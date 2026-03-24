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

    var pressureLevel: PressureLevel? { directive.pressureLevel }

    func hash(into hasher: inout Hasher) { hasher.combine(directive.id) }
    static func == (lhs: DirectiveRowData, rhs: DirectiveRowData) -> Bool {
        lhs.directive.id == rhs.directive.id
    }
}

// MARK: - FocusSnapshot

/// All data needed to render the Focus screen.
nonisolated struct FocusSnapshot: Sendable {
    let allModes: [NotePage]                       // All mode notes for the carousel
    let activeModeId: UUID?                        // Currently active mode (nil = no mode)
    let modeDirectives: [DirectiveRowData]         // Linked directives for the active mode
    let urgentBalloons: [DirectiveRowData]         // Sorted by remaining time asc
    let todaySchedule: [ScheduleInstanceRow]       // Today's pending items
}

// MARK: - ScheduleInstanceRow

/// Flattened row for schedule display (rule + directive title).
nonisolated struct ScheduleInstanceRow: Hashable, Sendable {
    let rule: ScheduleRule
    let directiveTitle: String

    /// Whether the rule was completed today.
    var isCompletedToday: Bool {
        guard let last = rule.lastCompletedDate else { return false }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return last == fmt.string(from: Date())
    }

    func hash(into hasher: inout Hasher) { hasher.combine(rule.id) }
    static func == (lhs: ScheduleInstanceRow, rhs: ScheduleInstanceRow) -> Bool {
        lhs.rule.id == rhs.rule.id
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

// MARK: - ModeDetailData

/// All data needed to render a Mode detail screen.
nonisolated struct ModeDetailData: Sendable {
    let note: NotePage
    let isActive: Bool
    let linkedDirectives: [DirectiveRowData]
}

// MARK: - HistoryMonthSummary

/// Aggregated diary data for a single month.
nonisolated struct HistoryMonthSummary: Hashable, Sendable {
    let month: String             // yyyy-MM
    let entryCount: Int
    let averageRating: Double?
    let bestDay: DayEntry?
    let worstDay: DayEntry?
    let topTags: [String]         // Most frequently used tags

    func hash(into hasher: inout Hasher) { hasher.combine(month) }
    static func == (lhs: HistoryMonthSummary, rhs: HistoryMonthSummary) -> Bool {
        lhs.month == rhs.month
    }
}

// MARK: - SeedPlanCard

enum SeedCardType: String, Codable, Sendable { case directive, folder }

/// View data for onboarding seed plan cards.
nonisolated struct SeedPlanCard: Hashable, Codable, Sendable {
    let id: UUID
    let type: SeedCardType
    let title: String
    let body: String
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

// MARK: - SubscriptionInfo

/// View data for the subscription/paywall screens.
nonisolated struct SubscriptionInfo: Hashable, Codable, Sendable {
    let plan: SubscriptionPlan
    let expiresAt: Date?
    let isTrialActive: Bool
    let trialDaysRemaining: Int?
}

// MARK: - UsageQuota

/// View data for the AI usage / limit screen.
nonisolated struct UsageQuota: Hashable, Codable, Sendable {
    let dailyLimit: Int
    let dailyUsed: Int
    let resetAt: Date

    var remaining: Int { max(0, dailyLimit - dailyUsed) }
    var usageRatio: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(dailyUsed) / Double(dailyLimit)
    }
}

// MARK: - UserProfile

/// View data for the profile screen (self or friend).
nonisolated struct UserProfile: Hashable, Codable, Sendable {
    let id: UUID
    let displayName: String
    let bio: String?
    let avatarSystemImage: String   // SF Symbol for now; URL later
    let moodChips: [String]
    let joinedAt: Date
    let plan: SubscriptionPlan

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool { lhs.id == rhs.id }
}

// MARK: - FriendItem

/// View data for a row in the friends list.
nonisolated struct FriendItem: Hashable, Codable, Sendable {
    let id: UUID
    let displayName: String
    let avatarSystemImage: String
    let status: FriendRequestStatus
    let since: Date?                // nil for pending requests

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: FriendItem, rhs: FriendItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - PaywallFeature

/// A feature row displayed on the paywall comparison.
nonisolated struct PaywallFeature: Hashable, Sendable {
    let title: String
    let freeValue: String
    let proValue: String
}

// MARK: - CoachMark

/// Describes a single coach mark tooltip.
nonisolated struct CoachMark: Hashable, Sendable {
    let id: String
    let title: String
    let body: String
    let pointingDirection: CoachMarkDirection
    let tabIndex: Int  // 0=Focus, 1=Notes, 2=Playbooks, 3=Diary, 4=Settings
}

nonisolated enum CoachMarkDirection: String, Hashable, Sendable {
    case up, down, left, right
}

// MARK: - AiChip

/// A single AI suggestion chip.
nonisolated struct AiChip: Hashable, Codable, Sendable {
    let id: UUID
    let action: ChipAction
    let title: String           // e.g. "Add a morning walk"
    let subtitle: String        // e.g. "Based on your low energy diary entries"
    let destination: String     // Human-readable target: "Directives", "Notes", etc.
    var status: ChipStatus

    // Pre-filled fields for the confirm screen
    let prefillTitle: String?
    let prefillBody: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AiChip, rhs: AiChip) -> Bool { lhs.id == rhs.id }
}

// MARK: - AiDraft

/// API response containing a batch of AI chip suggestions + updated quota.
nonisolated struct AiDraft: Codable, Sendable {
    let chips: [AiChip]
    let remainingQuota: Int
    let resetAt: Date
}
