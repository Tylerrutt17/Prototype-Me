import Foundation

// MARK: - Section / Item identifiers

enum HistorySection: Sendable {
    case month(String) // yyyy-MM
}
extension HistorySection: @preconcurrency Hashable {}

enum HistoryItem: Sendable {
    case monthSummary(HistoryMonthSummary)
    case aiReview(PeriodicReview)
}
extension HistoryItem: @preconcurrency Hashable {}

// MARK: - Shared formatters

enum HistoryDateFormat {
    /// "2026-03" → "March 2026"
    static func monthTitle(_ yyyyMM: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: yyyyMM) else { return yyyyMM }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }

    /// "2026-03-24" + "2026-03-30" → "Mar 24 – Mar 30"
    static func weekRange(start: String, end: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let s = parser.date(from: start), let e = parser.date(from: end) else {
            return "Week of \(start)"
        }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return "\(display.string(from: s)) – \(display.string(from: e))"
    }

    /// "2026-03-24" → "Mar 24"
    static func shortDate(_ yyyyMMdd: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: yyyyMMdd) else { return yyyyMMdd }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}
