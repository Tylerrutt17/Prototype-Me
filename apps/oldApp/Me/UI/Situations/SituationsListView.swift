import SwiftUI
import SwiftData

struct SituationsListView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSituations: [Situation]
    @State private var showNew = false
    // Reordering support
    @State private var editMode: EditMode = .inactive

    private var situations: [Situation] {
        allSituations.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            } else {
                return lhs.order < rhs.order
            }
        }
    }

    var body: some View {
        List {
            ForEach(situations, id: \.id) { sit in
                NavigationLink {
                    SituationDetailView(situation: sit)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.named(sit.colorName))
                                .frame(width: 24, height: 24)
                            Image(systemName: sit.iconSystemName)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                        Text(sit.title)
                    }
                }
            }
            .onDelete(perform: delete)
            .onMove(perform: moveSituations)
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Situations")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            ToolbarItem(placement: .navigationBarTrailing) { Button { add() } label: { Image(systemName: "plus") } }
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets { context.delete(situations[idx]) }
    }

    // MARK: - Reordering helper
    private func moveSituations(from offsets: IndexSet, to destination: Int) {
        var arr = situations
        arr.move(fromOffsets: offsets, toOffset: destination)
        for (idx, s) in arr.enumerated() { s.order = idx }
        try? context.save()
    }

    private func add() {
        let s = Situation(title: "New Situation", order: situations.count)
        context.insert(s)
    }
}
