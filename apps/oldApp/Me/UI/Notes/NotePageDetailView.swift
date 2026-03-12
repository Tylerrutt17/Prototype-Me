import SwiftUI
import SwiftData
import Combine
import SPIndicator
import RichEditorSwiftUI

struct NotePageDetailView: View {
    @Bindable var page: NotePage

    // Custom init to seed attributed string immediately
    init(page: NotePage) {
        self._page = Bindable(wrappedValue: page)
        self._editorState = State(initialValue: page.makeEditorState())
    }

    @Environment(\.modelContext) private var context
    @State private var showNewAlert = false
    @State private var newTitle = ""

    // Allowed quick-pick colors (static avoids binding overload)
    private static let colorNames: [String] = ["red","orange","yellow","green","blue","indigo","violet","gray"]
    @State private var editorState: RichEditorState
    @Query private var trackables: [Trackable]
    @State private var dailyEnabled: Bool = false
    @Query(sort: \Intervention.title) private var allInterventions: [Intervention]
    // Color names for picker
    private let colorNames: [String] = ["red","orange","yellow","green","blue","indigo","purple","gray"]
    @State private var showLinkSheet = false
    // Keyboard toolbar support
    @State private var keyboardVisible: Bool = false

    // MARK: - Intervention list view mode
    private enum InterventionListMode: String, CaseIterable, Identifiable {
        case compact = "Default"
        case detailed = "Detailed"
        case simple = "Titles" // new mode showing only titles
        var id: Self { self }
    }

    // Initialize list mode from persisted index to avoid a visible jump on first render
    @State private var listModeState: InterventionListMode = {
        let idx = UserDefaults.standard.integer(forKey: "interventionListModeIndex")
        let cases = InterventionListMode.allCases
        return (idx >= 0 && idx < cases.count) ? cases[idx] : .compact
    }()
    // We still keep an AppStorage binding so changes propagate back to UserDefaults
    @AppStorage("interventionListModeIndex") private var listModeIdx: Int = 0

    private var listMode: InterventionListMode {
        let cases = InterventionListMode.allCases
        return (listModeIdx >= 0 && listModeIdx < cases.count) ? cases[listModeIdx] : .compact
    }

    // Existing SwiftData settings kept for compatibility but no longer used for list mode
    private var settings: AppSettings { AppSettings.shared(in: context) }

    // MARK: - Extracted Section Views to aid type-checking
    private var titleSection: some View {
        Section("Title") {
            TextField("Title", text: $page.title)
                .foregroundStyle(tintColor)
        }
    }

    private var bodyEditorSection: some View {
        Section("Body") {
            RichNoteField(model: page, state: editorState)
                .frame(minHeight: 250, maxHeight: .infinity, alignment: .top)
        }
    }

