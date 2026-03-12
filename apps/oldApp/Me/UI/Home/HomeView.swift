import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trackable.order) private var trackables: [Trackable]
    @State private var levels: [String: Int] = [:]
    @State private var navPath = NavigationPath()
    @State private var workingOnPage: NotePage? = nil
    @State private var activeNoteID: String? = nil
    // Diary states
    @State private var diaryText: String = ""
    @State private var diaryRating: Int = 8
    @State private var showTagSheet = false
    @State private var loadedTodayLog = false
    // Persist slider levels for each day via DailyCuratedNote
    @Environment(\.calendar) private var calendar

    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        return nf
    }()

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                workingOnSection()
                headerSection
                diarySection
                slidersSection
                generateSection
                Section("Situations") {
                    SituationsGrid { situation in
                        navPath.append(situation.id)
                    }
                }
            }
            .navigationTitle("Daily Check-In")
            .onAppear {
                initializeLevelsIfNeeded()
                loadWorkingOnPage()
            }
            .onChange(of: modelContext) { _ in loadWorkingOnPage() }
            .onChange(of: levels) { _ in
                saveLevels()
            }
            .onDisappear(perform: saveLevels)
            .navigationDestination(for: String.self) { id in
                if let sit = (try? modelContext.fetch(FetchDescriptor<Situation>(predicate: #Predicate { $0.id == id })).first) {
                    SituationDetailView(situation: sit)
                } else if let page = (try? modelContext.fetch(FetchDescriptor<NotePage>(predicate: #Predicate { $0.id == id })).first) {
                    NotePageDetailView(page: page)
                        .onAppear { activeNoteID = page.id }
                        .onDisappear { if activeNoteID == page.id { activeNoteID = nil } }
                } else {
                    CuratedNoteView(noteID: id)
                }
            }
        }
    }

    // Extracted to keep body simpler for compiler
    @ViewBuilder
    private func workingOnSection() -> some View {
        if let wip = workingOnPage { 
            Section {
                Button {
                    if activeNoteID == wip.id {
                        // Already viewing: unlink
                        wip.isWorkingOn = false
                        workingOnPage = nil
                        activeNoteID = nil
                        navPath.removeLast()
                    } else {
                        navPath.append(wip.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: "hammer")
                        Text(wip.title.isEmpty ? "Untitled" : wip.title)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }

    private var headerSection: some View {
        Section {
            HStack {
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Spacer()
                NavigationLink(destination: DayLogCalendarView()) {
                    Image(systemName: "calendar")
                }
            }
        }
    }

    // MARK: - Diary Section
    private var diarySection: some View {
        Section("Today\u{2019}s Diary") {
            TextEditor(text: $diaryText)
                .frame(minHeight: 120)
                .textEditorStyle(.automatic)
                .onAppear { loadTodayLogIfNeeded() }
            HStack {
                Stepper(value: $diaryRating, in: 1...10) {
                    Text("Rating: \(diaryRating)")
                }
                Spacer()
                Button("Save") { saveDiary() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showTagSheet) {
            TagSelectionSheet(dayLog: todayLogBinding())
        }
    }

    private func loadTodayLogIfNeeded() {
        guard !loadedTodayLog else { return }
        loadedTodayLog = true
        if let log = DayLogService.log(for: .now, in: modelContext) {
            diaryText = log.bodyMarkdown
            diaryRating = log.rating
        }
    }

    private func saveDiary() {
        let log = DayLogService.upsert(body: diaryText, rating: diaryRating, in: modelContext)
        try? modelContext.save()
        // After save, open tag sheet
        showTagSheet = true
    }

    private func todayLogBinding() -> DayLog {
        if let existing = DayLogService.log(for: .now, in: modelContext) {
            return existing
        }
        return DayLogService.upsert(body: diaryText, rating: diaryRating, in: modelContext)
    }

    private var slidersSection: some View {
        Section(header: Text("How are you feeling?")) {
            ForEach(trackables, id: \.id) { trackable in
                sliderRow(for: trackable)
            }
        }
    }

    private func sliderRow(for trackable: Trackable) -> some View {
        let binding = Binding<Double>(
            get: { Double(levels[trackable.id] ?? trackable.defaultValue) },
            set: { levels[trackable.id] = Int($0) }
        )

        return HStack {
            Text(trackable.name)
                .frame(width: 100, alignment: .leading)
            Slider(value: binding,
                   in: Double(trackable.min)...Double(trackable.max), step: 1)
                .tint(Color.named(trackable.colorName))
            Text(numberFormatter.string(from: NSNumber(value: Int(binding.wrappedValue))) ?? "0")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: Generate curated note
    private var generateSection: some View {
        Button(action: generateCuratedNote) {
            Text("See Daily Note")
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .controlSize(.large)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        // Remove all default insets so the button occupies full row area
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        // Add a content shape so the empty area is also tappable
        .contentShape(Rectangle())
    }

    private func generateCuratedNote() {
        let context = modelContext

        // Fetch supporting data
        let trackables = (try? context.fetch(FetchDescriptor<Trackable>())) ?? []
        let pages = (try? context.fetch(FetchDescriptor<NotePage>())) ?? []
        let interventions = (try? context.fetch(FetchDescriptor<Intervention>())) ?? []

        let (intIDs, pageIDs) = CurationEngine.curated(for: trackables,
                                                       values: levels,
                                                       pages: pages,
                                                       interventions: interventions)

        let todayId = DateUtils.todayId()
        let todayDate = DateUtils.startOfToday()

        if let existing = try? context.fetch(FetchDescriptor<DailyCuratedNote>(predicate: #Predicate { $0.id == todayId })).first {
            existing.metricLevels = levels
            existing.interventionIDs = intIDs
            existing.notePageIDs = pageIDs
        } else {
            let record = DailyCuratedNote(id: todayId, date: todayDate, metricLevels: levels, interventionIDs: intIDs, notePageIDs: pageIDs)
            context.insert(record)
        }

        try? context.save()
        navPath.append(todayId)
    }

    private func initializeLevelsIfNeeded() {
        guard levels.isEmpty else { return }

        let todayID = DateUtils.todayID()
        if let rec = try? modelContext.fetch(FetchDescriptor<DailyCuratedNote>(predicate: #Predicate { $0.id == todayID })).first {
            // Load previously saved levels for today
            levels = rec.metricLevels
        }

        // Ensure every current trackable has a value (in case of new metrics)
        for t in trackables {
            if levels[t.id] == nil {
                levels[t.id] = t.defaultValue
            }
        }
    }

    /// Save current levels into today's DailyCuratedNote record, creating if needed.
    private func saveLevels() {
        let todayID = DateUtils.todayID()
        if let rec = try? modelContext.fetch(FetchDescriptor<DailyCuratedNote>(predicate: #Predicate { $0.id == todayID })).first {
            rec.metricLevels = levels
        } else {
            let record = DailyCuratedNote(id: todayID, date: DateUtils.startOfToday(), metricLevels: levels)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    // MARK: Working-on helpers
    private func loadWorkingOnPage() {
        workingOnPage = try? modelContext.fetch(FetchDescriptor<NotePage>(predicate: #Predicate { $0.isWorkingOn == true })).first
    }
}

#Preview {
    let container = try! ModelContainer(for: Trackable.self)
    // spoof one preview trackable
    let context = ModelContext(container)
    let tmp = Trackable(name: "Energy")
    context.insert(tmp)
    return HomeView().modelContainer(container)
}
