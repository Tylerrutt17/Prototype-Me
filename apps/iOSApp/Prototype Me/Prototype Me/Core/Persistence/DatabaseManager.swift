import Foundation
import GRDB

/// Owns the GRDB `DatabaseQueue` and runs forward-only migrations.
final class DatabaseManager: Sendable {

    let dbQueue: DatabaseQueue

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
        dbQueue = try DatabaseQueue(path: dbURL.path)
        try runMigrations()
    }

    /// In-memory database for tests / previews.
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()
        try runMigrations()
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        // In DEBUG, wipe DB on schema change for faster iteration.
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_createTables") { db in
            // ── folders — created first because notePage references it ──
            try db.create(table: "folder") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull().defaults(to: "")
                t.column("parentFolderId", .text).references("folder", onDelete: .cascade)
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
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // ── note↔directive join ──
            try db.create(table: "noteDirective") { t in
                t.column("noteId", .text).notNull().references("notePage", onDelete: .cascade)
                t.column("directiveId", .text).notNull().references("directive", onDelete: .cascade)
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
                t.primaryKey(["noteId", "directiveId"])
            }

            // ── day entries (diary) ──
            try db.create(table: "dayEntry") { t in
                t.primaryKey("id", .text).notNull()
                t.column("date", .text).notNull()  // yyyy-MM-dd
                t.column("rating", .integer)
                t.column("diary", .text).notNull().defaults(to: "")
                t.column("tagsJSON", .text).notNull().defaults(to: "[]")  // JSON array of strings
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
                t.column("createdAt", .datetime).notNull()
                t.column("lastCompletedDate", .text)  // yyyy-MM-dd, nullable
            }

            // ── tags ──
            try db.create(table: "tag") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("color", .text)
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
        }

        migrator.registerMigration("v2_addActiveModes") { db in
            // ── active modes ──
            try db.create(table: "activeMode") { t in
                t.primaryKey("noteId", .text).references("notePage", onDelete: .cascade)
                t.column("activatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("v3_syncInfrastructure") { db in
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
        }

        migrator.registerMigration("v4_addSyncFieldsToEntities") { db in
            // Add updatedByDeviceId to all mutable entities for LWW conflict resolution
            for table in ["notePage", "directive", "dayEntry"] {
                try db.alter(table: table) { t in
                    t.add(column: "updatedByDeviceId", .text)
                }
            }
        }

        migrator.registerMigration("v5_addFolderSortIndex") { db in
            try db.alter(table: "folder") { t in
                t.add(column: "sortIndex", .integer).notNull().defaults(to: 0)
            }
        }

        try migrator.migrate(dbQueue)
    }
}
