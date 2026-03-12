import Foundation
import SwiftData
import CoreGraphics

@Model
public final class RoadmapNode: RichTextPersistable {
    @Attribute public var id: String = UUID().uuidString
    public var title: String = ""
    public var body: String = ""
    /// Rich text storage
    @Attribute public var encodedText: Data? = nil

    /// Stored color name used for UI rendering
    @Attribute public var colorName: String = "yellow"

    /// Linked resources
    @Attribute public var pageIds: [String] = [] // linked NotePage ids
    @Attribute public var interventionIds: [String] = [] // linked Intervention ids

    /// Markdown representation (alias to `body` for backward compatibility)
    public var bodyMarkdown: String {
        get { body }
        set { body = newValue }
    }
    public var x: Double = 0
    public var y: Double = 0

    /// Optional identifier of the parent node this node is connected from.
    public var parentId: String? = nil

    @Relationship(inverse: \Roadmap.nodes)
    public var roadmap: Roadmap?

    public init(title: String = "", position: CGPoint = .zero, parentId: String? = nil) {
        self.title = title
        self.x = position.x
        self.y = position.y
        self.parentId = parentId
        // default color already set by property initializer
    }

    public var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }
}
