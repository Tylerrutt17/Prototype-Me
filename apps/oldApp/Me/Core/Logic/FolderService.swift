import Foundation
import SwiftData

/// Simple helper for common Folder CRUD operations.
struct FolderService {
    let context: ModelContext

    /// Creates a folder under an optional parent.
    @discardableResult
    func createFolder(named name: String, parentId: String? = nil) -> Folder {
        let folder = Folder(name: name, parentId: parentId)
        context.insert(folder)
        return folder
    }

    /// Renames the given folder.
    func renameFolder(_ folder: Folder, to newName: String) {
        folder.name = newName
    }

    /// Deletes folder only if empty (legacy). Returns success.
    func deleteFolderIfEmpty(_ folder: Folder) -> Bool {
        let folderId = folder.id
        let fid: String? = folderId
        let hasSubfolders = (try? context.fetchCount(FetchDescriptor<Folder>(predicate: #Predicate { $0.parentId == fid }))) ?? 0 > 0
        let hasPages = (try? context.fetchCount(FetchDescriptor<NotePage>(predicate: #Predicate { $0.folderId == fid }))) ?? 0 > 0
        guard !hasSubfolders && !hasPages else { return false }
        context.delete(folder)
        return true
    }

    /// Permanently deletes the folder and *all* its subfolders and pages.
    func deleteFolderCascade(_ folder: Folder) {
        // Delete pages in this folder
        let thisId: String? = folder.id
        let pages = (try? context.fetch(FetchDescriptor<NotePage>(predicate: #Predicate { $0.folderId == thisId }))) ?? []
        for p in pages { context.delete(p) }

        // Recursively delete child folders
        let children = (try? context.fetch(FetchDescriptor<Folder>(predicate: #Predicate { $0.parentId == thisId }))) ?? []
        for child in children { deleteFolderCascade(child) }

        // Finally delete this folder
        context.delete(folder)
    }
}
