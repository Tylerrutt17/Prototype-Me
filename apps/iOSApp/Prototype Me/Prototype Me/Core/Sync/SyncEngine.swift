import Foundation
import GRDB

/// Orchestrates push/pull sync between the local GRDB database and the remote API.
/// Push first (maximize data safety), then pull.
final class SyncEngine: @unchecked Sendable {

    // MARK: - Dependencies

    private let db: DatabaseManager
    private let api: APIClient
    private let reachability: ReachabilityMonitor

    // MARK: - State

    private let lock = NSLock()
    private var isSyncing = false
    private var lastError: Error?

    private static let pullPageSize = 200
    private static let maxRetryAttempts = 5
    private static let maxBackoffSeconds: Double = 30

    // MARK: - Init

    init(db: DatabaseManager, api: APIClient, reachability: ReachabilityMonitor) {
        self.db = db
        self.api = api
        self.reachability = reachability

        // Initialize sync state if not present
        initializeSyncState()

        // Auto-sync when connectivity returns
        reachability.observe { [weak self] status in
            if status.isConnected {
                Task { try? await self?.sync() }
            }
        }
    }

    // MARK: - Public

    /// Full sync cycle: push pending outbox ops, then pull remote changes.
    func sync() async throws {
        guard reachability.isConnected else { return }
        guard beginSync() else { return }

        defer { endSync() }

        do {
            try await push()
            try await pull()
            lock.lock()
            lastError = nil
            lock.unlock()
        } catch {
            lock.lock()
            lastError = error
            lock.unlock()
            throw error
        }
    }

    /// Push only (e.g., after a local write).
    func push() async throws {
        guard reachability.isConnected else { return }

        let ops = try await db.dbQueue.read { db in
            try OutboxOp
                .filter(Column("attemptCount") < Self.maxRetryAttempts)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }

        guard !ops.isEmpty else { return }

        let deviceId = api.deviceId
        let syncToken = try await db.dbQueue.read { db in
            try SyncState.current(in: db)?.lastSyncToken
        }

        let request = PushRequest(
            deviceId: deviceId,
            lastSyncToken: syncToken,
            ops: ops.map { op in
                PushRequest.OpPayload(
                    id: op.id.uuidString,
                    entityType: op.entityType,
                    entityId: op.entityId.uuidString,
                    op: op.op,
                    patch: op.patch,
                    baseUpdatedAt: op.baseUpdatedAt,
                    schemaVersion: op.schemaVersion,
                    createdAt: op.createdAt
                )
            }
        )

        do {
            let response: PushResponse = try await api.post("/sync/push", body: request, timeout: APIClient.Timeout.sync)

            // Remove successfully applied ops from outbox
            try await db.dbQueue.write { db in
                let appliedEntityIds = Set(response.applied.map(\.entityId))
                for op in ops where appliedEntityIds.contains(op.entityId.uuidString) {
                    try op.delete(db)
                }

                // Update sync token
                if var state = try SyncState.current(in: db) {
                    state.lastSyncToken = response.lastSyncToken
                    state.lastPushAt = Date()
                    try state.update(db)
                }
            }
        } catch let error as APIClient.APIError {
            // Mark failed ops with error
            try await db.dbQueue.write { db in
                for var op in ops {
                    op.attemptCount += 1
                    op.lastError = "\(error)"
                    try op.update(db)
                }
            }
            throw error
        }
    }

    /// Pull remote changes, paginating until caught up.
    func pull() async throws {
        guard reachability.isConnected else { return }

        var hasMore = true
        while hasMore {
            let cursor = try await db.dbQueue.read { db in
                try SyncState.current(in: db)?.lastSyncToken
            }

            var path = "/sync/pull?limit=\(Self.pullPageSize)"
            if let cursor {
                path += "&cursor=\(cursor)"
            }

            let response: PullResponse = try await api.get(path, timeout: APIClient.Timeout.sync)

            try await db.dbQueue.write { db in
                for event in response.events {
                    try applyEvent(event, in: db)
                }

                // Update cursor
                if let nextToken = response.nextToken {
                    if var state = try SyncState.current(in: db) {
                        state.lastSyncToken = nextToken
                        state.lastPullAt = Date()
                        try state.update(db)
                    }
                }
            }

            hasMore = response.hasMore
        }
    }

    // MARK: - Outbox Enqueue

    /// Enqueue a local change for sync. Called by services after writes.
    func enqueue(entityType: String, entityId: UUID, op: String, patch: String = "{}", baseUpdatedAt: Date? = nil) async throws {
        let outboxOp = OutboxOp(
            id: UUID(),
            entityType: entityType,
            entityId: entityId,
            op: op,
            patch: patch,
            baseUpdatedAt: baseUpdatedAt,
            schemaVersion: 1,
            createdAt: Date(),
            attemptCount: 0,
            lastError: nil
        )
        try await db.dbQueue.write { db in
            try outboxOp.insert(db)
        }
    }

