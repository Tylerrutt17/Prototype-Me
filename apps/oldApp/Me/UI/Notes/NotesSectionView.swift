import SwiftUI
import SwiftData

struct NotesSectionView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            phoneLayout
        } else {
            splitLayout
        }
    }

    // MARK: - Phone (simple recursive view)
    private var phoneLayout: some View {
        NavigationStack {
            FolderContentsView(parentId: nil)
        }
    }

    // MARK: - iPad/Mac
    private var splitLayout: some View {
        NavigationSplitView {
            FolderContentsView(parentId: nil)
        } detail: {
            ContentUnavailableView("Select a page", systemImage: "doc")
        }
    }

    // No extra helpers needed
}

#Preview {
    let mc = try! ModelContainer(for: Folder.self, NotePage.self)
    SeedData.populateIfNeeded(container: mc)
    return NotesSectionView().modelContainer(mc)
}
