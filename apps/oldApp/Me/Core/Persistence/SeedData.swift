import Foundation
import SwiftData

/// Seeds initial app data on first launch.
enum SeedData {
    /// Seed versioning
    /// -----------------------------------------------------------------
    /// This constant tells the app which seed blocks should run.
    ///   • Leave `currentVersion` unchanged → only existing seed blocks
    ///     run for _brand-new_ installs; existing users run none.
    ///   • Bump `currentVersion` and add a matching `seedVn(_:)` method
    ///     when you want **all devices** to get new baseline content
    ///     exactly once.
    ///
    ///   Launch logic:
    ///       stored = UserDefaults.seedVersion  // 0 if never seeded
    ///       if stored < currentVersion {
    ///           run seed blocks (stored+1…currentVersion)
    ///           store currentVersion
    ///       }
    ///
    ///   Effect matrix
    ///   ----------------------------------------------------------------
    ///   stored vs currentVersion    Seed blocks that run
    ///   ---------------------------------------------------------------
    ///   Old user, keep v1  (1 < 1)  → none
    ///   New install v1    (0 < 1)  → V1
    ///   Old user, bump v2 (1 < 2)  → V2 only
    ///   New install v2    (0 < 2)  → V1 then V2
    /// -----------------------------------------------------------------
    ///
    /// This gives you full control:
    ///   • Don’t bump → existing users receive nothing new.
    ///   • Bump and add seedVn → every device gets the new items once.
    private static let currentVersion = 1
    private static let versionKey = "seedVersion"

    /// Call early in app lifecycle (e.g., inside ModelContainer init) to ensure baseline data.
    static func populateIfNeeded(container: ModelContainer) {
        let lastVersion = UserDefaults.standard.integer(forKey: versionKey)
        let context = ModelContext(container)

        // Always ensure baseline data exists even if versions already match (e.g., CloudKit reset)
        if baselineMissing(in: context) {
            seedV1(context)
        }

        // Run incremental seed blocks when app version advances
        guard lastVersion < currentVersion else { return }

        if lastVersion < 1 { seedV1(context) }

        UserDefaults.standard.set(Self.currentVersion, forKey: Self.versionKey)
    }

