    import SwiftUI
    import Observation
    import SwiftData
    import RichEditorSwiftUI

struct RoadmapNodeEditorSheet: View {
    @Bindable var node: RoadmapNode
    @State private var editorState: RichEditorState

    // Data sources
    @Query(sort: \NotePage.title) private var pages: [NotePage]
    @Query(sort: \Intervention.title) private var interventions: [Intervention]

    // UI state
    @State private var showingPicker = false
    @State private var creatingNew = false // for new note
    @State private var creatingIntervention = false // for new directive
    @State private var linkSearch = ""
    @State private var editMode: EditMode = .inactive
    @AppStorage("roadmapListModeIndex") private var listModeIdx: Int = 0
    private var listModeBinding: Binding<InterventionRow.RowStyle> {
        Binding(get: {
            let cases = InterventionRow.RowStyle.allCases
            return (listModeIdx >= 0 && listModeIdx < cases.count) ? cases[listModeIdx] : .compact
        }, set: { newVal in
            if let idx = InterventionRow.RowStyle.allCases.firstIndex(of: newVal) { listModeIdx = idx }
        })
    }

    /// Custom init to ensure consistent editor background (clear like NotePageDetailView)
    init(node: RoadmapNode) {
        self._node = Bindable(wrappedValue: node)
        self._editorState = State(initialValue: node.makeEditorState())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $node.title)
                }

                linksSection

                Section("Description") {
                    RichNoteField(model: node, state: editorState)
                        .frame(minHeight: 250, alignment: .top)
                }

                Section("Color") {
                    let palette: [String] = ["red", "orange", "yellow", "green", "blue", "indigo", "purple", "gray"]

                    HStack(spacing: 12) {
                        ForEach(palette, id: \.self) { name in
                            let color = Color.named(name)
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: node.colorName == name ? 3 : 0)
                                )
                                .onTapGesture {
                                    node.colorName = name
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .padding(.top, 15)
            .environment(\.editMode, $editMode)
            .navigationTitle("Edit Node")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { creatingIntervention = true }) {
                        Image(systemName: "plus.app")
                    }
                    Button(action: { showingPicker = true }) {
                        Image(systemName: "link.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingPicker) { linkPicker }
            .sheet(isPresented: $creatingNew) { newNoteSheet }
            .sheet(isPresented: $creatingIntervention) { newInterventionSheet }
#if os(iOS)
            .safeAreaInset(edge: .bottom, alignment: .center) {
                RichTextKeyboardToolbar(
                    context: editorState,
                    leadingButtons: { $0 },
                    trailingButtons: { $0 },
                    formatSheet: { $0 }
                )
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
#endif
        }
    }

    // MARK: - Links Section
    private var linksSection: some View {
        Group {
            Section("Linked Directives") {
                Picker("View", selection: listModeBinding) {
                    ForEach([InterventionRow.RowStyle.compact, .detailed, .titleOnly], id: \.self) { style in
                        Text(label(for: style)).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                if linkedInterventions.isEmpty {
                    Text("No directives linked").foregroundStyle(.secondary)
                }
                ForEach(linkedInterventions, id: \Intervention.id) { iv in
                    NavigationLink {
                        InterventionEditorView(intervention: iv)
                    } label: {
                        InterventionRow(intervention: iv, style: listModeBinding.wrappedValue)
                            .padding(.vertical,6)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.rowBackground(named: iv.rowBackgroundName) ?? Color(.secondarySystemBackground))
                }
                .onDelete(perform: removeInterventions)
                .onMove(perform: moveInterventions)
            }

            Section("Linked Pages") {
                if linkedPages.isEmpty {
                    Text("No pages linked").foregroundStyle(.secondary)
                }
                ForEach(linkedPages, id: \.id) { p in
                    NavigationLink {
                        NotePageDetailView(page: p)
                    } label: {
                        Text(p.title)
                    }
                }
                .onDelete { idx in removePages(at: idx) }
                .onMove(perform: movePages)
            }
        }
    }

    // Computed link arrays
    private var linkedPages: [NotePage] {
        node.pageIds.compactMap { id in pages.first(where: { $0.id == id }) }
    }

    @State private var selected: Intervention? = nil

    private var linkedInterventions: [Intervention] {
        node.interventionIds.compactMap { id in interventions.first(where: { $0.id == id }) }
    }

    // MARK: Actions
    private func removePages(at offsets: IndexSet) {
        for i in offsets {
            let id = linkedPages[i].id
            node.pageIds.removeAll { $0 == id }
        }
    }

    private func movePages(from offsets: IndexSet, to destination: Int) {
        var ids = node.pageIds
        ids.move(fromOffsets: offsets, toOffset: destination)
        node.pageIds = ids
    }

    private func removeInterventions(at offsets: IndexSet) {
        for i in offsets {
            let id = linkedInterventions[i].id
            node.interventionIds.removeAll { $0 == id }
        }
    }

    private func moveInterventions(from offsets: IndexSet, to destination: Int) {
        var ids = node.interventionIds
        ids.move(fromOffsets: offsets, toOffset: destination)
        node.interventionIds = ids
    }

    // MARK: Picker Sheet
    private var linkPicker: some View {
        NavigationStack {
            Form {
                TextField("Search…", text: $linkSearch)
                    .textFieldStyle(.roundedBorder)
                Section("Pages") {
                    ForEach(filteredPages, id: \.id) { p in
                        Toggle(p.title, isOn: Binding(
                            get: { node.pageIds.contains(p.id) },
                            set: { newVal in
                                if newVal {
                                    if !node.pageIds.contains(p.id) { node.pageIds.append(p.id) }
                                } else {
                                    node.pageIds.removeAll { $0 == p.id }
                                }
                            }))
                    }
                }
                Section("Directives") {
                    ForEach(filteredInterventions, id: \.id) { iv in
                        Toggle(iv.title, isOn: Binding(
                            get: { node.interventionIds.contains(iv.id) },
                            set: { newVal in
                                if newVal {
                                    if !node.interventionIds.contains(iv.id) { node.interventionIds.append(iv.id) }
                                } else {
                                    node.interventionIds.removeAll { $0 == iv.id }
                                }
                            }))
                    }
                }
            }
            .navigationTitle("Add Links")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingPicker = false }
                }
            }
        }
    }

    // New note sheet
    @Environment(\.modelContext) private var context
    private var newNoteSheet: some View {
        NavigationStack {
            let newPage = NotePage(title: "New Note")
            NotePageDetailView(page: newPage)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { context.delete(newPage); creatingNew = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            context.insert(newPage)
                            node.pageIds.append(newPage.id)
                            creatingNew = false
                        }
                    }
                }
        }
    }

    // New directive sheet
    private var newInterventionSheet: some View {
        NavigationStack {
            let newIv = Intervention(title: "New Directive")
            InterventionEditorView(intervention: newIv)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { context.delete(newIv); creatingIntervention = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            context.insert(newIv)
                            node.interventionIds.append(newIv.id)
                            creatingIntervention = false
                        }
                    }
                }
        }
    }

    private var filteredPages: [NotePage] {
        guard !linkSearch.isEmpty else { return pages }
        return pages.filter { $0.title.localizedCaseInsensitiveContains(linkSearch) }
    }

    private var filteredInterventions: [Intervention] {
        guard !linkSearch.isEmpty else { return interventions }
        return interventions.filter { $0.title.localizedCaseInsensitiveContains(linkSearch) }
    }

    // MARK: - Compact directive row matching NotePage default list
    private struct DirectiveCompactRow: View {
        let intervention: Intervention

        var body: some View {
            HStack {
                Text(intervention.title)
                    .foregroundStyle(trackableColor(for: intervention))
                Spacer()
                Text("P\(intervention.priority)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(priorityColor(intervention.priority))
                    .foregroundStyle(Color.white)
                    .cornerRadius(4)
            }
            .padding(.vertical, 2)
        }

        private func priorityColor(_ value: Int) -> Color {
            let ratio = Double(max(0, min(100, value))) / 100.0
            let hue = 0.33 - 0.33 * ratio
            return Color(hue: hue, saturation: 0.9, brightness: 0.9)
        }

        private func trackableColor(for iv: Intervention) -> Color {
            if let cname = iv.colorName { return Color.named(cname) }
            return .primary
        }
    }

    // Helper to map style to label
    private func label(for style: InterventionRow.RowStyle) -> String {
        switch style {
        case .compact: return "Default"
        case .detailed: return "Detailed"
        case .titleOnly: return "Titles"
        case .badge: return "Badge" // not used but for completeness
        }
    }
}
