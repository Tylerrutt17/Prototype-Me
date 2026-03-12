// Bootstrap.swift – coordinates first-launch data setup without creating duplicates.
import Foundation
import SwiftData
import CoreData

/// Handles first-launch initialization:
/// 1. Waits for either the first CloudKit merge *or* a timeout.
/// 2. Removes any duplicate seeded objects.
/// 3. Runs `SeedData.populateIfNeeded`.
///
/// Call `Bootstrap.start(container:)` once during app startup.
enum Bootstrap {
    /// Starts the background task. Safe to call multiple times; only the first invocation does work.
    static func start(container: ModelContainer, timeout: TimeInterval = 8) {
        // Prevent duplicate tasks if the caller accidentally invokes us twice.
        guard sharedTask == nil else { return }
        sharedTask = Task { @MainActor in
            // 1. Wait for remote merge OR timeout – whichever happens first.
            async let merge: Void = await waitForRemoteMerge()
            async let timer: Void = {
                try? await Task.sleep(for: .seconds(timeout))
            }()
            // The first of these two "awaits" to finish unblocks execution.
            _ = await (try? merge, timer)

            // 2. Deduplicate any seeded objects that leaked in before we run seeding.
            dedupeSeededObjects(in: container)

            // 3. Seed if needed.
            SeedData.populateIfNeeded(container: container)

            // 4. Keep listening for *future* merges and dedupe again if CloudKit brings down new copies later.
            CloudDeDupe.start(container: container)
        }
    }

    // MARK: - Internals
    private static var sharedTask: Task<Void, Never>? = nil

    /// Suspends until the first CloudKit merge notification arrives.
    private static func waitForRemoteMerge() async {
        for await _ in NotificationCenter.default
            .notifications(named: NSPersistentCloudKitContainer.eventChangedNotification)
            .prefix(1) {
            return
        }
    }

    /// Removes duplicate baseline objects that might exist if the app launched offline and then synced.
    private static func dedupeSeededObjects(in container: ModelContainer) {
        let ctx = ModelContext(container)
        // Helper closure to delete extras for a model type.
        func dedupe<T: PersistentModel & SeedIdentifiable>(_ type: T.Type) {
            if let all = try? ctx.fetch(FetchDescriptor<T>()) {
                let grouped = Dictionary(grouping: all, by: { $0.id })
                for (_, dupes) in grouped where dupes.count > 1 {
                    for dupe in dupes.dropFirst() { ctx.delete(dupe) }
                }
            }
        }
        dedupe(Trackable.self)
        dedupe(Folder.self)
        dedupe(NotePage.self)
        dedupe(Intervention.self)
        dedupe(Situation.self)
        try? ctx.save()
    }
}
