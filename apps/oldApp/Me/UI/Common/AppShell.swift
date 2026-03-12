import SwiftUI
import SwiftData

enum AppSection: String, CaseIterable, Identifiable {
    case balloons = "Balloons"
    case home = "Home"
    case notes = "Notes"
    case directives = "Directives" // Moved Directives directly below Notes
    case situations = "Situations"
    case roadmaps = "Roadmaps"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .balloons: return "balloon.fill"
        case .home: return "house"
        case .notes: return "note.text"
        case .situations: return "sparkles"
        case .roadmaps: return "map"
        case .history: return "calendar"
        case .settings: return "gear"
        case .directives: return "list.bullet.rectangle"
        }
    }
}

struct AppShell: View {
    // Start with no selection so the app opens showing the sidebar menu only
    @State private var selection: AppSection? = nil

    // Model context for fetching data
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @Environment(\.scenePhase) private var scenePhase
    // Currently flagged "working on" note page
    @State private var workingOnPage: NotePage? = nil
    // Array of pinned notes
    @State private var pinnedPages: [NotePage] = []
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // "Working on" quick-access section
                if let wip = workingOnPage {
                    Section {
                        NavigationLink {
                            NotePageDetailView(page: wip)
                        } label: {
                            Label(wip.title.isEmpty ? "Untitled" : wip.title, systemImage: "hammer")
                        }
                        .tint(.orange)
                    }
                }

                // Pinned notes
                if !pinnedPages.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedPages, id: \.id) { p in
                            NavigationLink {
                                NotePageDetailView(page: p)
                            } label: {
                                Label(p.title.isEmpty ? "Untitled" : p.title, systemImage: "pin")
                            }
                        }
                        .onMove(perform: movePinned)
                    }
                }

        // Balloons shortcut
        NavigationLink(value: AppSection.balloons) {
            Label("Balloons", systemImage: AppSection.balloons.systemImage)
        }

        // Standard app sections
        ForEach(navigableSections, id: \.self) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.systemImage)
                    }
                }
            }
            .navigationTitle("Menu")
            .toolbar { EditButton() }
            .onAppear(perform: loadSidebarData)
            .onChange(of: modelContext) { _ in loadSidebarData() }
            .environment(\.editMode, $editMode)
        } detail: {
            detailView()
        }
        .task {
            await CountdownService.refreshCountdowns(in: modelContext)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await CountdownService.refreshCountdowns(in: modelContext)
                    await NotificationScheduler.refreshAllDirectiveDailyNotifications(in: modelContext)
                }
            }
        }
    }

    @ViewBuilder
    private func detailView() -> some View {
        if let deepLinked = resolveDeepLinkedIntervention() {
            deepLinked
        } else {
            switch selection {
            case .none:
                Text("Select a section")
                    .foregroundStyle(.secondary)
            case .home:
                HomeDashboardView()
            case .notes:
                NotesSectionView()
            case .situations:
                SituationsListView()
            case .roadmaps:
                RoadmapsSectionView()
            case .history:
                HistoryListView()
            case .settings:
                SettingsView()
            case .directives:
                DirectivesListView()
            case .balloons:
                BalloonsView()
            }
        }
    }

    // MARK: - Helpers
    private func loadSidebarData() {
        workingOnPage = try? modelContext.fetch(FetchDescriptor<NotePage>(predicate: #Predicate { $0.isWorkingOn == true })).first
        pinnedPages = (try? modelContext.fetch(FetchDescriptor<NotePage>(predicate: #Predicate { $0.isPinned == true })).sorted { $0.pinnedOrder < $1.pinnedOrder }) ?? []
    }

    private func movePinned(from offsets: IndexSet, to destination: Int) {
        var arr = pinnedPages
        arr.move(fromOffsets: offsets, toOffset: destination)
        for (idx, p) in arr.enumerated() { p.pinnedOrder = idx }
        pinnedPages = arr
        try? modelContext.save()
    }

    // MARK: - Deep link handling
    private func resolveDeepLinkedIntervention() -> AnyView? {
        guard let targetId = deepLinkRouter.targetInterventionId else { return nil }
        if let iv = try? modelContext.fetch(FetchDescriptor<Intervention>(predicate: #Predicate { $0.id == targetId })).first {
            return AnyView(
                InterventionEditorView(intervention: iv)
                    .onAppear {
                        selection = .directives
                    }
                    .onDisappear { deepLinkRouter.consumeInterventionLink() }
            )
        } else {
            return AnyView(
                Text("Directive not found")
                    .foregroundStyle(.secondary)
                    .onAppear { deepLinkRouter.consumeInterventionLink() }
            )
        }
    }

    private var navigableSections: [AppSection] {
        AppSection.allCases.filter { $0 != .balloons }
    }
}

#Preview {
    AppShell()
}
