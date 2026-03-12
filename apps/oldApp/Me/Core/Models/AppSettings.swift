import Foundation
import SwiftData

@Model
final class AppSettings {
    /// Persisted raw string for intervention list mode ("compact" or "detailed")
    var interventionListModeRaw: String = "compact"
    init() {}
}

extension AppSettings {
    /// Returns the singleton settings object, creating and persisting it if necessary.
    @MainActor
    static func shared(in context: ModelContext) -> AppSettings {
        if let existing = (try? context.fetch(FetchDescriptor<AppSettings>()))?.first {
            // Remove extras if duplicates exist
            if let all = try? context.fetch(FetchDescriptor<AppSettings>()), all.count > 1 {
                for extra in all.dropFirst() { context.delete(extra) }
                try? context.save()
            }
            return existing
        }
        let s = AppSettings()
        context.insert(s)
        try? context.save()
        return s
    }
}
