import Foundation
import GRDB

/// Owns the GRDB `DatabaseQueue` and runs forward-only migrations.
final class DatabaseManager: Sendable {

    let dbQueue: DatabaseQueue

    // MARK: - Safe Write

    /// Error thrown when the device is critically low on storage and writes are blocked.
    struct StorageFullError: LocalizedError {
        var errorDescription: String? { "Device storage is full. Free up space to save." }
    }

    /// Wraps `dbQueue.write` with a pre-flight storage check and post-failure notification.
    /// Use this instead of `dbQueue.write` in service methods to surface errors to the UI.
    @discardableResult
    func safeWrite<T>(_ updates: @Sendable @escaping (Database) throws -> T) async throws -> T {
        guard StorageMonitor.canSafelyWrite else {
            let error = StorageFullError()
            StorageMonitor.handleWriteError(error)
            throw error
        }
        do {
            return try await dbQueue.write(updates)
        } catch {
            StorageMonitor.handleWriteError(error)
            throw error
        }
    }

    /// Creates a DatabaseManager backed by a file in Application Support.
    init() throws {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = appSupport.appendingPathComponent("prototype_me.sqlite")
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
        try runMigrations()

        if let attrs = try? fileManager.attributesOfItem(atPath: dbURL.path),
           let bytes = attrs[.size] as? Int64 {
            let mb = Double(bytes) / 1_048_576
            print("[DB] prototype_me.sqlite — \(String(format: "%.1f", mb)) MB")
        }
    }

