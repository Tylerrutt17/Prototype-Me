import Foundation
import SwiftData

@Model
public final class Roadmap {
    @Attribute public var id: String = UUID().uuidString
    public var name: String = ""
    public var createdAt: Date = Date()

    // Relationship: one-to-many RoadmapNode
    @Relationship public var nodes: [RoadmapNode]? = nil

    // View state persistence
    @Attribute public var zoomScale: Double = 1.0
    @Attribute public var offsetX: Double = 0
    @Attribute public var offsetY: Double = 0

    public init(name: String = "") {
        self.name = name
    }
}
