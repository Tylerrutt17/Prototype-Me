import SwiftUI
import SwiftData

struct RoadmapsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Roadmap.createdAt) private var roadmaps: [Roadmap]

    // State for renaming roadmaps
    @State private var roadmapToRename: Roadmap? = nil
    @State private var newName: String = ""

    // State for delete confirmation
    @State private var roadmapToDelete: Roadmap? = nil

    var body: some View {
        List {
            ForEach(roadmaps) { roadmap in
                NavigationLink(value: roadmap) {
                    Text(roadmap.name)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        roadmapToDelete = roadmap
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        newName = roadmap.name
                        roadmapToRename = roadmap
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("Roadmaps")
        .toolbar {
            Button {
                createRoadmap()
            } label: {
                Image(systemName: "plus")
            }
        }
        .navigationDestination(for: Roadmap.self) { roadmap in
            RoadmapDetailView(roadmap: roadmap)
        }

        // Rename alert with text field
        .alert("Rename Roadmap", isPresented: Binding<Bool>(
            get: { roadmapToRename != nil },
            set: { isShowing in
                if !isShowing { roadmapToRename = nil }
            }
        ), actions: {
            TextField("Name", text: $newName)
            Button("Save") {
                if let rm = roadmapToRename {
                    rm.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                roadmapToRename = nil
            }
            Button("Cancel", role: .cancel) {
                roadmapToRename = nil
            }
        })

        // Delete confirmation alert
        .alert("Delete Roadmap?", isPresented: Binding<Bool>(
            get: { roadmapToDelete != nil },
            set: { isShowing in
                if !isShowing { roadmapToDelete = nil }
            }
        ), actions: {
            Button("Delete", role: .destructive) {
                if let rm = roadmapToDelete { deleteRoadmap(rm) }
                roadmapToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                roadmapToDelete = nil
            }
        }, message: {
            if let rm = roadmapToDelete {
                Text("This will permanently delete \(rm.name).")
            }
        })
    }

    private func createRoadmap() {
        let rm = Roadmap(name: "Untitled")
        context.insert(rm)
    }

    private func deleteRoadmap(_ roadmap: Roadmap) {
        context.delete(roadmap)
    }
}

#Preview {
    let container = try! ModelContainer(for: Roadmap.self, RoadmapNode.self)
    return NavigationStack { RoadmapsListView() }
        .modelContainer(container)
}
