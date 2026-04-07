import Foundation
import GRDB

/// Owns all write operations for Tag.
final class TagService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - CRUD

    func create(name: String, color: String? = nil) async throws -> Tag {
        let tag = Tag(id: UUID(), name: name, color: color, version: 1)
        try await db.safeWrite { db in
            try tag.insert(db)
            try OutboxOp.enqueue(entityType: "tag", entityId: tag.id.uuidString, op: "create", patch: tag.syncPatch(), in: db)
        }
        return tag
    }

    func delete(id: UUID) async throws {
        _ = try await db.safeWrite { db in
            try Tag.deleteOne(db, key: id)
            try OutboxOp.enqueueDelete(entityType: "tag", entityId: id.uuidString, in: db)
        }
    }

    /// Find or create a tag by name.
    func findOrCreate(name: String, color: String? = nil) async throws -> Tag {
        try await db.safeWrite { db in
            if let existing = try Tag.filter(Column("name") == name).fetchOne(db) {
                return existing
            }
            let tag = Tag(id: UUID(), name: name, color: color, version: 1)
            try tag.insert(db)
            try OutboxOp.enqueue(entityType: "tag", entityId: tag.id.uuidString, op: "create", patch: tag.syncPatch(), in: db)
            return tag
        }
    }

    func fetchAll() async throws -> [Tag] {
        try await db.dbQueue.read { db in
            try Tag.order(Column("name")).fetchAll(db)
        }
    }
}
