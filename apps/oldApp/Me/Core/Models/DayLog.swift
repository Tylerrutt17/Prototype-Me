/// Daily diary entry with rating and attached tags
import Foundation
import SwiftData

import UIKit

@Model
final class DayLog: RichTextPersistable {
    // MARK: Identity
    var date: Date = Date()            // one log per calendar day

    // MARK: Content
    var bodyMarkdown: String = ""
    var rating: Int = 5                            // 1…10 inclusive
    var encodedText: Data? = nil      // rich text archive

    // MARK: Relationships
    @Relationship(deleteRule: .cascade) var tags: [DayLogTag]? = []

    // MARK: Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: Init
    init(date: Date = Date(), bodyMarkdown: String = "", rating: Int = 5) {
        let normalized = Calendar.current.startOfDay(for: date)
        self.date = normalized
        self.bodyMarkdown = bodyMarkdown
        self.rating = rating
        // timestamps already default
    }

    // Call before saving after edits
    func touch() {
        updatedAt = .now
    }
}