    /// In-memory database for tests / previews.
    init(inMemory: Bool) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(configuration: config)
        try runMigrations()
    }

    // MARK: - Migrations

    // When adding a new migration:
    // 1. Add the ID to migrationIds below
    // 2. Register it in makeMigrator() with registered.append + shouldStop check
    // 3. Add a test in Prototype MeTests/MigrationTests.swift
    static let migrationIds = [
        "v1_initialSchema",
        "v10_missedScheduled",
        "v11_directiveColor",
        "v12_outboxBackoff",
    ]

    /// Builds a migrator with all registered migrations.
    /// Pass `through:` to stop after a specific migration (for testing).
    static func makeMigrator(through lastMigration: String? = nil) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        var registered = [String]()

        func shouldStop() -> Bool {
            if let last = lastMigration, registered.last == last { return true }
            return false
        }

        migrator.registerMigration("v1_initialSchema") { db in
            // ── folders — created first because notePage references it ──
            try db.create(table: "folder") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull().defaults(to: "")
                t.column("parentFolderId", .text).references("folder", onDelete: .cascade)
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
                t.column("version", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // ── notes ──
            try db.create(table: "notePage") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("body", .text).notNull().defaults(to: "")
                t.column("kind", .text).notNull().defaults(to: NoteKind.regular.rawValue)
                t.column("folderId", .text).references("folder", onDelete: .setNull)
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
                t.column("version", .integer).notNull().defaults(to: 1)
                t.column("updatedByDeviceId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // ── directives ──
            try db.create(table: "directive") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text).notNull().defaults(to: "")
                t.column("body", .text)
                t.column("status", .text).notNull().defaults(to: DirectiveStatus.active.rawValue)
                t.column("balloonEnabled", .boolean).notNull().defaults(to: false)
                t.column("balloonDurationSec", .double).notNull().defaults(to: 0)
                t.column("balloonSnapshotSec", .double).notNull().defaults(to: 0)
                t.column("snoozedUntil", .datetime)
                t.column("version", .integer).notNull().defaults(to: 1)
                t.column("updatedByDeviceId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // ── note↔directive join ──
            try db.create(table: "noteDirective") { t in
                t.column("noteId", .text).notNull().references("notePage", onDelete: .cascade)
                t.column("directiveId", .text).notNull().references("directive", onDelete: .cascade)
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull().defaults(to: Date())
                t.primaryKey(["noteId", "directiveId"])
            }

            // ── day entries (journal) ──
            try db.create(table: "dayEntry") { t in
                t.primaryKey("id", .text).notNull()
                t.column("date", .text).notNull()  // yyyy-MM-dd
                t.column("rating", .integer)
                t.column("diary", .text).notNull().defaults(to: "")
                t.column("tagsJSON", .text).notNull().defaults(to: "[]")  // JSON array of strings
                t.column("version", .integer).notNull().defaults(to: 1)
                t.column("updatedByDeviceId", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.uniqueKey(["date"])
            }

            // ── schedule rules ──
            try db.create(table: "scheduleRule") { t in
                t.primaryKey("id", .text).notNull()
                t.column("directiveId", .text).notNull().references("directive", onDelete: .cascade)
                t.column("ruleType", .text).notNull()
                t.column("paramsJSON", .text).notNull().defaults(to: "{}")
                t.column("version", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull().defaults(to: Date())
                t.column("lastCompletedDate", .text)  // yyyy-MM-dd, nullable
            }

            // ── tags ──
            try db.create(table: "tag") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("color", .text)
                t.column("version", .integer).notNull().defaults(to: 1)
                t.uniqueKey(["name"])
            }

            // ── directive history ──
            try db.create(table: "directiveHistory") { t in
                t.primaryKey("id", .text).notNull()
                t.column("directiveId", .text).notNull().references("directive", onDelete: .cascade)
                t.column("action", .text).notNull()
                t.column("payload", .text).notNull().defaults(to: "{}")
                t.column("createdAt", .datetime).notNull()
            }

            // ── active modes ──
            try db.create(table: "activeMode") { t in
                t.primaryKey("noteId", .text).references("notePage", onDelete: .cascade)
                t.column("activatedAt", .datetime).notNull()
            }

            // ── outbox queue (pending sync operations) ──
            try db.create(table: "outboxOp") { t in
                t.primaryKey("id", .text).notNull()
                t.column("entityType", .text).notNull()
                t.column("entityId", .text).notNull()
                t.column("op", .text).notNull()           // create | update | delete
                t.column("patch", .text).notNull().defaults(to: "{}")
                t.column("baseUpdatedAt", .datetime)
                t.column("schemaVersion", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull()
                t.column("attemptCount", .integer).notNull().defaults(to: 0)
                t.column("lastError", .text)
            }

            // ── tombstones (soft deletes for sync) ──
            try db.create(table: "tombstone") { t in
                t.primaryKey("id", .text).notNull()
                t.column("entityType", .text).notNull()
                t.column("entityId", .text).notNull()
                t.column("deletedAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deviceId", .text).notNull()
            }

            // ── sync state (single-row cursor + metadata) ──
            try db.create(table: "syncState") { t in
                t.primaryKey("id", .text).notNull()        // always "singleton"
                t.column("lastSyncToken", .text)
                t.column("lastPushAt", .datetime)
                t.column("lastPullAt", .datetime)
                t.column("deviceId", .text).notNull()
            }

            // ── registered devices (for multi-device debug) ──
            try db.create(table: "device") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("platform", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("lastSeenAt", .datetime).notNull()
            }

            // ── periodic reviews (server-cached AI reviews) ──
            try db.create(table: "periodicReview") { t in
                t.primaryKey("id", .text).notNull()
                t.column("period", .text).notNull()
                t.column("periodStart", .text).notNull()
                t.column("periodEnd", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("bestDay", .text)
                t.column("bestDayNote", .text)
                t.column("lowestDay", .text)
                t.column("lowestDayNote", .text)
                t.column("suggestion", .text)
                t.column("themesJSON", .text).notNull().defaults(to: "[]")
                t.column("directiveWinsJSON", .text).notNull().defaults(to: "[]")
                t.column("directiveFocusJSON", .text).notNull().defaults(to: "[]")
                t.column("directiveGapsJSON", .text).notNull().defaults(to: "[]")
                t.column("avgRating", .double)
                t.column("entryCount", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .text).notNull()
            }
            try db.create(indexOn: "periodicReview", columns: ["period", "periodStart"], options: .unique)

            // ── speak history (local-only, for undo) ──
            try db.create(table: "speakHistory") { t in
                t.primaryKey("id", .text).notNull()
                t.column("timestamp", .text).notNull()
                t.column("actionType", .text).notNull()
                t.column("entityType", .text).notNull()
                t.column("entityId", .text).notNull()
                t.column("itemName", .text).notNull()
                t.column("beforeJSON", .text)
            }
            try db.create(indexOn: "speakHistory", columns: ["timestamp"])
        }

        registered.append("v1_initialSchema")
        if shouldStop() { return migrator }

        migrator.registerMigration("v10_missedScheduled") { db in
            try db.alter(table: "periodicReview") { t in
                t.add(column: "missedScheduledJSON", .text).notNull().defaults(to: "[]")
            }
            // Clear cached reviews — they're missing the new field.
            try db.execute(sql: "DELETE FROM periodicReview")
        }

        registered.append("v10_missedScheduled")
        if shouldStop() { return migrator }

        migrator.registerMigration("v11_directiveColor") { db in
            try db.alter(table: "directive") { t in
                t.add(column: "color", .text)  // user-chosen hex color, nullable
            }
        }

        registered.append("v11_directiveColor")
        if shouldStop() { return migrator }

        migrator.registerMigration("v12_outboxBackoff") { db in
            try db.alter(table: "outboxOp") { t in
                t.add(column: "nextRetryAt", .datetime)  // time-based retry gating
            }
            // Unstick existing failed ops — reset attemptCount so they retry on next sync.
            try db.execute(sql: "UPDATE outboxOp SET attemptCount = 0, lastError = NULL")
        }
        registered.append("v12_outboxBackoff")

        return migrator
    }

    private func runMigrations() throws {
        let migrator = Self.makeMigrator()
        try migrator.migrate(dbQueue)
    }
}
