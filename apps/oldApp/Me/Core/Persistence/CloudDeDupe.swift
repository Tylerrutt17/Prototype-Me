import Foundation
import SwiftData
import CoreData

/// Listens for the first CloudKit import event and removes any duplicate seeded objects
/// that could appear if the user launched offline then later synced.
enum CloudDeDupe {
    static func start(container: ModelContainer) {
        // Fire-and-forget task that waits for the very first remote merge.
        Task { @MainActor in
            // NSPersistentCloudKitContainer posts this notification when records merge.
            // SwiftData re-emits it under the same name.
            for await _ in NotificationCenter.default
                .notifications(named: NSPersistentCloudKitContainer.eventChangedNotification)
                .prefix(1) {
                let ctx = ModelContext(container)

                // Dedupe each seeded entity type
                try? dedupe(Trackable.self, in: ctx)
                try? dedupe(Folder.self, in: ctx)
                try? dedupe(NotePage.self, in: ctx)
                try? dedupe(Intervention.self, in: ctx)
                try? dedupe(Situation.self, in: ctx)

                try? ctx.save()
                print("CloudDeDupe: Removed duplicate seeded objects after CloudKit import")
            }
        }
    }

    private static func dedupe<T>(_ type: T.Type, in ctx: ModelContext) throws where T: PersistentModel & SeedIdentifiable {
        let all = try ctx.fetch(FetchDescriptor<T>())
        let grouped = Dictionary(grouping: all, by: { $0.id })

        for (_, dupes) in grouped where dupes.count > 1 {
            // Keep first, delete rest
            for dupe in dupes.dropFirst() { ctx.delete(dupe) }
        }
    }
}
