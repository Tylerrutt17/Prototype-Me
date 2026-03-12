import SwiftUI
import SwiftData

/// Lists all global directives (Interventions) in the system.
struct DirectivesListView: View {
    @Query(sort: \Intervention.title) private var interventions: [Intervention]
    @State private var searchText: String = ""
    @State private var editMode: EditMode = .inactive
    @Environment(\.modelContext) private var context
    
    private var filtered: [Intervention] {
        guard !searchText.isEmpty else { return interventions }
        return interventions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \Intervention.id) { iv in
                    NavigationLink {
                        InterventionEditorView(intervention: iv)
                    } label: {
                        InterventionRow(intervention: iv, style: .compact)
                            .padding(.vertical,6)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.rowBackground(named: iv.rowBackgroundName) ?? Color(.secondarySystemBackground))
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
            .navigationTitle("Directives")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
            }
            .searchable(text: $searchText)
            .environment(\.editMode, $editMode)
            // navigation handled by NavigationLink in InterventionList
        }
    }
    
    private func delete(at offsets: IndexSet) {
        for idx in offsets { context.delete(filtered[idx]) }
        try? context.save()
    }
}

#Preview {
    let container = try! ModelContainer(for: Intervention.self)
    let ctx = ModelContext(container)
    ctx.insert(Intervention(title: "Test"))
    return DirectivesListView().modelContainer(container)
}
