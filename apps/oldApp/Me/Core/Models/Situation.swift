import Foundation
import SwiftData

@Model
public final class Situation {
    @Attribute public var id: String = UUID().uuidString
    public var title: String = ""
    public var iconSystemName: String = "circle.fill"
    public var colorName: String = "blue"
    /// Manual ordering within the list (lower numbers appear first).
    public var order: Int = 0
    public var pageIds: [String] = [] // linked NotePage ids
    public var interventionIds: [String] = [] // linked Intervention ids

    public init(title: String = "", order: Int = 0) {
        self.title = title
        self.order = order
    }
}
