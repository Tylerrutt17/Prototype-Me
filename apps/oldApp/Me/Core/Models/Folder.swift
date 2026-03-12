import Foundation
import SwiftData

@Model
public final class Folder {
    @Attribute public var id: String = UUID().uuidString
    public var name: String = ""
    public var parentId: String? = nil // nil = root folder
    public var order: Int = 0    // manual sort within parent

    public init(name: String = "", parentId: String? = nil, order: Int = 0) {
        self.name = name
        self.parentId = parentId
        self.order = order
    }
}
