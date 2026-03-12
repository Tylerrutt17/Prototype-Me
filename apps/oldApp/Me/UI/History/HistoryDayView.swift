import SwiftUI
import SwiftData

/// Read-only view of a past DailyCuratedNote with option to recreate as Today.
struct HistoryDayView: View {
    let record: DailyCuratedNote
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    // Slider metric levels saved for the day as (trackable, value)
    @State private var metricPairs: [(Trackable, Int)] = []
    @State private var interventions: [Intervention] = []
    @State private var pages: [NotePage] = []

    var body: some View {
        List {
            if !metricPairs.isEmpty {
                Section("Metric Levels") {
                    ForEach(metricPairs.indices, id: \.self) { idx in
                        let (t, v) = metricPairs[idx]
                        HStack {
                            Text(t.name)
                            Spacer()
                            Text("\(v)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            ForEach(interventions, id: \Intervention.id) { iv in
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
            if !pages.isEmpty {
                Section("Notes") {
                    ForEach(pages, id: \.id) { p in
                        NavigationLink {
                            NotePageDetailView(page: p)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.title).font(.headline).lineLimit(2)
                                if !p.bodyMarkdown.isEmpty {
                                    Text(p.bodyMarkdown.prefix(120) + "…")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(record.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Recreate as Today", action: recreate)
            }
        }
        .onAppear(perform: load)
        // Navigation handled in list rows
    }

    private func load() {
        if interventions.isEmpty || pages.isEmpty {
            // Load saved metric levels
            if metricPairs.isEmpty {
                let allTracks = (try? context.fetch(FetchDescriptor<Trackable>())) ?? []
                metricPairs = allTracks.compactMap { t in
                    if let val = record.metricLevels[t.id] { return (t, val) } else { return nil }
                }
                .sorted { $0.0.order < $1.0.order }
            }

            let ints = (try? context.fetch(FetchDescriptor<Intervention>())) ?? []
            let setIDs = Set(record.interventionIDs)
            interventions = ints.filter { setIDs.contains($0.id) }
                .sorted { $0.title < $1.title }

            let allPages = (try? context.fetch(FetchDescriptor<NotePage>())) ?? []
            let pageSet = Set(record.notePageIDs)
            pages = allPages.filter { pageSet.contains($0.id) }
                .sorted { $0.title < $1.title }
        }
    }

    private func recreate() {
        let todayID = DateUtils.todayID()
        if let existing = try? context.fetch(FetchDescriptor<DailyCuratedNote>(predicate: #Predicate { $0.id == todayID })).first {
            context.delete(existing)
        }
        let new = DailyCuratedNote(id: todayID, date: DateUtils.startOfToday(), metricLevels: record.metricLevels, interventionIDs: record.interventionIDs, notePageIDs: record.notePageIDs)
        context.insert(new)
        dismiss()
    }
}

#Preview {
    Text("HistoryDayView Preview")
}
