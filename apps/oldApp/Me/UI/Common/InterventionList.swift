import SwiftUI
import SwiftData

/// A fully custom, edge-to-edge scrollable list of `InterventionRow`s.
/// This avoids UIKitʼs `List` container so row backgrounds (or any other layout)
/// can span the entire width and height of each cell.
struct InterventionList: View {
    let interventions: [Intervention]
    var style: InterventionRow.RowStyle = .compact
    var showSeparators: Bool = false
    /// Optional move handler enabling drag-to-reorder support when supplied.
    private let onMove: ((IndexSet, Int) -> Void)?

    /// Optional destination builder. When supplied, each row is wrapped in a `NavigationLink` pushing this destination.
    private let destination: ((Intervention) -> AnyView)?
    /// Fallback tap handler used when no destination is provided.
    private let onSelect: (Intervention) -> Void

    init(interventions: [Intervention],
         style: InterventionRow.RowStyle = .compact,
         showSeparators: Bool = false,
         onMove: ((IndexSet, Int) -> Void)? = nil,
         destination: ((Intervention) -> AnyView)? = nil,
         onSelect: @escaping (Intervention) -> Void = { _ in }) {
        self.interventions = interventions
        self.style = style
        self.showSeparators = showSeparators
        self.destination = destination
        self.onMove = onMove
        self.onSelect = onSelect
    }

    var body: some View {
        // When a move handler is supplied, we switch to SwiftUIʼs native `List`
        // which provides built-in drag-to-reorder support. Otherwise we keep the
        // custom ScrollView implementation.
        if let move = onMove {
            List {
                // Enumerate to know position and selectively hide top/bottom separators
                ForEach(Array(interventions.enumerated()), id: \.1.id) { index, iv in
                    let isFirst = index == 0
                    let isLast  = index == interventions.count - 1

                    row(for: iv)
                        .listRowInsets(EdgeInsets())
                        // Base visibility for between-row dividers
                        .listRowSeparator(showSeparators ? .visible : .hidden)
                        // Hide the very first dividerʼs top edge
                        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                        // Hide the very last dividerʼs bottom edge
                        .listRowSeparator(isLast  ? .hidden : .visible, edges: .bottom)
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            // Remove default background so rows can span full width like before.
            .scrollContentBackground(.hidden)
            // Disable List's own scrolling so it expands to fit content within parent scroll views.
            .scrollDisabled(true)
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(interventions, id: \Intervention.id) { iv in
                        row(for: iv)

                        if showSeparators, iv.id != interventions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for iv: Intervention) -> some View {
        let rowBackground = rowBackgroundColor(for: iv)

        if let dest = destination?(iv) {
            NavigationLink(destination: { dest }) {
                InterventionRow(intervention: iv, style: style)
                    .padding(.vertical, 6)
            }
                .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
        } else {
            Button(action: { onSelect(iv) }) {
                InterventionRow(intervention: iv, style: style)
                    .padding(.vertical, 6)
            }
                .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
        }
    }

    // MARK: - Helpers
    private func rowBackgroundColor(for iv: Intervention) -> Color {
        return Color.rowBackground(named: iv.rowBackgroundName) ?? Color.clear
    }
}

#if DEBUG
struct InterventionListPreview: View {
    var body: some View {
        let container = try! ModelContainer(for: Intervention.self)
        let ctx = ModelContext(container)
        for i in 1...5 { ctx.insert(Intervention(title: "Sample \(i)")) }
        let ivs = (try? ctx.fetch(FetchDescriptor<Intervention>())) ?? []
        return NavigationStack {
            InterventionList(interventions: ivs, style: .badge, showSeparators: true, destination: { iv in
                AnyView(Text("Editing \(iv.title)"))
            })
        }
        .modelContainer(container)
    }
}
#endif
