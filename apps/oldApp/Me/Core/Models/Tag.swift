import Foundation
import SwiftData

@Model
final class Tag {
    var name: String = ""
    var defaultWeight: Int = 1

    @Relationship(inverse: \DayLogTag.tag)
    var joins: [DayLogTag]? = []

    init(name: String = "", defaultWeight: Int = 1) {
        self.name = name
        self.defaultWeight = max(-5, min(5, defaultWeight))
    }
}

// extension removed
