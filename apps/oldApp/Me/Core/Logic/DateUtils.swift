import Foundation

enum DateUtils {
    static func startOfDay(for date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func todayId(calendar: Calendar = .current) -> String {
        let comp = calendar.dateComponents([.year, .month, .day], from: .now)
        return String(format: "%04d-%02d-%02d", comp.year ?? 0, comp.month ?? 0, comp.day ?? 0)
    }

    // Alias with capital D for convenience
    static func todayID(calendar: Calendar = .current) -> String { todayId(calendar: calendar) }

    /// Convenience for start of today using current calendar
    static func startOfToday(calendar: Calendar = .current) -> Date {
        startOfDay(for: .now, calendar: calendar)
    }
}
