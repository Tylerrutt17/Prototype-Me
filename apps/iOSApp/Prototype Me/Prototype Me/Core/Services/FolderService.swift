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
                """, arguments: [parentFolderId]) ?? 0
        }
        let folder = Folder(
            id: UUID(),
            name: name,
            parentFolderId: parentFolderId,
            sortIndex: nextSort,
            version: 1,
            createdAt: now,
            updatedAt: now
        )
        try await db.dbQueue.write { db in
            try folder.insert(db)
            try OutboxOp.enqueue(entityType: "folder", entityId: folder.id.uuidString, op: "create", patch: folder.syncPatch(), in: db)
        }
        return folder
    }

    func update(_ folder: Folder) async throws {
        var updated = folder
        updated.updatedAt = Date()
        updated.version += 1
        try await db.dbQueue.write { db in
            try updated.update(db)
            try OutboxOp.enqueue(entityType: "folder", entityId: updated.id.uuidString, op: "update", patch: updated.syncPatch(), baseUpdatedAt: updated.updatedAt, in: db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            // Collect all descendant folder IDs (recursive)
            var folderIdsToDelete: [UUID] = [id]
            var queue: [UUID] = [id]
            while !queue.isEmpty {
                let parentId = queue.removeFirst()
                let children = try Folder.filter(Column("parentFolderId") == parentId).fetchAll(db)
                for child in children {
                    folderIdsToDelete.append(child.id)
                    queue.append(child.id)
                }
            }

            // Update notes whose folderId points to any of these folders
            for fid in folderIdsToDelete {
                let notes = try NotePage.filter(Column("folderId") == fid).fetchAll(db)
                for var note in notes {
                    note.folderId = nil
                    note.version += 1
                    note.updatedAt = Date()
                    try note.update(db)
                    try OutboxOp.enqueue(entityType: "notePage", entityId: note.id.uuidString, op: "update", patch: note.syncPatch(), baseUpdatedAt: note.updatedAt, in: db)
                }
            }

            // Enqueue deletes for all folders (children first)
            for fid in folderIdsToDelete.reversed() {
                try OutboxOp.enqueueDelete(entityType: "folder", entityId: fid.uuidString, in: db)
            }

            // Cascade delete handles subfolders
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
                               arguments: [index, id])
                if let folder = try Folder.fetchOne(db, key: id) {
                    try OutboxOp.enqueue(entityType: "folder", entityId: id.uuidString, op: "update", patch: folder.syncPatch(), baseUpdatedAt: folder.updatedAt, in: db)
                }
            }
        }
    }

    /// Move a folder under a new parent (or to root if parentId is nil).
    func moveFolder(folderId: UUID, toParentId: UUID?) async throws {
        try await db.dbQueue.write { db in
            guard var folder = try Folder.fetchOne(db, key: folderId) else { return }
            folder.parentFolderId = toParentId
            folder.updatedAt = Date()
            folder.version += 1
            try folder.update(db)
            try OutboxOp.enqueue(entityType: "folder", entityId: folderId.uuidString, op: "update", patch: folder.syncPatch(), baseUpdatedAt: folder.updatedAt, in: db)
        }
    }

    /// Move a note into a folder (or to root if folderId is nil).
    func moveNote(noteId: UUID, toFolderId: UUID?) async throws {
        try await db.dbQueue.write { db in
            guard var note = try NotePage.fetchOne(db, key: noteId) else { return }
            note.folderId = toFolderId
            note.updatedAt = Date()
            note.version += 1
            try note.update(db)
            try OutboxOp.enqueue(entityType: "notePage", entityId: noteId.uuidString, op: "update", patch: note.syncPatch(), baseUpdatedAt: note.updatedAt, in: db)
        }
    }
}
