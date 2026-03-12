import SwiftUI
import SwiftData
import RichEditorSwiftUI

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var navPath = NavigationPath()

    // Diary states
    @State private var diaryText: String = ""
    @State private var diaryRating: Int? = nil // Nil until user chooses
    @State private var showTagSheet = false
    @State private var loadedTodayLog = false
    @State private var diaryEditorState: RichEditorState

    init() {
        _diaryEditorState = State(initialValue: DayLog().makeEditorState())
    }

    @Environment(\.calendar) private var calendar

    private let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        return nf
    }()

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(spacing: 16) {
                    headerBar
                    ratingCard
                    diaryCard
                    actionsRow
                }
                .padding()
            }
            .navigationDestination(for: String.self, destination: pushDestination)
            .navigationTitle("Daily Dashboard")
            .onAppear { loadTodayLogIfNeeded() }
            .onChange(of: diaryRating) { newVal in
                guard let rating = newVal else { return }
                let log = todayLogBinding()
                log.rating = rating
                try? modelContext.save()
            }
            .onDisappear {
                // Only update if a log already exists; don't create a new one implicitly
                if let existing = DayLogService.log(for: .now, in: modelContext) {
                    if let rating = diaryRating {
                        existing.rating = rating
                    }
                    try? modelContext.save()
                }
            }
            #if os(iOS)
            .safeAreaInset(edge: .bottom, alignment: .center) {
                RichTextKeyboardToolbar(
                    context: diaryEditorState,
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

    // MARK: ‑ Sub-Components
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now, style: .date)
                    .font(.headline)
                // Placeholder for streak badge
                // Text("🔥 3-day streak")
            }
            Spacer()
            NavigationLink(destination: DayLogCalendarView()) {
                Image(systemName: "calendar")
            }
        }
        .padding()
        .cardBackground(Color(.secondarySystemBackground))
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How’s today?")
                .font(.headline)
            Picker("Rating", selection: $diaryRating) {
                ForEach(1..<11, id: \ .self) { n in
                    Text(String(n)).tag(Optional(n))
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .cardBackground(accentColor(for: diaryRating))
    }

    private var diaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quick Diary")
                    .font(.headline)
                Spacer()
                Button(action: saveDiary) {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.accentColor, .white)
                }
            }
            RichNoteField(model: todayLogBinding(), state: diaryEditorState)
                .onAppear { loadTodayLogIfNeeded() }
        }
        .padding()
        .cardBackground(Color(.secondarySystemBackground))
        .sheet(isPresented: $showTagSheet) {
            TagSelectionSheet(dayLog: todayLogBinding())
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 12) {
            actionButton("Daily Note", systemImage: "doc.text", color: .pink) {
                openDailyNote()
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
    }

    // MARK: ‑ Helpers & Navigation
    private func pushDestination(id: String) -> some View {
        if id == "INSIGHTS" {
            return AnyView(Text("Insights TBD"))
        }
        if let sit = (try? modelContext.fetch(FetchDescriptor<Situation>(predicate: #Predicate { $0.id == id })).first) {
            return AnyView(SituationDetailView(situation: sit))
        } else if let page = (try? modelContext.fetch(FetchDescriptor<NotePage>(predicate: #Predicate { $0.id == id })).first) {
            return AnyView(NotePageDetailView(page: page))
        } else {
            return AnyView(CuratedNoteView(noteID: id))
        }
    }

    private func loadTodayLogIfNeeded() {
        guard !loadedTodayLog else { return }
        loadedTodayLog = true
        if let log = DayLogService.log(for: .now, in: modelContext) {
            diaryText = log.bodyMarkdown
            diaryRating = log.rating
            diaryEditorState = log.makeEditorState()
        } else {
            diaryEditorState = DayLog().makeEditorState()
        }
    }

    private func saveDiary() {
        let log = todayLogBinding()
        if let rating = diaryRating { log.rating = rating }
        log.touch()
        try? modelContext.save()
        showTagSheet = true
    }

    private func todayLogBinding() -> DayLog {
        if let existing = DayLogService.log(for: .now, in: modelContext) {
            // Ensure editor reflects latest stored content
            diaryEditorState = existing.makeEditorState()
            return existing
        }
        let created = DayLogService.upsert(body: diaryText, rating: diaryRating ?? 8, in: modelContext)
        diaryEditorState = created.makeEditorState()
        return created
    }

    private func openDailyNote() {
        let todayId = DateUtils.todayId()
        if let rec = try? modelContext.fetch(FetchDescriptor<DailyCuratedNote>(predicate: #Predicate { $0.id == todayId })).first {
            if rec.interventionIDs.isEmpty && rec.notePageIDs.isEmpty {
                populate(rec: rec)
            }
        } else {
            let rec = DailyCuratedNote(id: todayId, date: DateUtils.startOfToday())
            populate(rec: rec)
            modelContext.insert(rec)
        }
        try? modelContext.save()
        navPath.append(todayId)
    }

    private func populate(rec: DailyCuratedNote) {
        let trackables = (try? modelContext.fetch(FetchDescriptor<Trackable>())) ?? []
        let pages = (try? modelContext.fetch(FetchDescriptor<NotePage>())) ?? []
        let interventions = (try? modelContext.fetch(FetchDescriptor<Intervention>())) ?? []
        let (intIDs, pageIDs) = CurationEngine.curated(for: trackables, values: [:], pages: pages, interventions: interventions)
        rec.interventionIDs = intIDs
        rec.notePageIDs = pageIDs
    }

    // Utility: color mapping for rating
    private func accentColor(for rating: Int?) -> Color {
        guard let rating = rating else { return Color(.secondarySystemBackground) }
        switch rating {
        case 1...4: return .red.opacity(0.2)
        case 5...7: return .yellow.opacity(0.2)
        default: return .green.opacity(0.2)
        }
    }
}

// MARK: ‑ View Modifiers
private extension View {
    func cardBackground(_ color: Color = Color(.systemBackground)) -> some View {
        self
            .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    let container = try! ModelContainer(for: Trackable.self)
    let ctx = ModelContext(container)
    ctx.insert(Trackable(name: "Energy"))
    return HomeDashboardView().modelContainer(container)
}
