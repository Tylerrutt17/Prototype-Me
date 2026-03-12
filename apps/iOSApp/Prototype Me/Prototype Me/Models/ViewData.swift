import Foundation

// MARK: - NoteListItem

/// Composed view data for note list rows.
nonisolated struct NoteListItem: Hashable, Sendable {
    let note: NotePage
    let directiveCount: Int
    let folderName: String?

    func hash(into hasher: inout Hasher) { hasher.combine(note.id) }
    static func == (lhs: NoteListItem, rhs: NoteListItem) -> Bool { lhs.note.id == rhs.note.id }
}

// MARK: - DirectiveRowData

/// Composed view data for directive rows, including balloon + schedule state.
nonisolated struct DirectiveRowData: Hashable, Sendable {
    let directive: Directive
    let scheduledToday: Bool
    let instanceStatus: InstanceStatus?

    var pressureLevel: PressureLevel? { directive.pressureLevel }

    func hash(into hasher: inout Hasher) { hasher.combine(directive.id) }
    static func == (lhs: DirectiveRowData, rhs: DirectiveRowData) -> Bool {
        lhs.directive.id == rhs.directive.id
    }
}

// MARK: - FocusSnapshot

/// All data needed to render the Focus screen.
nonisolated struct FocusSnapshot: Sendable {
    let activeModes: [NotePage]                    // 1–3 mode notes
    let urgentBalloons: [DirectiveRowData]         // Sorted by remaining time asc
    let todaySchedule: [ScheduleInstanceRow]       // Today's pending items
}

// MARK: - ScheduleInstanceRow

/// Flattened row for schedule display (directive name + status).
nonisolated struct ScheduleInstanceRow: Hashable, Sendable {
    let instance: ScheduleInstance
    let directiveTitle: String

    func hash(into hasher: inout Hasher) { hasher.combine(instance.id) }
    static func == (lhs: ScheduleInstanceRow, rhs: ScheduleInstanceRow) -> Bool {
        lhs.instance.id == rhs.instance.id
    }
}

// MARK: - DayEntrySummary

/// Composed view data for diary list rows.
nonisolated struct DayEntrySummary: Hashable, Sendable {
    let entry: DayEntry
    let tagNames: [String]
    let diaryPreview: String

    func hash(into hasher: inout Hasher) { hasher.combine(entry.id) }
    static func == (lhs: DayEntrySummary, rhs: DayEntrySummary) -> Bool {
        lhs.entry.id == rhs.entry.id
    }
}

// MARK: - PlaybookListItem

/// Composed view data for playbook (folder) list rows.
nonisolated struct PlaybookListItem: Hashable, Sendable {
    let folder: Folder
    let noteCount: Int
    let directiveCount: Int

    func hash(into hasher: inout Hasher) { hasher.combine(folder.id) }
    static func == (lhs: PlaybookListItem, rhs: PlaybookListItem) -> Bool {
        lhs.folder.id == rhs.folder.id
    }
}