    private var interventionsSection: some View {
        // Interventions visually named as "Directives"
        Section("Directives") {
            Picker("View", selection: $listModeState) {
                ForEach(InterventionListMode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            // no explicit onAppear needed; state is already correctly initialized
            .onChange(of: listModeState) { newVal in
                if let idx = InterventionListMode.allCases.firstIndex(of: newVal) {
                    listModeIdx = idx // persist index
                }
#if DEBUG
                print("🗄️ AppStorage saved index = \(listModeIdx)")
                print("💾 Saved list mode = \(newVal.rawValue)")
#endif
            }

            if (page.interventions?.isEmpty ?? true) && page.linkedInterventionIds.isEmpty {
                Button {
                    showNewAlert = true
                } label: {
                    ContentUnavailableView("No directives yet", systemImage: "plus")
                }
                .buttonStyle(.plain) // keep default look
            }

            ForEach(displayedInterventions(), id: \Intervention.id) { iv in
                NavigationLink {
                    InterventionEditorView(intervention: iv)
                } label: {
                    InterventionRow(intervention: iv,
                                     style: listModeState == .compact ? .compact : (listModeState == .detailed ? .detailed : .titleOnly))
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.visible)
                .listRowBackground(Color.rowBackground(named: iv.rowBackgroundName) ?? Color(.secondarySystemBackground))
            }
            .onDelete(perform: deleteInterventions)
            .onMove(perform: moveInterventions)
        }
    }

    private var dailyCurationSection: some View {
        Section("Daily Curation") {
            Toggle("Enable Daily Curation", isOn: $dailyEnabled.animation())
            if dailyEnabled {
                Picker("Trackable", selection: $page.trackableId) {
                    Text("Any").tag(Optional<String>(nil))
                    ForEach(trackables, id: \.id) { t in
                        Text(t.name).tag(Optional<String>(t.id))
                    }
                }
                if page.trackableId != nil {
                    severityControls
                }
                priorityControls
            }
        }
        .onChange(of: dailyEnabled) { newVal in
            if !newVal {
                page.minSeverity = 0
                page.maxSeverity = 10
                page.priority = 0
                page.isEveryDay = false
                page.trackableId = nil
            }
        }
    }

    private var colorSection: some View {
        Section("Title Color") {
            Picker("Color", selection: Binding(get: { page.colorName ?? "" }, set: { val in page.colorName = val.isEmpty ? nil : val })) {
                Text("Default").tag("")
                ForEach(colorNames, id: \.self) { name in
                    HStack {
                        Circle().fill(Color.named(name)).frame(width: 20, height: 20)
                        Text(name.capitalized)
                    }.tag(name)
                }
            }
        }
    }

    // MARK: - Add menu for navigation bar
    private var addMenu: some View {
        Menu {
            Button("New Directive") { showNewAlert = true } // visually renamed
            Button("Link Directives") { showLinkSheet = true } // visually renamed
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - Main body composed of smaller sections
    var body: some View {
        Form {
            titleSection
            interventionsSection
            bodyEditorSection
            AudioAttachmentsSection(note: page)
            dailyCurationSection
            colorSection
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: HStack {
            Button(action: togglePin) {
                Image(systemName: page.isPinned ? "pin.fill" : "pin")
            }
            Button(action: toggleWorkingOn) {
                Image(systemName: page.isWorkingOn ? "hammer.fill" : "hammer")
            }
            addMenu
        })
        .alert("New Directive", isPresented: $showNewAlert) {
            TextField("Title", text: $newTitle)
            Button("Create") { createIntervention() }
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { newTitle = "" }
        }
        .onAppear {
            dailyEnabled = page.trackableId != nil || page.isEveryDay || page.priority > 0 || page.minSeverity != 0 || page.maxSeverity != 10
        }
        .sheet(isPresented: $showLinkSheet) { linkPicker }
        // navigation handled in InterventionList rows
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

    private func createIntervention() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Create a *global* directive (Intervention) that is merely **linked** to this note.
        // It no longer lives inside the NotePage, avoiding accidental deletion when un-linking.
        let i = Intervention(title: trimmed)
        context.insert(i)               // persist new directive first to obtain its id

        // Link by id – this drives display ordering without owning the object.
        page.linkedInterventionIds.append(i.id)
        try? context.save()
        newTitle = ""
    }

    // MARK: Row helpers
    private func priorityColor(_ value: Int) -> Color {
        let ratio = Double(value) / 100.0
        let hue = 0.33 - 0.33 * ratio
        return Color(hue: hue, saturation: 0.9, brightness: 0.9)
    }
    private func severityLabel(_ i: Intervention) -> String {
        if i.minSeverity == i.maxSeverity { return "=\(i.minSeverity)" }
        if i.minSeverity == 0 { return "≤\(i.maxSeverity)" }
        if i.maxSeverity == 10 { return "≥\(i.minSeverity)" }
        return "\(i.minSeverity)–\(i.maxSeverity)"
    }

    // MARK: Shared sub-controls (mirroring InterventionEditorView)
    @State private var severityMode: SeverityMode = .atLeast

    private var severityControls: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Mode", selection: $severityMode) {
                    ForEach(SeverityMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented).frame(width: 120)
                Spacer()
                Text(thresholdLabel())
            }
            Slider(value: Binding(get: { Double(thresholdValue()) }, set: { updateThreshold(Int($0)) }), in: 0...10, step: 1)
                .tint(severityColor(thresholdValue()))
            Text(explanationText())
                .font(.caption).foregroundStyle(.secondary).padding(.top,2)
        }
    }

    private var priorityControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Priority: \(page.priority)")
                Spacer()
                Text(priorityLabel(page.priority))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { Double(page.priority) }, set: { page.priority = Int($0) }), in: 0...100, step: 1)
                .tint(priorityColor(page.priority))
            Toggle("Every day", isOn: $page.isEveryDay)
            Text("Higher priority shows earlier in the daily list. 0 = lowest, 100 = highest.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // Helper funcs copied
    private func severityColor(_ value: Int) -> Color {
        let ratio = Double(value) / 10.0
        let hue = 0.33 - 0.33 * ratio
        return Color(hue: hue, saturation: 0.9, brightness: 0.9)
    }
    private func priorityLabel(_ value: Int) -> String {
        switch value { case 0...25: return "Low"; case 26...60: return "Medium"; case 61...85: return "High"; default: return "Critical" }
    }
    private func thresholdValue() -> Int {
        switch severityMode {
        case .atLeast: return page.minSeverity
        case .atMost: return page.maxSeverity
        case .equal: return page.minSeverity
        }
    }
    private func updateThreshold(_ v: Int) {
        switch severityMode {
        case .atLeast: page.minSeverity = v; page.maxSeverity = 10
        case .atMost: page.minSeverity = 0; page.maxSeverity = v
        case .equal: page.minSeverity = v; page.maxSeverity = v
        }
    }
    private func thresholdLabel() -> String { "Level \(thresholdValue())" }
    private func explanationText() -> String {
        switch severityMode {
        case .atLeast: return "Appears when level is ≥ \(thresholdValue())."
        case .atMost: return "Appears when level is ≤ \(thresholdValue())."
        case .equal: return "Appears only when level is exactly \(thresholdValue())."
        }
    }

    // MARK: - Reordering helpers
    private func displayedInterventions() -> [Intervention] {
        let linkedPairs: [(idx: Int, iv: Intervention)] = page.linkedInterventionIds.enumerated().compactMap { (idx, id) in
            allInterventions.first(where: { $0.id == id }).map { (idx, $0) }
        }
        var entries: [(order: Int, iv: Intervention)] = []
        for iv in page.interventions ?? [] { entries.append((iv.order, iv)) }
        for pair in linkedPairs { entries.append((pair.idx, pair.iv)) }
        return entries.sorted { $0.order < $1.order }.map { $0.iv }
    }

    private func moveInterventions(from offsets: IndexSet, to destination: Int) {
        var arr = displayedInterventions()
        arr.move(fromOffsets: offsets, toOffset: destination)
        var newLinked: [String] = []
        for (idx, iv) in arr.enumerated() {
            if iv.pageId == page.id {
                iv.order = idx
            } else {
                newLinked.append(iv.id)
            }
        }
        page.linkedInterventionIds = newLinked
        try? context.save()
    }

    private func deleteInterventions(at idxSet: IndexSet) {
        let arr = displayedInterventions()
        for idx in idxSet {
            let iv = arr[idx]

            // Always unlink the directive from this note; do **not** delete the directive itself.
            page.linkedInterventionIds.removeAll { $0 == iv.id }

            // Legacy embedded directives (created before this change) may still reside in
            // the `interventions` relationship. Remove such references to keep data clean.
            if iv.pageId == page.id {
                page.interventions?.removeAll { $0.id == iv.id }
            }
        }

        try? context.save()
    }

    /// Iterates through all NotePages to drop references to a deleted intervention.
    private func removeLinks(to interventionId: String) {
        if let pages = try? context.fetch(FetchDescriptor<NotePage>()) {
            for p in pages {
                if p.linkedInterventionIds.contains(interventionId) {
                    p.linkedInterventionIds.removeAll { $0 == interventionId }
                }
            }
        }
    }

    // MARK: Link picker
    @State private var linkSearch = ""
    private var linkPicker: some View {
        NavigationStack {
            Form {
                TextField("Search…", text: $linkSearch).textFieldStyle(.roundedBorder)
                Section {
                    ForEach(filteredInterventions(), id: \.id) { iv in
                        Toggle(iv.title, isOn: Binding(get: { page.linkedInterventionIds.contains(iv.id) }, set: { val in
                            if val {
                                if !page.linkedInterventionIds.contains(iv.id) { page.linkedInterventionIds.append(iv.id) }
                            } else {
                                page.linkedInterventionIds.removeAll { $0 == iv.id }
                            }
                        }))
                    }
                } footer: { Text("Select directives to reuse in this note.") } // visually renamed
            }
            .navigationTitle("Link Directives") // visually renamed
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showLinkSheet = false } } }
        }
    }

    private func filteredInterventions() -> [Intervention] {
        let excludeOwn = allInterventions.filter { $0.pageId != page.id }
        guard !linkSearch.isEmpty else { return excludeOwn }
        return excludeOwn.filter { $0.title.localizedCaseInsensitiveContains(linkSearch) }
    }

    private func trackableColor(_ iv: Intervention) -> Color {
        if let cname = iv.colorName {
            return Color.named(cname)
        }
        return .white
    }

    // MARK: Working On support
    private func toggleWorkingOn() {
        // Remember current state before clearing
        let wasOn = page.isWorkingOn

        // Clear the flag from all pages
        if let all = try? context.fetch(FetchDescriptor<NotePage>()) {
            for p in all where p.isWorkingOn { p.isWorkingOn = false }
        }

        // If it wasn’t previously on, set it; otherwise leave it cleared
        if wasOn == false {
            page.isWorkingOn = true
            SPIndicatorView(title: "Working On", message: "This page will appear on Home.", preset: .done).present(haptic: .success)
        } else {
            SPIndicatorView(title: "Working On Cleared", message: "Removed from Home.", preset: .error).present(haptic: .warning)
        }

        try? context.save()
    }

    // MARK: Pin support
    private func togglePin() {
        page.isPinned.toggle()
        SPIndicatorView(title: page.isPinned ? "Pinned" : "Unpinned", message: nil, preset: .done).present(haptic: .success)
        try? context.save()
    }

    // MARK: Tint helper
    private var tintColor: Color {
        if let name = page.colorName { return Color.named(name) }
        return .primary
    }
}

#Preview {
    let container = try! ModelContainer(for: NotePage.self)
    let ctx = ModelContext(container)
    let p = NotePage(title: "Sample page")
    ctx.insert(p)
    return NavigationStack { NotePageDetailView(page: p).modelContainer(container) }
}
