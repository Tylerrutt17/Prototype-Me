import Foundation
import GRDB

/// Owns all write operations for NotePage and NoteDirective links.
final class NoteService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - CRUD

    func create(title: String, body: String = "", kind: NoteKind = .regular, folderId: UUID? = nil) async throws -> NotePage {
        let now = Date()
        let note = NotePage(
            id: UUID(),
            title: title,
            body: body,
            kind: kind,
            folderId: folderId,
            sortIndex: 0,
            version: 1,
            createdAt: now,
            updatedAt: now
        )
        try await db.dbQueue.write { db in
            try note.insert(db)
        }
        return note
    }

    func update(_ note: NotePage) async throws {
        var updated = note
        updated.updatedAt = Date()
        updated.version += 1
        try await db.dbQueue.write { db in
            try updated.update(db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            // Cascade delete handles noteDirective + activeMode cleanup
            try NotePage.deleteOne(db, key: id)
        }
    }

    func fetch(id: UUID) async throws -> NotePage? {
        try await db.dbQueue.read { db in
            try NotePage.fetchOne(db, key: id)
        }
    }

    // MARK: - Directive Links

    func linkDirective(noteId: UUID, directiveId: UUID) async throws {
        try await db.dbQueue.write { db in
            let maxSort = try Int.fetchOne(db, sql: """
                SELECT COALESCE(MAX(sortIndex), -1) FROM noteDirective WHERE noteId = ?
                """, arguments: [noteId.uuidString]) ?? -1
            let link = NoteDirective(noteId: noteId, directiveId: directiveId, sortIndex: maxSort + 1, createdAt: Date())
            try link.insert(db)
        }
    }

    func unlinkDirective(noteId: UUID, directiveId: UUID) async throws {
        try await db.dbQueue.write { db in
            try db.execute(sql: """
                DELETE FROM noteDirective WHERE noteId = ? AND directiveId = ?
                """, arguments: [noteId.uuidString, directiveId.uuidString])
        }
    }

    func reorderDirectives(noteId: UUID, directiveIds: [UUID]) async throws {
        try await db.dbQueue.write { db in
            for (index, dirId) in directiveIds.enumerated() {
                try db.execute(sql: """
                    UPDATE noteDirective SET sortIndex = ? WHERE noteId = ? AND directiveId = ?
                    """, arguments: [index, noteId.uuidString, dirId.uuidString])
            }
        }
    }

    // MARK: - Reorder

    func reorderNotes(ids: [UUID]) async throws {
        try await db.dbQueue.write { db in
            for (index, id) in ids.enumerated() {
                try db.execute(sql: "UPDATE notePage SET sortIndex = ? WHERE id = ?",
                               arguments: [index, id.uuidString])
            }
        }
    }

    // MARK: - Move to Folder

    func moveToFolder(noteId: UUID, folderId: UUID?) async throws {
        try await db.dbQueue.write { db in
            guard var note = try NotePage.fetchOne(db, key: noteId) else { return }
            note.folderId = folderId
            note.updatedAt = Date()
            note.version += 1
            try note.update(db)
        }
    }
}