    // MARK: - Version 1
    /// Seed baseline objects required for any fresh install.
    private static func seedV1(_ context: ModelContext) {
        // If a sentinel Trackable already exists (likely synced from CloudKit), skip heavy work
        let sentinelExists: Bool = {
            var fetch = FetchDescriptor<Trackable>(
                predicate: #Predicate { $0.id == "trackable-anxiety" })
            fetch.fetchLimit = 1
            return ((try? context.fetch(fetch).isEmpty) == false)
        }()
        if sentinelExists { return }

        // MARK: Trackables
        let anxiety: Trackable = context.findOrCreate(id: "trackable-anxiety") {
            let t = Trackable(name: "Anxiety")
            t.id = "trackable-anxiety"
            t.colorName = "orange"
            t.order = 0
            return t
        }

        let brainFog: Trackable = context.findOrCreate(id: "trackable-brainfog") {
            let t = Trackable(name: "Brain Fog")
            t.id = "trackable-brainfog"
            t.colorName = "indigo"
            t.order = 1
            return t
        }

        // MARK: Folders & Pages
        let healthFolder: Folder = context.findOrCreate(id: "folder-health") {
            let f = Folder(name: "Health")
            f.id = "folder-health"
            return f
        }

        let anxietyPage: NotePage = context.findOrCreate(id: "page-anxiety") {
            NotePage(id: "page-anxiety", title: "Anxiety", folderId: healthFolder.id, isSystem: true)
        }
        let fogPage: NotePage = context.findOrCreate(id: "page-brainfog") {
            NotePage(id: "page-brainfog", title: "Brain Fog", folderId: healthFolder.id, isSystem: true)
        }

        // MARK: Interventions
        let physiologicalSigh: Intervention = context.findOrCreate(id: "iv-physio-sigh") {
            let iv = Intervention(pageId: anxietyPage.id, title: "Physiological Sigh")
            iv.id = "iv-physio-sigh"
            iv.trackableId = anxiety.id
            iv.detailsMarkdown = "Take two quick inhales followed by a long exhale."
            iv.isEveryDay = true
            iv.priority = 100
            return iv
        }

        let boxBreathing: Intervention = context.findOrCreate(id: "iv-box-breath") {
            let iv = Intervention(pageId: anxietyPage.id, title: "Box Breathing")
            iv.id = "iv-box-breath"
            iv.trackableId = anxiety.id
            iv.detailsMarkdown = "Inhale 4 • Hold 4 • Exhale 4 • Hold 4"
            iv.minSeverity = 4
            iv.maxSeverity = 10
            iv.priority = 80
            return iv
        }

        let walk: Intervention = context.findOrCreate(id: "iv-walk") {
            let iv = Intervention(pageId: fogPage.id, title: "Short Walk")
            iv.id = "iv-walk"
            iv.trackableId = brainFog.id
            iv.detailsMarkdown = "10-minute brisk walk outdoors"
            iv.maxSeverity = 3
            iv.priority = 90
            return iv
        }

        // Link interventions to pages
        func link(_ iv: Intervention, to page: NotePage) {
            if page.interventions == nil { page.interventions = [] }
            if page.interventions!.contains(where: { $0.id == iv.id }) == false {
                page.interventions!.append(iv)
            }
        }

        link(physiologicalSigh, to: anxietyPage)
        link(boxBreathing, to: anxietyPage)
        link(walk, to: fogPage)

        // MARK: Situations
        _ = context.findOrCreate(id: "situation-presentation") {
            let s = Situation(title: "Giving a presentation")
            s.id = "situation-presentation"
            s.iconSystemName = "person.2.wave.2"
            s.colorName = "orange"
            s.pageIds = [anxietyPage.id]
            return s
        }

        // MARK: Save
        do {
            try context.save()
            print("SeedData v1 inserted")
        } catch {
            assertionFailure("Failed to seed data v1: \(error)")
        }
    }

    /// Quick check for a known sentinel object; if missing we know the baseline is gone.
    private static func baselineMissing(in context: ModelContext) -> Bool {
        var fetch = FetchDescriptor<Trackable>()
        fetch.predicate = #Predicate { $0.id == "trackable-anxiety" }
        fetch.fetchLimit = 1
        return (try? context.fetch(fetch).isEmpty) ?? true
    }
}

// MARK: - SeedIdentifiable helper
/// Models that expose a stable `id` string so we can look them up generically.
protocol SeedIdentifiable { var id: String { get set } }

// Declare conformance for all seeded models
extension Trackable: SeedIdentifiable {}
extension Folder: SeedIdentifiable {}
extension NotePage: SeedIdentifiable {}
extension Intervention: SeedIdentifiable {}
extension Situation: SeedIdentifiable {}
extension Roadmap: SeedIdentifiable {}
extension RoadmapNode: SeedIdentifiable {}

// Add a generic helper that guarantees idempotent inserts.
extension ModelContext {
    /// Returns an existing object with the given `id`, or creates and inserts a new one.
    /// - Parameters:
    ///   - id: The stable primary‐key for the seeded object.
    ///   - create: Factory closure that configures the object when it does not yet exist.
    /// - Returns: The persistent model instance that now lives in the context.
    @discardableResult
    func findOrCreate<T>(id: String, create: () -> T) -> T where T: PersistentModel & SeedIdentifiable {
        var fetch = FetchDescriptor<T>()
        fetch.predicate = #Predicate { $0.id == id }
        fetch.fetchLimit = 1

        if let existing = try? self.fetch(fetch).first {
            return existing
        }

        let obj = create()
        insert(obj)
        return obj
    }
}
