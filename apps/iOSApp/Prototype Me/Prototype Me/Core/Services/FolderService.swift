import Foundation
import GRDB

/// Owns all write operations for Folder.
final class FolderService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - CRUD

    func create(name: String, parentFolderId: UUID? = nil) async throws -> Folder {
        let now = Date()
        let nextSort = try await db.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COALESCE(MAX(sortIndex), -1) + 1 FROM folder WHERE parentFolderId IS ?
                """, arguments: [parentFolderId?.uuidString]) ?? 0
        }
        let folder = Folder(
            id: UUID(),
            name: name,
            parentFolderId: parentFolderId,
            sortIndex: nextSort,
            createdAt: now,
            updatedAt: now
        )
        try await db.dbQueue.write { db in
            try folder.insert(db)
        }
        return folder
    }

    func update(_ folder: Folder) async throws {
        var updated = folder
        updated.updatedAt = Date()
        try await db.dbQueue.write { db in
            try updated.update(db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            try Folder.deleteOne(db, key: id)
        }
    }

    func fetch(id: UUID) async throws -> Folder? {
        try await db.dbQueue.read { db in
            try Folder.fetchOne(db, key: id)
        }
    }

    // MARK: - Reorder

    func reorderFolders(ids: [UUID]) async throws {
        try await db.dbQueue.write { db in
            for (index, id) in ids.enumerated() {
                try db.execute(sql: "UPDATE folder SET sortIndex = ? WHERE id = ?",
                               arguments: [index, id.uuidString])
            }
        }
    }

    /// Move a note into a folder (or to root if folderId is nil).
    func moveNote(noteId: UUID, toFolderId: UUID?) async throws {
        try await db.dbQueue.write { db in
            guard var note = try NotePage.fetchOne(db, key: noteId) else { return }
            note.folderId = toFolderId
            note.updatedAt = Date()
            try note.update(db)
        }
    }
}
