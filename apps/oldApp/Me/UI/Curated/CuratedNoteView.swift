import SwiftUI
import SwiftData

struct CuratedNoteView: View {
    let noteID: String
    @Environment(\.modelContext) private var context
    @State private var interventions: [Intervention] = []
    @State private var pages: [NotePage] = []
    @State private var note: DailyCuratedNote? = nil
    @State private var noteTitle: String = "Today"
    @State private var grouped: Bool = false

    private enum Layout: String, CaseIterable, Identifiable {
        case list = "Flat", grouped = "Grouped", concise = "Concise"
        var id:String{ rawValue }
    }
    @State private var layout: Layout = .list

    var body: some View {
        List {
            Picker("Layout", selection: $layout) {
                ForEach(Layout.allCases) { l in Text(l.rawValue).tag(l) }
            }
            .pickerStyle(.segmented)

            if layout == .list {
                ForEach(interventions, id: \Intervention.id) { iv in
                    NavigationLink {
                        InterventionEditorView(intervention: iv)
                    } label: {
                        HStack(alignment: .center, spacing: 0) {
                            if iv.isGoal {
                                Button(action: { toggleGoal(iv) }) {
                                    GoalCheckbox(isChecked: note?.completedGoalIDs.contains(iv.id) ?? false)
                                }
                                .buttonStyle(.plain)
                            }
                            InterventionRow(intervention: iv, style: iv.isGoal ? .detailed : .badge)
                        }
                        .padding(.vertical,6)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.rowBackground(named: iv.rowBackgroundName) ?? Color(.secondarySystemBackground))
                }
                if !pages.isEmpty {
                    Section("Notes") {
                        ForEach(pages, id: \.id) { pageRow(for: $0) }
                    }
                }
            } else if layout == .grouped {
                // grouped layout only groups directives; pages shown in own section
                ForEach(groupedInterventions.keys.sorted(), id: \.self) { topicTitle in
                    Section(topicTitle) {
                        ForEach(groupedInterventions[topicTitle]!, id: \.id) { iv in
                            NavigationLink { InterventionEditorView(intervention: iv) } label: { InterventionRow(intervention: iv, style: .badge) }
                        }
                    }
                }
                if !pages.isEmpty {
                    Section("Notes") {
                        ForEach(pages, id: \.id) { pageRow(for: $0) }
                    }
                }
            } else if layout == .concise {
                // Concise layout: titles only
                ForEach(interventions, id: \Intervention.id) { iv in
                    NavigationLink {
                        InterventionEditorView(intervention: iv)
                    } label: {
                        InterventionRow(intervention: iv, style: .titleOnly)
                            .padding(.vertical,6)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.rowBackground(named: iv.rowBackgroundName) ?? Color(.secondarySystemBackground))
                }

                if !pages.isEmpty {
                    Section("Notes") {
                        ForEach(pages, id: \.id) { pageRow(for: $0) }
                    }
                }
            }

        }
        // Navigation links handle row taps
        .navigationTitle(noteTitle)
        .onAppear(perform: loadData)
    }

    private func loadData() {
        guard interventions.isEmpty && pages.isEmpty else { return }
        if let fetched = try? context.fetch(FetchDescriptor<DailyCuratedNote>(predicate: #Predicate { $0.id == noteID })).first {
            self.note = fetched
            noteTitle = fetched.date.formatted(date: .abbreviated, time: .omitted)
            let allInts = (try? context.fetch(FetchDescriptor<Intervention>())) ?? []
            let setIDs = Set(fetched.interventionIDs)
            let byId = Dictionary(uniqueKeysWithValues: allInts.map { ($0.id, $0) })
            interventions = fetched.interventionIDs.compactMap { byId[$0] }

            // Pages
            let allPages = (try? context.fetch(FetchDescriptor<NotePage>())) ?? []
            let pageSet = Set(fetched.notePageIDs)
            let byPageId = Dictionary(uniqueKeysWithValues: allPages.map { ($0.id, $0) })
            pages = fetched.notePageIDs.compactMap { byPageId[$0] }
        }
    }

    // Toggle goal completion for today
    private func toggleGoal(_ iv: Intervention) {
        guard var n = note else { return }
        if let idx = n.completedGoalIDs.firstIndex(of: iv.id) {
            n.completedGoalIDs.remove(at: idx)
        } else {
            n.completedGoalIDs.append(iv.id)
        }
        note = n
        try? context.save()
    }

    private func priorityColor(_ value: Int) -> Color {
        let ratio = Double(max(0, min(100, value))) / 100.0 // 0..1
        // Purple (hue 0.78) to Green (hue 0.33)
        let hueStart = 0.78, hueEnd = 0.33
        let hue = hueStart + (hueEnd - hueStart) * ratio
        return Color(hue: hue, saturation: 0.8, brightness: 0.8)
    }

    // row(for:) removed; use InterventionRow instead

    private var groupedInterventions: [String:[Intervention]] {
        let byPage = Dictionary(grouping: interventions) { $0.pageId }
        // Fetch page titles once
        let pages = (try? context.fetch(FetchDescriptor<NotePage>())) ?? []
        let titleById = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0.title) })
        var dict: [String:[Intervention]] = [:]
        for (pid, items) in byPage {
            let title = titleById[pid] ?? "Other"
            dict[title] = items.sorted { $0.priority > $1.priority }
        }
        return dict
    }

    private func trackableColor(for iv: Intervention) -> Color {
        if let cname = iv.colorName { return Color.named(cname) }
        return .white
    }

    // Row for NotePage
    private func pageRow(for page: NotePage) -> some View {
        NavigationLink {
            NotePageDetailView(page: page)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(priorityColor(page.priority))
                    Text("\(page.priority)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.title).font(.headline)
                    if !page.bodyMarkdown.isEmpty {
                        Text(page.bodyMarkdown.prefix(120) + "…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
