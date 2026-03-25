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
    private var isDirty = false
    private var lastError: Error?

    private static let pullPageSize = 200
    private static let maxRetryAttempts = 5
    private static let maxBackoffSeconds: Double = 30
    private static let pushDebounceInterval: TimeInterval = 2.0

    private var debounceWorkItem: DispatchWorkItem?
    private let debounceQueue = DispatchQueue(label: "com.prototypeme.sync.debounce")
    private var outboxObserver: AnyDatabaseCancellable?

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

        // Watch outbox table — auto-trigger debounced push when new ops appear
        outboxObserver = ValueObservation
            .tracking { db in try OutboxOp.fetchCount(db) }
            .start(in: db.dbQueue, onError: { _ in }, onChange: { [weak self] count in
                if count > 0 {
                    self?.schedulePush()
                }
            })
    }

    // MARK: - Public

    /// Full sync cycle: push pending outbox ops, then pull remote changes.
    func sync() async throws {
        guard reachability.isConnected else { return }
        guard beginSync() else { return }

        defer {
            endSync()
            // If writes arrived during sync, re-sync
            if checkAndClearDirty() {
                Task { try? await self.sync() }
            }
        }

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

    /// Schedule a debounced push (called after local writes).
    func schedulePush() {
        debounceQueue.async { [weak self] in
            self?.debounceWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                Task { try? await self?.sync() }
            }
            self?.debounceWorkItem = item
            self?.debounceQueue.asyncAfter(deadline: .now() + Self.pushDebounceInterval, execute: item)
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
                    entityId: op.entityId,
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
                for op in ops where appliedEntityIds.contains(op.entityId) {
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
            // Mark failed ops with error + exponential backoff delay
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

    // MARK: - Private: Sync State

    private func beginSync() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isSyncing else {
            isDirty = true  // Mark dirty so we re-sync when current cycle ends
            return false
        }
        isSyncing = true
        return true
    }

    private func endSync() {
        lock.lock()
        isSyncing = false
        lock.unlock()
    }

    private func checkAndClearDirty() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let wasDirty = isDirty
        isDirty = false
        return wasDirty
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

    // MARK: - Private: Backoff

    /// Calculate backoff delay for a given attempt count (exponential with jitter).
    private static func backoffDelay(attempt: Int) -> TimeInterval {
        let base = min(pow(2.0, Double(attempt)), maxBackoffSeconds)
        let jitter = Double.random(in: 0...base * 0.3)
        return base + jitter
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
        switch event.entityType {
        case "notePage":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try NotePage.deleteOne(db, key: entityId)
        case "directive":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try Directive.deleteOne(db, key: entityId)
        case "folder":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try Folder.deleteOne(db, key: entityId)
        case "dayEntry":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try DayEntry.deleteOne(db, key: entityId)
        case "tag":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try Tag.deleteOne(db, key: entityId)
        case "noteDirective":
            // entityId format: "noteId|directiveId"
            let parts = event.entityId.split(separator: "|")
            guard parts.count == 2,
                  let noteId = UUID(uuidString: String(parts[0])),
                  let dirId = UUID(uuidString: String(parts[1])) else { return }
            try db.execute(sql: "DELETE FROM noteDirective WHERE noteId = ? AND directiveId = ?",
                           arguments: [noteId.uuidString, dirId.uuidString])
        case "scheduleRule":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try ScheduleRule.deleteOne(db, key: entityId)
        default:
            break
        }
    }

    private func applyUpsert(_ event: PullResponse.ChangeEvent, in db: Database) throws {
        guard let payload = event.payload, let payloadData = payload.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Check tombstones first — never resurrect deleted entities
        let hasTombstone = try Tombstone
            .filter(Column("entityType") == event.entityType && Column("entityId") == event.entityId)
            .fetchCount(db) > 0
        if hasTombstone { return }

        // Version-based LWW: only apply if remote version >= local version
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
            if let local = try Folder.fetchOne(db, key: remote.id), local.version > remote.version {
                return
            }
            try remote.save(db)

        case "dayEntry":
            let remote = try decoder.decode(DayEntry.self, from: payloadData)
            if let local = try DayEntry.fetchOne(db, key: remote.id), local.version > remote.version {
                return
            }
            try remote.save(db)

        case "tag":
            let remote = try decoder.decode(Tag.self, from: payloadData)
            if let local = try Tag.fetchOne(db, key: remote.id), local.version > remote.version {
                return
            }
            try remote.save(db)

        case "noteDirective":
            let remote = try decoder.decode(NoteDirective.self, from: payloadData)
            // For join tables: insert or replace (no version-based conflict)
            try remote.save(db)

        case "scheduleRule":
            let remote = try decoder.decode(ScheduleRule.self, from: payloadData)
            if let local = try ScheduleRule.fetchOne(db, key: remote.id), local.version > remote.version {
                return
            }
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
