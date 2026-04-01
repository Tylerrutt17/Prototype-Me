import UIKit

// MARK: - Note Kind

/// Determines the behavior and display of a NotePage.
nonisolated enum NoteKind: String, Hashable, Codable, CaseIterable, Sendable {
    case regular
    case mode        // Operating‑mode instructions shown on Focus tab
    case framework   // Personal constitution (one per user)
    case situation   // Contextual scenario with linked directives
    case goal        // Goal tracking with linked directives

    var color: UIColor {
        switch self {
        case .regular:   UIColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1.0)  // Blue
        case .mode:      UIColor(red: 0.65, green: 0.40, blue: 0.95, alpha: 1.0)  // Purple
        case .framework: UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 1.0)  // Gold
        case .situation: UIColor(red: 0.30, green: 0.80, blue: 0.65, alpha: 1.0)  // Teal
        case .goal:      UIColor(red: 0.95, green: 0.45, blue: 0.40, alpha: 1.0)  // Salmon
        }
    }

    var iconName: String {
        switch self {
        case .regular:   "doc.text"
        case .mode:      "bolt.fill"
        case .framework: "star.fill"
        case .situation: "cloud.sun.fill"
        case .goal:      "flag.fill"
        }
    }

    var displayName: String {
        switch self {
        case .regular:   "Simple"
        case .mode:      "Situational Mode"
        case .framework: "Framework"
        case .situation: "Situation"
        case .goal:      "Goal"
        }
    }
}

// MARK: - Directive Status

nonisolated enum DirectiveStatus: String, Hashable, Codable, CaseIterable, Sendable {
    case active
    case archived    // Hidden from Focus/balloons, kept for history
}

// MARK: - Pressure Level (Balloon)

/// Derived from remaining time relative to original balloon duration.
///   green  ≥ 75 %
///   yellow 25–75 %
///   red    < 25 %
nonisolated enum PressureLevel: String, Hashable, Codable, CaseIterable, Sendable {
    case green
    case yellow
    case red
}

// MARK: - Schedule Types

nonisolated enum ScheduleType: String, Hashable, Codable, CaseIterable, Sendable {
    case weekly   // Specific weekdays
    case monthly  // Specific dates of month
    case oneOff   // Single date
}

nonisolated enum InstanceStatus: String, Hashable, Codable, CaseIterable, Sendable {
    case pending
    case done
    case skipped
}

// MARK: - Playbook Intent

nonisolated enum PlaybookIntent: String, Hashable, Codable, CaseIterable, Sendable {
    case general
    case learning
    case execution
    case maintenance
}

// MARK: - Directive History Action

nonisolated enum DirectiveHistoryAction: String, Hashable, Codable, CaseIterable, Sendable {
    case create
    case update
    case graduate
    case snooze
    case balloonPump = "balloon_pump"
    case shrink
    case split
    case checklistComplete = "checklist_complete"
}

// MARK: - Subscription Plan

nonisolated enum SubscriptionPlan: String, Hashable, Codable, Sendable {
    case free
    case pro
}

// MARK: - Friend Request Status

nonisolated enum FriendRequestStatus: String, Hashable, Codable, Sendable {
    case pending
    case accepted
    case declined
}

// MARK: - AI Chip Action

/// The kind of mutation an AI chip suggests.
nonisolated enum ChipAction: String, Hashable, Codable, Sendable {
    case createDirective
    case updateDirective
    case createNote
    case activateMode
    case addSchedule
}

// MARK: - Chip Status

/// Lifecycle of a single AI chip suggestion.
nonisolated enum ChipStatus: String, Hashable, Codable, Sendable {
    case suggested     // Freshly returned from the API
    case accepted      // User tapped and confirmed
    case dismissed     // User dismissed the panel without accepting
}
