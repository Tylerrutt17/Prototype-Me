import Foundation
import GRDB

/// Owns all write operations for ActiveMode (max 3 concurrent modes).
final class ModeService: Sendable {

    private let db: DatabaseManager
    static let maxActiveModes = 3

    init(db: DatabaseManager) {
        self.db = db
    }

    /// Activate a mode note. Enforces max 3 active modes — removes the oldest if needed.
    func activate(noteId: UUID) async throws {
        try await db.safeWrite { db in
            // Already active?
            if try ActiveMode.fetchOne(db, key: noteId) != nil { return }

            // Enforce max: remove oldest if at limit
            let count = try ActiveMode.fetchCount(db)
            if count >= Self.maxActiveModes {
                let oldest = try ActiveMode.order(Column("activatedAt").asc).fetchOne(db)
                if let oldest {
                    try oldest.delete(db)
                    try OutboxOp.enqueueDelete(entityType: "activeMode", entityId: oldest.noteId.uuidString, in: db)
                }
            }

            let mode = ActiveMode(noteId: noteId, activatedAt: Date())
            try mode.insert(db)
            try OutboxOp.enqueue(entityType: "activeMode", entityId: noteId.uuidString, op: "create", patch: mode.syncPatch(), in: db)
        }
    }

    func deactivate(noteId: UUID) async throws {
        _ = try await db.safeWrite { db in
            try ActiveMode.deleteOne(db, key: noteId)
            try OutboxOp.enqueueDelete(entityType: "activeMode", entityId: noteId.uuidString, in: db)
        }
    }

    func deactivateAll() async throws {
        _ = try await db.safeWrite { db in
            let all = try ActiveMode.fetchAll(db)
            try ActiveMode.deleteAll(db)
            for mode in all {
                try OutboxOp.enqueueDelete(entityType: "activeMode", entityId: mode.noteId.uuidString, in: db)
            }
        }
    }

    func isActive(noteId: UUID) async throws -> Bool {
        try await db.dbQueue.read { db in
            try ActiveMode.fetchOne(db, key: noteId) != nil
        }
    }
}
