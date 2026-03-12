import Foundation

// MARK: - NotePage

nonisolated struct NotePage: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var body: String              // Markdown
    var kind: NoteKind
    var tier: Tier
    var folderId: UUID?
    var sortIndex: Int
    var version: Int
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NotePage, rhs: NotePage) -> Bool { lhs.id == rhs.id }
}

// MARK: - Directive

nonisolated struct Directive: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var body: String?             // Optional longer description
    var status: DirectiveStatus
    var balloonEnabled: Bool
    var balloonDurationSec: TimeInterval   // Original duration in seconds
    var balloonRemainingSec: TimeInterval  // Current countdown
    var snoozedUntil: Date?
    var version: Int
    let createdAt: Date
    var updatedAt: Date

    // Derived pressure level
    var pressureLevel: PressureLevel? {
        guard balloonEnabled, balloonDurationSec > 0 else { return nil }
        let ratio = balloonRemainingSec / balloonDurationSec
        if ratio >= 0.75 { return .green }
        if ratio >= 0.25 { return .yellow }
        return .red
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Directive, rhs: Directive) -> Bool { lhs.id == rhs.id }
}

// MARK: - NoteDirective (join)

nonisolated struct NoteDirective: Identifiable, Hashable, Sendable {
    var id: String { "\(noteId)-\(directiveId)" }
    let noteId: UUID
    let directiveId: UUID
    var sortIndex: Int

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NoteDirective, rhs: NoteDirective) -> Bool { lhs.id == rhs.id }
}

// MARK: - Folder (Playbook)

nonisolated struct Folder: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var intent: PlaybookIntent
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Folder, rhs: Folder) -> Bool { lhs.id == rhs.id }
}

// MARK: - DayEntry

nonisolated struct DayEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: String              // yyyy-MM-dd
    var rating: Int?              // 1–10
    var diary: String
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DayEntry, rhs: DayEntry) -> Bool { lhs.id == rhs.id }
}

// MARK: - ScheduleRule

nonisolated struct ScheduleRule: Identifiable, Hashable, Sendable {
    let id: UUID
    let directiveId: UUID
    var ruleType: ScheduleType
    var params: [String: [Int]]   // e.g. { "days": [1,3,5] }
    let createdAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ScheduleRule, rhs: ScheduleRule) -> Bool { lhs.id == rhs.id }
}

// MARK: - ScheduleInstance

nonisolated struct ScheduleInstance: Identifiable, Hashable, Sendable {
    let id: UUID
    let directiveId: UUID
    var date: String              // yyyy-MM-dd
    var status: InstanceStatus

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ScheduleInstance, rhs: ScheduleInstance) -> Bool { lhs.id == rhs.id }
}

// MARK: - Tag

nonisolated struct Tag: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var color: String?            // hex, e.g. "#FF6B6B"

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Tag, rhs: Tag) -> Bool { lhs.id == rhs.id }
}

// MARK: - DirectiveHistory

nonisolated struct DirectiveHistory: Identifiable, Hashable, Sendable {
    let id: UUID
    let directiveId: UUID
    var action: DirectiveHistoryAction
    var payload: String           // JSON string for flexibility
    let createdAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DirectiveHistory, rhs: DirectiveHistory) -> Bool { lhs.id == rhs.id }
}
