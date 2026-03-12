import SwiftUI
import SwiftData

import RichTextKit

struct DayLogCalendarView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedDate = Date()
    
    private var calendar: Calendar { .current }
    private var logsByDate: [Date: DayLog] {
        let logs = DayLogService.logs(in: context)
        return Dictionary(uniqueKeysWithValues: logs.map { ($0.date, $0) })
    }

    // MARK: - Calendar Navigation & Helpers

    @State private var currentMonth: Date = {
        // Start at the first day of the current month
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy" // e.g. November 2025
        return df
    }()

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) else { return }
        currentMonth = newMonth
        // Update selected date to remain within displayed month (default to first day)
        if let firstDay = daysInMonth().first {
            selectedDate = firstDay
        }
    }

    private func daysInMonth() -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    // Map a 1-10 rating to a red→green gradient color
    private func color(for rating: Int) -> Color {
        let clamped = max(1, min(rating, 10))
        let t = Double(clamped - 1) / 9.0 // 0 → red, 1 → green
        // Bright vivid gradient using HSB (hue 0 = red, 0.333 = green)
        return Color(hue: 0.333 * t, saturation: 0.85, brightness: 0.95)
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let startOfDay = calendar.startOfDay(for: date)
        let log = logsByDate[startOfDay]

        let backgroundColor: Color = {
            if let rating = log?.rating {
                return color(for: rating).opacity(0.85)
            } else {
                return Color.clear
            }
        }()

        VStack {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Month header with navigation
                HStack {
                    Button(action: { changeMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthFormatter.string(from: currentMonth))
                        .font(.headline)
                    Spacer()
                    Button(action: { changeMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)

                // Weekday symbols
                let symbols = calendar.shortWeekdaySymbols
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                    ForEach(symbols, id: \ .self) { s in
                        Text(s).font(.subheadline).bold()
                    }
                }

                // Days grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(daysInMonth(), id: \ .self) { day in
                        dayCell(for: day)
                    }
                }
                .padding(.horizontal)
                divider
                detailSection
                Spacer()
            }
            .navigationTitle("Diary Calendar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var divider: some View { Divider().padding(.horizontal) }
    
    private var detailSection: some View {
        Group {
            let start = calendar.startOfDay(for: selectedDate)
            if let log = logsByDate[start] {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating: \(log.rating)")
                        .font(.headline)
                    Text(log.loadEditorText())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            } else {
                Text("No entry for this day")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }
}

#Preview {
    let mc = try! ModelContainer(for: DayLog.self)
    // insert sample
    let ctx = ModelContext(mc)
    let sample = DayLog(date: .now, bodyMarkdown: "Sample", rating: 8)
    ctx.insert(sample)
    return DayLogCalendarView().modelContainer(mc)
}
