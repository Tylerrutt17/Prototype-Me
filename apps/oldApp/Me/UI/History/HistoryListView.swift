import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \DailyCuratedNote.date, order: .reverse) private var records: [DailyCuratedNote]

    var body: some View {
        List(records, id: \.id) { rec in
            NavigationLink(rec.date.formatted(date: .abbreviated, time: .omitted)) {
                HistoryDayView(record: rec)
            }
        }
        .navigationTitle("History")
    }
}
