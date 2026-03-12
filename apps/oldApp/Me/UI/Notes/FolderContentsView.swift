import SwiftUI
import SwiftData

/// Displays the contents of a folder: first its sub-folders (alphabetical) then its pages (alphabetical).
/// Pass `parentId == nil` to show the top-level (root) folder list.
struct FolderContentsView: View {
    var parentId: String?

    @Environment(\.modelContext) private var context
    @Query private var allFolders: [Folder]
    @Query private var allPages: [NotePage]
    @Query private var trackables: [Trackable]

    private var folders: [Folder] {
        allFolders
            .filter { $0.parentId == parentId }
            .sorted { lhs, rhs in
                if lhs.order == rhs.order {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                } else {
                    return lhs.order < rhs.order
                }
            }
    }

    private var pages: [NotePage] {
        allPages
            .filter { $0.folderId == parentId }
            .sorted { lhs, rhs in
                if lhs.order == rhs.order {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                } else {
                    return lhs.order < rhs.order
                }
            }
    }

    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var creatingPage = false
    @State private var newPageTitle = ""
    @State private var folderToMove: Folder? = nil
    @State private var pageToMove: NotePage? = nil
    @State private var folderToDelete: Folder? = nil
    @State private var pageToDelete: NotePage? = nil
    @State private var showMoveSheet = false
    @State private var folderToRename: Folder? = nil
    @State private var renameText = ""
    // Reordering support
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            // Sub-folders
            ForEach(folders, id: \.id) { folder in
                NavigationLink(folder.name) {
                    FolderContentsView(parentId: folder.id)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        folderToRename = folder
                        renameText = folder.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
                    Button {
                        folderToMove = folder
                        showMoveSheet = true
                    } label: {
                        Label("Move", systemImage: "folder").tint(.blue)
                    }
                    Button(role: .destructive) {
                        folderToDelete = folder
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: moveFolders)

            // Pages (if any)
            if !pages.isEmpty {
                Section("Pages") {
                    ForEach(pages, id: \.id) { page in
                        NavigationLink {
                            NotePageDetailView(page: page)
                        } label: {
                            NoteRow(page: page)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                pageToMove = page
                                showMoveSheet = true
                            } label: {
                                Label("Move", systemImage: "arrowshape.turn.up.forward").tint(.blue)
                            }
                            Button(role: .destructive) {
                                pageToDelete = page
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: movePages)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(parentId == nil ? "Folders" : folderName(for: parentId!) )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNewFolder = true } label: { Image(systemName: "folder.badge.plus") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { creatingPage = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Name", text: $newFolderName)
            Button("Create") { createFolder() }
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
        .alert("New Note", isPresented: $creatingPage) {
            TextField("Title", text: $newPageTitle)
            Button("Create") { createPage() }
                .disabled(newPageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { newPageTitle = "" }
        }
        .sheet(isPresented: $showMoveSheet) {
            NavigationStack {
                FolderDestinationPicker(allFolders: allFolders,
                                         currentFolderId: folderToMove?.id,
                                         onSelect: { destId in
                                             if let f = folderToMove {
                                                 moveFolder(f, to: destId)
                                             } else if let p = pageToMove {
                                                 movePage(p, to: destId)
                                             }
                                             showMoveSheet = false; folderToMove = nil; pageToMove = nil
                                         })
            }
            .presentationDetents([.medium, .large])
        }
        // Deletion confirmation alerts
        .alert("Delete Folder?", isPresented: .init(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let f = folderToDelete { deleteFolder(f) }
                folderToDelete = nil
            }
            Button("Cancel", role: .cancel) { folderToDelete = nil }
        } message: {
            Text("This will permanently remove the folder and all its contents.")
        }
        .alert("Delete Note?", isPresented: .init(get: { pageToDelete != nil }, set: { if !$0 { pageToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let p = pageToDelete { deletePage(p) }
                pageToDelete = nil
            }
            Button("Cancel", role: .cancel) { pageToDelete = nil }
        } message: {
            Text("This cannot be undone.")
        }
        // Rename alert
        .alert("Rename Folder", isPresented: .init(get: { folderToRename != nil }, set: { if !$0 { folderToRename = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let f = folderToRename {
                    renameFolder(f, to: renameText)
                }
                folderToRename = nil; renameText = ""
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { folderToRename = nil }
        }
    }

    // MARK: - Helpers

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(Folder(name: trimmed, parentId: parentId))
        try? context.save()
        newFolderName = ""
    }

    private func folderName(for id: String) -> String {
        allFolders.first(where: { $0.id == id })?.name ?? "Folder"
    }

    private func createPage() {
        let trimmed = newPageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        context.insert(NotePage(title: trimmed, folderId: parentId))
        try? context.save()
        newPageTitle = ""
    }

    // pageRow removed; now using NoteRow

    // MARK: - CRUD helpers
    private func deleteFolder(_ folder: Folder) {
        FolderService(context: context).deleteFolderCascade(folder)
        try? context.save()
    }

    private func deletePage(_ page: NotePage) {
        guard !page.isSystem else { return }
        context.delete(page)
        try? context.save()
    }

    private func moveFolder(_ folder: Folder, to parent: String?) {
        folder.parentId = parent
        try? context.save()
        folderToMove = nil
    }

    private func movePage(_ page: NotePage, to folderId: String?) {
        page.folderId = folderId
        try? context.save()
        pageToMove = nil
    }

    private func renameFolder(_ folder: Folder, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        try? context.save()
    }

    // MARK: - Reordering helpers
    private func moveFolders(from offsets: IndexSet, to destination: Int) {
        var arr = folders
        arr.move(fromOffsets: offsets, toOffset: destination)
        for (idx, f) in arr.enumerated() { f.order = idx }
        try? context.save()
    }

    private func movePages(from offsets: IndexSet, to destination: Int) {
        var arr = pages
        arr.move(fromOffsets: offsets, toOffset: destination)
        for (idx, p) in arr.enumerated() { p.order = idx }
        try? context.save()
    }
}

// MARK: - Destination picker

private struct FolderDestinationPicker: View {
    let allFolders: [Folder]
    let currentFolderId: String?
    var onSelect: (String?) -> Void

    private struct Row: Identifiable {
        let folder: Folder
        let level: Int
        var id: String { folder.id }
    }

    private func rows() -> [Row] {
        func children(of parent: String?) -> [Folder] {
            allFolders.filter { $0.parentId == parent }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        var result: [Row] = []
        func visit(parent: String?, level: Int) {
            for f in children(of: parent) {
                result.append(Row(folder: f, level: level))
                visit(parent: f.id, level: level + 1)
            }
        }
        visit(parent: nil, level: 0)
        return result
    }

    var body: some View {
        List {
            Button("Root") { onSelect(nil) }
            ForEach(rows()) { row in
                Button(action: { onSelect(row.folder.id) }) {
                    HStack {
                        Text(row.folder.name)
                            .padding(.leading, CGFloat(row.level) * 12)
                        if row.folder.id == currentFolderId {
                            Spacer(); Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle("Move To…")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onSelect(currentFolderId) } } }
    }
}

#Preview {
    let mc = try! ModelContainer(for: Folder.self, NotePage.self)
    let ctx = ModelContext(mc)
    let root = Folder(name: "Work"); let sub = Folder(name: "Project", parentId: root.id)
    ctx.insert(root); ctx.insert(sub); ctx.insert(NotePage(title: "Notes", folderId: sub.id))
    return NavigationStack { FolderContentsView(parentId: nil) }.modelContainer(mc)
}
