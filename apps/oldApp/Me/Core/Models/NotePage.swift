import Foundation
import SwiftData

@Model
public final class NotePage {
    @Attribute public var id: String = UUID().uuidString
    public var title: String = ""
    public var bodyMarkdown: String = ""
    /// Archived NSAttributedString containing full rich-text representation of the body.
    /// Stored externally so large notes don’t bloat the main table row.
    @Attribute(.externalStorage) public var encodedText: Data? = nil
    @Relationship(inverse: \Intervention.page)
    public var interventions: [Intervention]? // nil until first insert
    public var folderId: String? // nil at root
    public var isSystem: Bool = false // non-deletable core pages like Anxiety

    // MARK: Optional Daily Curation metadata (parity with Intervention)
    /// Minimum severity level (inclusive) at which this Note should appear when selected via Daily Check-In.
    public var minSeverity: Int = 0
    /// Maximum severity level (inclusive) at which this Note should appear when selected via Daily Check-In.
    public var maxSeverity: Int = 10
    /// Higher priority items float to the top of a curated note.
    public var priority: Int = 0
    /// When set, this note will appear every day regardless of severity levels.
    public var isEveryDay: Bool = false
    /// Manual ordering within its parent folder (lower numbers appear first).
    public var order: Int = 0
    /// Optional associated `Trackable` whose slider value drives severity comparisons. `nil` means global.
    public var trackableId: String? = nil
    /// IDs of interventions linked from other notes.
    public var linkedInterventionIds: [String] = []
    /// Marks this note as the single current “Working On” item to surface on Home screen.
    public var isWorkingOn: Bool = false
    /// Optional custom color name for the note title.
    public var colorName: String? = nil
    /// Marks this note as pinned to appear in the sidebar menu.
    public var isPinned: Bool = false
    /// Manual ordering among pinned notes.
    public var pinnedOrder: Int = 0

    public init(id: String = UUID().uuidString,
                title: String,
                bodyMarkdown: String = "",
                encodedText: Data? = nil,
                folderId: String? = nil,
                isSystem: Bool = false,
                minSeverity: Int = 0,
                maxSeverity: Int = 10,
                priority: Int = 0,
                isEveryDay: Bool = false,
                order: Int = 0,
                trackableId: String? = nil,
                isPinned: Bool = false,
                pinnedOrder: Int = 0,
                colorName: String? = nil) {
        self.id = id
        self.title = title
        self.bodyMarkdown = bodyMarkdown
        self.encodedText = encodedText
        self.folderId = folderId
        self.isSystem = isSystem

        self.minSeverity = minSeverity
        self.maxSeverity = maxSeverity
        self.priority = priority
        self.isEveryDay = isEveryDay
        self.order = order
        self.trackableId = trackableId
        self.linkedInterventionIds = []
        self.isWorkingOn = false
        self.isPinned = isPinned
        self.pinnedOrder = pinnedOrder
        self.colorName = colorName
    }
}

// MARK: - Rich text
extension NotePage: RichTextPersistable {}
