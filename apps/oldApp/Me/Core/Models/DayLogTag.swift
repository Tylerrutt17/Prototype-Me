import Foundation
import SwiftData

@Model
final class DayLogTag {
    @Relationship(inverse: \DayLog.tags) var dayLog: DayLog?
    var tag: Tag?
    var customWeight: Int?

    init(dayLog: DayLog, tag: Tag?, customWeight: Int? = nil) {
        self.dayLog = dayLog
        self.tag = tag
        if let w = customWeight {
            self.customWeight = max(-5, min(5, w))
        } else { self.customWeight = nil }
    }
}

// removed extension to avoid ambiguity
