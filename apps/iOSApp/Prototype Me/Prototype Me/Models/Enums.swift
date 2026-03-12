import Foundation

// MARK: - Note Kind

/// Determines the behavior and display of a NotePage.
nonisolated enum NoteKind: String, Hashable, Codable, CaseIterable, Sendable {
    case regular
    case mode        // Operating‑mode instructions shown on Focus tab
    case framework   // Personal constitution (one per user)
}

// MARK: - Tier

/// Priority tier that controls how a note or directive surfaces.
nonisolated enum Tier: String, Hashable, Codable, CaseIterable, Sendable {
    case foundation  // Passive, always‑on habits
    case support     // Supporting routines
    case active      // Situational, effortful
}

// MARK: - Directive Status

nonisolated enum DirectiveStatus: String, Hashable, Codable, CaseIterable, Sendable {
    case active
    case maintained  // Collapsed / hidden from primary views
    case retired
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
}
