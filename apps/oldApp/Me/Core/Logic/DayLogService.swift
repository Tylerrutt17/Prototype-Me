import Foundation
import SwiftData

/// CRUD helpers for `DayLog` plus simple queries.
/// Keep all heavy analytics out of the main UI thread.
struct DayLogService {
    // MARK: Lookup
    static func log(for date: Date, in context: ModelContext) -> DayLog? {
        let start = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<DayLog> { $0.date == start }
        let descriptor = FetchDescriptor<DayLog>(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    // MARK: Upsert
    @discardableResult
    static func upsert(date: Date = .now,
                       body: String,
                       rating: Int,
                       in context: ModelContext) -> DayLog {
        if let existing = log(for: date, in: context) {
            existing.bodyMarkdown = body
            existing.rating = rating
            existing.touch()
            return existing
        } else {
            let new = DayLog(date: date, bodyMarkdown: body, rating: rating)
            context.insert(new)
            return new
        }
    }

    // MARK: Queries
    static func logs(limit: Int? = nil, in context: ModelContext) -> [DayLog] {
        var descriptor = FetchDescriptor<DayLog>(sortBy: [SortDescriptor(\DayLog.date, order: .reverse)])
        if let l = limit { descriptor.fetchLimit = l }
        return (try? context.fetch(descriptor)) ?? []
    }

    static func logs(from start: Date, to end: Date, in context: ModelContext) -> [DayLog] {
        let s = Calendar.current.startOfDay(for: start)
        let e = Calendar.current.startOfDay(for: end)
        let predicate = #Predicate<DayLog> { $0.date >= s && $0.date <= e }
        let descriptor = FetchDescriptor<DayLog>(predicate: predicate, sortBy: [SortDescriptor(\DayLog.date)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
