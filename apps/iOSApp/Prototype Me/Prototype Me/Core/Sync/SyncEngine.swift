import Foundation
import UIKit
import GRDB

extension Notification.Name {
    static let syncDidComplete = Notification.Name("syncDidComplete")
    static let syncDidBegin = Notification.Name("syncDidBegin")
    static let syncUpgradeRequired = Notification.Name("syncUpgradeRequired")
}

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
    private static let pushDebounceInterval: TimeInterval = 2.0

    /// Exponential backoff (seconds) for retrying a failed outbox op, keyed by attemptCount.
    /// 1 → 30s, 2 → 2m, 3 → 10m, 4 → 30m, 5 → 2h, 6+ → 6h (capped).
    private static func backoffSeconds(for attemptCount: Int) -> TimeInterval {
        switch attemptCount {
        case ..<2:  return 30
        case 2:     return 120
        case 3:     return 600
        case 4:     return 1800
        case 5:     return 7200
        default:    return 21600
        }
    }

    private var debounceWorkItem: DispatchWorkItem?
    private let debounceQueue = DispatchQueue(label: "com.prototypeme.sync.debounce")
    private var outboxObserver: AnyDatabaseCancellable?
    private var pollTimer: Timer?
    private static let pollInterval: TimeInterval = 60

    // MARK: - Init

    init(db: DatabaseManager, api: APIClient, reachability: ReachabilityMonitor) {
        self.db = db
        self.api = api
        self.reachability = reachability

        // Initialize sync state if not present
        initializeSyncState()

        // If sync is off, clear dead-weight tables (tombstones + outbox ops).
        // They serve no purpose without sync and would accumulate forever.
        // If the user later enables sync, seedFullPush() re-enqueues everything.
        if !Self.isSyncEnabled {
            clearSyncArtifacts()
        }

        // Cap directiveHistory on every launch (not sync-dependent)
        capDirectiveHistory()

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

        // Periodic pull to pick up changes from other devices
        startPollTimer()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.startPollTimer()
            Task { try? await self?.sync() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.stopPollTimer()
        }
    }

    private func startPollTimer() {
        stopPollTimer()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { try? await self?.sync() }
        }
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Public

    /// Whether cloud sync is enabled (requires Pro plan).
    static var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "syncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "syncEnabled") }
    }

    /// Full sync cycle: push pending outbox ops, then pull remote changes.
    func sync() async throws {
        guard Self.isSyncEnabled else { return }
        guard reachability.isConnected else { return }

        // Don't attempt sync if device storage is critically low — writes will fail
        if !StorageMonitor.canSafelyWrite {
            StorageMonitor.checkAndNotify()
            return
        }

        guard beginSync() else { return }

        defer {
            endSync()
            NotificationCenter.default.post(name: .syncDidComplete, object: nil)
            // If writes arrived during sync, re-sync
            if checkAndClearDirty() {
                Task { try? await self.sync() }
            }
        }

        do {
            try await push()
            try await pull()
            try await pruneAfterSync()
            lock.lock()
            lastError = nil
            lock.unlock()
        } catch {
            lock.lock()
            lastError = error
            lock.unlock()

            // 426 Upgrade Required — stop sync entirely until the app is updated
            if case .clientError(426, _, _) = error as? APIClient.APIError {
                stopPollTimer()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .syncUpgradeRequired, object: nil)
                }
            }

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

    /// Wipes server data and pushes all local data fresh.
    /// Local state is authoritative — the server mirrors it exactly after this completes.
    func seedFullPush() async throws {
        // Acquire sync lock to prevent concurrent sync while seeding
        guard beginSync() else {
            print("[Sync] Seed push skipped — sync already in progress")
            return
        }
        defer { endSync() }

        // Wipe all user data on the server so we start clean.
        // This avoids needing tombstones — anything that doesn't exist locally
        // simply won't be pushed, and the server won't have it.
        print("[Sync] Resetting server data before full push")
        try await api.delete("/v1/sync/reset")

        // Clear local tombstones + stale outbox — we're pushing everything fresh
        try await db.dbQueue.write { db in
            try Tombstone.deleteAll(db)
            try OutboxOp.deleteAll(db)
        }

        // Reset sync cursor so pull starts from the beginning after push
        try await db.dbQueue.write { db in
            if var state = try SyncState.current(in: db) {
                state.lastSyncToken = nil
                state.lastPushAt = nil
                state.lastPullAt = nil
                try state.update(db)
            }
        }

        let count = try await db.dbQueue.write { db -> Int in
            var total = 0

            // Folders (must come before notes — note_page has FK to folder)
            for entity in try Folder.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "folder", entityId: entity.id.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Directives
            for entity in try Directive.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "directive", entityId: entity.id.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Notes
            for entity in try NotePage.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "notePage", entityId: entity.id.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Day Entries
            for entity in try DayEntry.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "dayEntry", entityId: entity.id.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Schedule Rules
            for entity in try ScheduleRule.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "scheduleRule", entityId: entity.id.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Tags
            for entity in try Tag.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "tag", entityId: entity.id.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Note-Directive links
            for entity in try NoteDirective.fetchAll(db) {
                let entityId = "\(entity.noteId.uuidString)|\(entity.directiveId.uuidString)"
                try OutboxOp.enqueue(entityType: "noteDirective", entityId: entityId, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            // Active Modes
            for entity in try ActiveMode.fetchAll(db) {
                try OutboxOp.enqueue(entityType: "activeMode", entityId: entity.noteId.uuidString, op: "create", patch: entity.syncPatch(), in: db)
                total += 1
            }

            return total
        }

        print("[Sync] Seed push: enqueued \(count) entities")
        // Trigger sync to push everything
        try await sync()
    }

    /// Entity types ordered by FK dependencies — parents before children.
    /// Types not listed here sort to the end (safe default for standalone entities).
    private static let entityPushOrder: [String: Int] = [
        "folder":         0,
        "directive":      1,
        "tag":            2,
        "notePage":       3,
        "dayEntry":       4,
        "scheduleRule":   5,
        "noteDirective":  6,
        "activeMode":     7,
    ]

    /// Push only (e.g., after a local write).
    func push() async throws {
        guard reachability.isConnected else { return }

        // Clean up redundant/obsolete ops before pushing
        try await compactOutbox()

        let now = Date()
        let ops = try await db.dbQueue.read { db in
            try OutboxOp
                .filter(Column("nextRetryAt") == nil || Column("nextRetryAt") <= now)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }

        guard !ops.isEmpty else { return }

        // Sort by entity dependency order so parents push before children
        let sortedOps = ops.sorted { a, b in
            let orderA = Self.entityPushOrder[a.entityType] ?? 99
            let orderB = Self.entityPushOrder[b.entityType] ?? 99
            if orderA != orderB { return orderA < orderB }
            return a.createdAt < b.createdAt
        }

        let deviceId = api.deviceId
        let batchSize = 20
        let batches = stride(from: 0, to: sortedOps.count, by: batchSize).map {
            Array(sortedOps[$0..<min($0 + batchSize, sortedOps.count)])
        }

        print("[Sync] Pushing \(sortedOps.count) ops in \(batches.count) batch(es)")

        for batch in batches {
            let syncToken = try await db.dbQueue.read { db in
                try SyncState.current(in: db)?.lastSyncToken
            }

            let request = PushRequest(
                deviceId: deviceId,
                lastSyncToken: syncToken,
                ops: batch.map { op in
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
                print("[Sync] Pushing batch of \(batch.count) ops")
                let response: PushResponse = try await api.post("/v1/sync/push", body: request, timeout: APIClient.Timeout.sync)
                print("[Sync] Batch succeeded: \(response.applied.count) applied")

                try await db.dbQueue.write { db in
                    let appliedEntityIds = Set(response.applied.map(\.entityId))
                    for op in batch where appliedEntityIds.contains(op.entityId) {
                        _ = try OutboxOp.deleteOne(db, key: op.id)
                    }

                    if var state = try SyncState.current(in: db) {
                        state.lastSyncToken = response.lastSyncToken
                        state.lastPushAt = Date()
                        try state.update(db)
                    }
                }
            } catch let error as APIClient.APIError {
                print("[Sync] Batch push failed: \(error)")
                try await db.dbQueue.write { db in
                    let failureTime = Date()
                    for var op in batch {
                        op.attemptCount += 1
                        op.lastError = "\(error)"
                        op.nextRetryAt = failureTime.addingTimeInterval(Self.backoffSeconds(for: op.attemptCount))
                        try op.update(db)
                    }
                }
                throw error
            }
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

            var path = "/v1/sync/pull?limit=\(Self.pullPageSize)"
            if let cursor {
                path += "&cursor=\(cursor)"
            }

            let response: PullResponse = try await api.get(path, timeout: APIClient.Timeout.sync)

            try await db.dbQueue.write { db in
                var lastSuccessfulToken: String?
                var failedCount = 0

                for event in response.events {
                    do {
                        try self.applyEvent(event, in: db)
                        lastSuccessfulToken = event.token
                    } catch {
                        failedCount += 1
                        print("[Sync] Failed to apply event \(event.entityType)/\(event.entityId): \(error)")
                        StorageMonitor.handleWriteError(error)
                    }
                }

                // Only advance cursor to the last *successfully* applied event.
                // This ensures failed events (e.g. from disk-full) are retried on the next pull.
                if let token = lastSuccessfulToken {
                    if var state = try SyncState.current(in: db) {
                        state.lastSyncToken = token
                        state.lastPullAt = Date()
                        try state.update(db)
                    }
                }

                if failedCount > 0 {
                    print("[Sync] Pull page: \(failedCount)/\(response.events.count) events failed to apply")
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
        let isSyncing: Bool
    }

    func debugInfo() async throws -> DebugInfo {
        let (count, state) = try await db.dbQueue.read { db -> (Int, SyncState?) in
            let count = try OutboxOp.fetchCount(db)
            let state = try SyncState.current(in: db)
            return (count, state)
        }

        lock.lock()
        let errorDesc = lastError.map { "\($0)" }
        let syncing = isSyncing
        lock.unlock()

        return DebugInfo(
            outboxCount: count,
            lastPushAt: state?.lastPushAt,
            lastPullAt: state?.lastPullAt,
            lastSyncToken: state?.lastSyncToken,
            lastError: errorDesc,
            deviceId: api.deviceId,
            isSyncing: syncing
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
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .syncDidBegin, object: nil)
        }
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

    /// Clears outbox ops and tombstones when sync is disabled.
    /// No need to keep them — seedFullPush() wipes the server and pushes
    /// everything local when the user re-subscribes.
    private func clearSyncArtifacts() {
        try? db.dbQueue.write { db in
            let ops = try OutboxOp.deleteAll(db)
            let tombstones = try Tombstone.deleteAll(db)
            if ops > 0 || tombstones > 0 {
                print("[Sync] Sync disabled — cleared \(ops) outbox op(s), \(tombstones) tombstone(s)")
            }
        }
    }

    // MARK: - Outbox Compaction

    /// Cleans up the outbox before pushing by removing redundant or obsolete ops.
    ///
    /// Safety invariant: **delete ops are never removed.** Even if we believe the
    /// server doesn't have the entity, we can't be certain — a prior create may
    /// have been accepted by the server but the client never got the response.
    /// Sending a redundant delete is harmless (server returns success or 404,
    /// both fine). Skipping a needed delete causes permanent divergence.
    ///
    /// Rules:
    /// 1. Create + Delete for same entity → remove create/updates, KEEP delete
    /// 2. Multiple updates for same entity → keep only the newest (full snapshots)
    /// 3. Create/Update for an entity that has a tombstone → remove (delete op already exists)
    private func compactOutbox() async throws {
        try await db.dbQueue.write { db in
            let allOps = try OutboxOp.order(Column("createdAt").asc).fetchAll(db)
            guard !allOps.isEmpty else { return }

            var opsToDelete: Set<UUID> = []

            // Group ops by (entityType, entityId)
            var grouped: [String: [OutboxOp]] = [:]
            for op in allOps {
                let key = "\(op.entityType)|\(op.entityId)"
                grouped[key, default: []].append(op)
            }

            for (_, ops) in grouped {
                let hasDelete = ops.contains { $0.op == "delete" }

                if hasDelete {
                    // Rule 1: Entity was deleted — remove create/update ops but KEEP delete.
                    // The delete must always reach the server in case the create was
                    // partially processed (server got it, client didn't get the ACK).
                    for op in ops where op.op != "delete" {
                        opsToDelete.insert(op.id)
                    }
                    continue
                }

                // Rule 2: Multiple updates → keep only the newest (patches are full snapshots)
                let updates = ops.filter { $0.op == "update" }
                if updates.count > 1 {
                    for op in updates.dropLast() {
                        opsToDelete.insert(op.id)
                    }
                }
            }

            // Rule 3: Create/Update ops for tombstoned entities (where delete op may
            // already have been sent in a prior push cycle and removed from outbox)
            let nonDeleteOps = allOps.filter { $0.op != "delete" && !opsToDelete.contains($0.id) }
            if !nonDeleteOps.isEmpty {
                let entityKeys = nonDeleteOps.map { "\($0.entityType)|\($0.entityId)" }
                let uniqueKeys = Set(entityKeys)

                for key in uniqueKeys {
                    let parts = key.split(separator: "|", maxSplits: 1)
                    guard parts.count == 2 else { continue }
                    let entityType = String(parts[0])
                    let entityId = String(parts[1])

                    let hasTombstone = try Tombstone
                        .filter(Column("entityType") == entityType && Column("entityId") == entityId)
                        .fetchCount(db) > 0

                    if hasTombstone {
                        for op in nonDeleteOps where op.entityType == entityType && op.entityId == entityId {
                            opsToDelete.insert(op.id)
                        }
                    }
                }
            }

            // Execute deletions
            if !opsToDelete.isEmpty {
                print("[Sync] Compaction: removing \(opsToDelete.count) obsolete outbox op(s)")
                for id in opsToDelete {
                    _ = try OutboxOp.deleteOne(db, key: id)
                }
            }
        }
    }

    // MARK: - Post-Sync Cleanup

    /// Prunes data that's no longer needed after a successful sync cycle.
    private func pruneAfterSync() async throws {
        try await db.dbQueue.write { db in
            // Tombstone pruning: only needed while delete op is still in outbox.
            let allTombstones = try Tombstone.fetchAll(db)
            var tombstonesPruned = 0

            for tombstone in allTombstones {
                let hasDeleteOp = try OutboxOp
                    .filter(Column("entityType") == tombstone.entityType
                            && Column("entityId") == tombstone.entityId
                            && Column("op") == "delete")
                    .fetchCount(db) > 0

                if !hasDeleteOp {
                    _ = try Tombstone.deleteOne(db, key: tombstone.id)
                    tombstonesPruned += 1
                }
            }

            if tombstonesPruned > 0 {
                print("[Sync] Cleanup: pruned \(tombstonesPruned) tombstone(s)")
            }
        }
    }

    /// Caps directiveHistory at 30 entries per directive. Runs on every launch
    /// regardless of sync status — this is local housekeeping, not sync-dependent.
    private func capDirectiveHistory() {
        try? db.dbQueue.write { db in
            let directiveIds = try UUID.fetchAll(db, sql: """
                SELECT DISTINCT directiveId FROM directiveHistory
                """)

            let maxPerDirective = 30
            var pruned = 0

            for directiveId in directiveIds {
                let count = try DirectiveHistory
                    .filter(Column("directiveId") == directiveId)
                    .fetchCount(db)

                if count > maxPerDirective {
                    let excess = count - maxPerDirective
                    let oldIds = try DirectiveHistory
                        .filter(Column("directiveId") == directiveId)
                        .order(Column("createdAt").asc)
                        .limit(excess)
                        .fetchAll(db)
                        .map(\.id)

                    for id in oldIds {
                        _ = try DirectiveHistory.deleteOne(db, key: id)
                    }
                    pruned += oldIds.count
                }
            }

            if pruned > 0 {
                print("[Sync] DirectiveHistory cap: pruned \(pruned) row(s)")
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
                           arguments: [noteId, dirId])
        case "scheduleRule":
            guard let entityId = UUID(uuidString: event.entityId) else { return }
            try ScheduleRule.deleteOne(db, key: entityId)
        case "activeMode":
            guard let noteId = UUID(uuidString: event.entityId) else { return }
            try ActiveMode.deleteOne(db, key: noteId)
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

        case "activeMode":
            let remote = try decoder.decode(ActiveMode.self, from: payloadData)
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
