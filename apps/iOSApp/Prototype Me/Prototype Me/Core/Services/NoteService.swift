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
        try await db.safeWrite { db in
            try note.insert(db)
            try OutboxOp.enqueue(entityType: "notePage", entityId: note.id.uuidString, op: "create", patch: note.syncPatch(), in: db)
        }
        return note
    }

    func update(_ note: NotePage) async throws {
        var updated = note
        updated.updatedAt = Date()
        updated.version += 1
        try await db.safeWrite { db in
            try updated.update(db)
            try OutboxOp.enqueue(entityType: "notePage", entityId: updated.id.uuidString, op: "update", patch: updated.syncPatch(), baseUpdatedAt: updated.updatedAt, in: db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await db.safeWrite { db in
            try NotePage.deleteOne(db, key: id)
            try OutboxOp.enqueueDelete(entityType: "notePage", entityId: id.uuidString, in: db)
        }
    }

    func fetch(id: UUID) async throws -> NotePage? {
        try await db.dbQueue.read { db in
            try NotePage.fetchOne(db, key: id)
        }
    }

    // MARK: - Directive Links

    func linkDirective(noteId: UUID, directiveId: UUID) async throws {
        try await db.safeWrite { db in
            try db.execute(sql: """
                UPDATE noteDirective SET sortIndex = sortIndex + 1 WHERE noteId = ?
                """, arguments: [noteId])
            let link = NoteDirective(noteId: noteId, directiveId: directiveId, sortIndex: 0, createdAt: Date())
            try link.insert(db)
            try OutboxOp.enqueue(entityType: "noteDirective", entityId: "\(noteId.uuidString)|\(directiveId.uuidString)", op: "create", patch: link.syncPatch(), in: db)
        }
    }

    func unlinkDirective(noteId: UUID, directiveId: UUID) async throws {
        try await db.safeWrite { db in
            // Get the sortIndex of the link being removed
            let removedIndex = try Int.fetchOne(db, sql: """
                SELECT sortIndex FROM noteDirective WHERE noteId = ? AND directiveId = ?
                """, arguments: [noteId, directiveId])

            try db.execute(sql: """
                DELETE FROM noteDirective WHERE noteId = ? AND directiveId = ?
                """, arguments: [noteId, directiveId])
            try OutboxOp.enqueueDelete(entityType: "noteDirective", entityId: "\(noteId.uuidString)|\(directiveId.uuidString)", in: db)

            // Close the gap: decrement sortIndex for all links that came after
            if let removedIndex {
                try db.execute(sql: """
                    UPDATE noteDirective SET sortIndex = sortIndex - 1
                    WHERE noteId = ? AND sortIndex > ?
                    """, arguments: [noteId, removedIndex])

                // Enqueue sync updates for the shifted links
                let shifted = try NoteDirective
                    .filter(Column("noteId") == noteId && Column("sortIndex") >= removedIndex)
                    .fetchAll(db)
                for link in shifted {
                    try OutboxOp.enqueue(entityType: "noteDirective", entityId: "\(noteId.uuidString)|\(link.directiveId.uuidString)", op: "update", patch: link.syncPatch(), in: db)
                }
            }
        }
    }

    func reorderDirectives(noteId: UUID, directiveIds: [UUID]) async throws {
        try await db.safeWrite { db in
            for (index, dirId) in directiveIds.enumerated() {
                try db.execute(sql: """
                    UPDATE noteDirective SET sortIndex = ? WHERE noteId = ? AND directiveId = ?
                    """, arguments: [index, noteId, dirId])
            }
            // Enqueue updates for each reordered link
            for dirId in directiveIds {
                if let link = try NoteDirective.filter(Column("noteId") == noteId && Column("directiveId") == dirId).fetchOne(db) {
                    try OutboxOp.enqueue(entityType: "noteDirective", entityId: "\(noteId.uuidString)|\(dirId.uuidString)", op: "update", patch: link.syncPatch(), in: db)
                }
            }
        }
    }

    // MARK: - Reorder

    func reorderNotes(ids: [UUID]) async throws {
        try await db.safeWrite { db in
            for (index, id) in ids.enumerated() {
                try db.execute(sql: "UPDATE notePage SET sortIndex = ? WHERE id = ?",
                               arguments: [index, id])
                if let note = try NotePage.fetchOne(db, key: id) {
                    try OutboxOp.enqueue(entityType: "notePage", entityId: id.uuidString, op: "update", patch: note.syncPatch(), baseUpdatedAt: note.updatedAt, in: db)
                }
            }
        }
    }

    // MARK: - Move to Folder

    func moveToFolder(noteId: UUID, folderId: UUID?) async throws {
        try await db.safeWrite { db in
            guard var note = try NotePage.fetchOne(db, key: noteId) else { return }
            note.folderId = folderId
            note.updatedAt = Date()
            note.version += 1
            try note.update(db)
            try OutboxOp.enqueue(entityType: "notePage", entityId: noteId.uuidString, op: "update", patch: note.syncPatch(), baseUpdatedAt: note.updatedAt, in: db)
        }
    }
}
