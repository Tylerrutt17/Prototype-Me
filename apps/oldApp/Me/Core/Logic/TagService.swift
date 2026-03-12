import Foundation
import SwiftData

struct TagService {
    // Fetch or create tag with given name
    static func tag(named name: String, defaultWeight: Int = 1, in context: ModelContext) -> Tag {
        let predicate = #Predicate<Tag> { $0.name == name }
        let descriptor = FetchDescriptor<Tag>(predicate: predicate)
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let tag = Tag(name: name, defaultWeight: defaultWeight)
        context.insert(tag)
        return tag
    }

    // Top tags by frequency in recent logs
    static func topTags(limit: Int = 10, in context: ModelContext) -> [Tag] {
        // naive implementation: fetch all dayLogTags and count
        let fetch = FetchDescriptor<DayLogTag>()
        guard let joins = try? context.fetch(fetch) else { return [] }
        // unwrap optional tags and count frequency
        let tags = joins.compactMap { $0.tag }
        let freq = Dictionary(grouping: tags, by: { $0 }).mapValues { $0.count }
        return freq.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    // Impact: average rating delta when tag present vs absent
    static func impact(of tag: Tag, in context: ModelContext) -> Double? {
        let allLogs = DayLogService.logs(in: context)
        guard !allLogs.isEmpty else { return nil }
        let withTag = allLogs.filter { log in
            (log.tags?.contains { $0.tag == tag } ?? false)
        }
        let withoutTag = allLogs.filter { !withTag.contains($0) }

        guard !withTag.isEmpty, !withoutTag.isEmpty else { return nil }

        let sumWith = withTag.reduce(0.0) { $0 + Double($1.rating) }
        let sumWithout = withoutTag.reduce(0.0) { $0 + Double($1.rating) }

        let avgWith = sumWith / Double(withTag.count)
        let avgWithout = sumWithout / Double(withoutTag.count)

        return avgWith - avgWithout
    }
}