    /// Enqueue a delete: creates a tombstone + outbox op.
    func enqueueDelete(entityType: String, entityId: UUID) async throws {
        try await db.dbQueue.write { db in
            let tombstone = Tombstone(
                id: UUID(),
                entityType: entityType,
                entityId: entityId,
                deletedAt: Date(),
                updatedAt: Date(),
                deviceId: self.api.deviceId
            )
            try tombstone.insert(db)

            let op = OutboxOp(
                id: UUID(),
                entityType: entityType,
                entityId: entityId,
                op: "delete",
                patch: "{}",
                baseUpdatedAt: nil,
                schemaVersion: 1,
                createdAt: Date(),
                attemptCount: 0,
                lastError: nil
            )
            try op.insert(db)
        }
    }

    // MARK: - Debug Info

    struct DebugInfo: Sendable {
        let outboxCount: Int
        let lastPushAt: Date?
        let lastPullAt: Date?
        let lastSyncToken: String?
        let lastError: String?
        let deviceId: String
    }

    func debugInfo() async throws -> DebugInfo {
        let (count, state) = try await db.dbQueue.read { db -> (Int, SyncState?) in
            let count = try OutboxOp.fetchCount(db)
            let state = try SyncState.current(in: db)
            return (count, state)
        }

        lock.lock()
        let errorDesc = lastError.map { "\($0)" }
        lock.unlock()

        return DebugInfo(
            outboxCount: count,
            lastPushAt: state?.lastPushAt,
            lastPullAt: state?.lastPullAt,
            lastSyncToken: state?.lastSyncToken,
            lastError: errorDesc,
            deviceId: api.deviceId
        )
    }

    // MARK: - Private

    private func beginSync() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isSyncing else { return false }
        isSyncing = true
        return true
    }

    private func endSync() {
        lock.lock()
        isSyncing = false
        lock.unlock()
    }

    private func initializeSyncState() {
        try? db.dbQueue.write { db in
            if try SyncState.current(in: db) == nil {
                let state = SyncState(
                    id: SyncState.singletonId,
                    lastSyncToken: nil,
                    lastPushAt: nil,
                    lastPullAt: nil,
                    deviceId: self.api.deviceId
                )
                try state.insert(db)
            }
        }
    }

    // MARK: - Apply Remote Events

    private func applyEvent(_ event: PullResponse.ChangeEvent, in db: Database) throws {
        switch event.operation {
        case "delete":
            try applyDelete(event, in: db)
        case "create", "update":
            try applyUpsert(event, in: db)
        default:
            break
        }
    }

    private func applyDelete(_ event: PullResponse.ChangeEvent, in db: Database) throws {
        guard let entityId = UUID(uuidString: event.entityId) else { return }

        switch event.entityType {
        case "notePage":    try NotePage.deleteOne(db, key: entityId)
        case "directive":   try Directive.deleteOne(db, key: entityId)
        case "folder":      try Folder.deleteOne(db, key: entityId)
        case "dayEntry":    try DayEntry.deleteOne(db, key: entityId)
        case "tag":         try Tag.deleteOne(db, key: entityId)
        default: break
        }
    }

    private func applyUpsert(_ event: PullResponse.ChangeEvent, in db: Database) throws {
        guard let payload = event.payload, let payloadData = payload.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Version-based LWW: only apply if remote version ≥ local version
        switch event.entityType {
        case "notePage":
            let remote = try decoder.decode(NotePage.self, from: payloadData)
            if let local = try NotePage.fetchOne(db, key: remote.id), local.version > remote.version {
                return // Local wins
            }
            try remote.save(db)
        case "directive":
            let remote = try decoder.decode(Directive.self, from: payloadData)
            if let local = try Directive.fetchOne(db, key: remote.id), local.version > remote.version {
                return
            }
            try remote.save(db)
        case "folder":
            let remote = try decoder.decode(Folder.self, from: payloadData)
            try remote.save(db)
        case "tag":
            let remote = try decoder.decode(Tag.self, from: payloadData)
            try remote.save(db)
        default:
            break
        }
    }
}

// MARK: - Sync API Types

struct PushRequest: Encodable {
    let deviceId: String
    let lastSyncToken: String?
    let ops: [OpPayload]

    struct OpPayload: Encodable {
        let id: String
        let entityType: String
        let entityId: String
        let op: String
        let patch: String
        let baseUpdatedAt: Date?
        let schemaVersion: Int
        let createdAt: Date
    }
}

struct PushResponse: Decodable {
    let applied: [AppliedEntity]
    let lastSyncToken: String

    struct AppliedEntity: Decodable {
        let entityType: String
        let entityId: String
    }
}

struct PullResponse: Decodable {
    let events: [ChangeEvent]
    let nextToken: String?
    let hasMore: Bool

    struct ChangeEvent: Decodable {
        let token: String
        let entityType: String
        let entityId: String
        let operation: String       // "create" | "update" | "delete"
        let payload: String?        // JSON string of the entity, null for deletes
        let version: Int?
        let updatedAt: Date?
        let updatedByDeviceId: String?
    }
}
