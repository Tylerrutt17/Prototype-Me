import Foundation
import SwiftData

@Model
public final class Trackable {
    @Attribute public var id: String = UUID().uuidString
    public var name: String = ""
    public var min: Int = 0
    public var max: Int = 10
    public var defaultValue: Int = 3
    public var order: Int = 0
    public var colorName: String = "gray"

    public init(name: String = "") {
        self.name = name
    }
}
