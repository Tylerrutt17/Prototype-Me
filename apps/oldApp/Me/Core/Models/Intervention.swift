import Foundation
import SwiftData

@Model
public final class Intervention {
    @Attribute public var id: String = UUID().uuidString
    // New unified linking to NotePage
    /// Identifier of the parent `NotePage`. Used for lightweight look-ups and to avoid requiring a full relationship when not needed.
    @Attribute public var pageId: String = ""
    @Relationship public var page: NotePage?
    // Temporary backward-compat alias; remove once migration completes
    @available(*, deprecated, message: "Use pageId instead")
    public var topicId: String {
        get { pageId }
        set { pageId = newValue }
    }
    public var title: String = ""
    public var detailsMarkdown: String = ""
    /// Cached plain-text version (without markdown or custom tags) for quick display/search.
    public var detailsPlain: String = ""
    @Attribute(.externalStorage) public var encodedText: Data? = nil
    public var minSeverity: Int = 0
    public var maxSeverity: Int = 10
    public var priority: Int = 0
    /// Marks this intervention as a user goal. Goal items can be checked off for completion each day.
    public var isGoal: Bool = false
    public var isEveryDay: Bool = false
    /// Optional countdown/balloon that deflates over time and nudges the user to check in.
    public var countdownEnabled: Bool = false
    /// Duration in days for a full balloon cycle. Defaults to 3. (Legacy; see countdownDurationMinutes)
    public var countdownDurationDays: Int = 3
    /// Duration in minutes for finer control (default 3 days).
    public var countdownDurationMinutes: Double = 4_320 // 3 days
    /// When the balloon will be empty. Updated whenever the user "pumps" it.
    public var countdownExpiresAt: Date? = nil
    /// When an expired balloon is allowed to refill (e.g., next 9am at least 24h out).
    public var countdownResetAt: Date? = nil
    public var tagsCSV: String = ""
    /// Manual ordering within its parent note page (lower numbers appear first).
    public var order: Int = 0
    /// Optional slider this intervention uses for severity comparisons.
    public var trackableId: String? = nil
    /// Optional custom color name (overrides trackable color when set).
    public var colorName: String? = nil
    /// Optional row background color for list display.
    public var rowBackgroundName: String? = nil
    /// Whether a daily push notification is enabled for this directive.
    public var dailyNotificationEnabled: Bool = false
    /// Time of day for the daily notification, stored as seconds since midnight. Default 9am.
    public var dailyNotificationTime: Double = 32_400 // 9 * 3600
    public init(title: String = "", order: Int = 0) {
        self.title = title
        self.order = order
    }

    /// Convenience initializer that assigns the parent `NotePage` by id.
    public init(pageId: String, title: String = "", order: Int = 0) {
        self.pageId = pageId
        self.title = title
        self.order = order
    }
}

extension Intervention: RichTextPersistable {
    var bodyMarkdown: String {
        get { detailsMarkdown }
        set { detailsMarkdown = newValue }
    }
}

// MARK: - Countdown helpers
extension Intervention {
    /// Fractional boost applied per pump action (5 taps to refill).
    static let countdownPumpStep: Double = 0.2

    /// Duration in seconds for the configured countdown period (min 1 minute).
    var countdownDurationSeconds: TimeInterval {
        if countdownDurationMinutes <= 0 {
            // Migrate legacy day-based value or ensure a sane default
            countdownDurationMinutes = Double(max(1, countdownDurationDays)) * 1_440
        }
        return max(60, countdownDurationMinutes * 60) // clamp to at least 1 minute
    }

    /// Returns remaining time; nil when countdown is disabled.
    func countdownRemaining(reference: Date = .now) -> TimeInterval? {
        guard countdownEnabled else { return nil }
        if let resetAt = countdownResetAt, reference < resetAt {
            return 0 // stay empty until reset window
        }
        guard let expires = countdownExpiresAt else { return countdownDurationSeconds }
        return max(0, expires.timeIntervalSince(reference))
    }

    /// Progress from 0 (empty) to 1 (full). Nil when countdown is disabled.
    func countdownProgress(reference: Date = .now) -> Double? {
        guard countdownEnabled else { return nil }
        if let resetAt = countdownResetAt, reference < resetAt {
            return 0 // expired but waiting for next window
        }
        if let resetAt = countdownResetAt,
           (countdownExpiresAt ?? resetAt) < resetAt + countdownDurationSeconds,
           reference >= resetAt {
            countdownExpiresAt = resetAt.addingTimeInterval(countdownDurationSeconds)
            countdownResetAt = nil
        }
        let duration = countdownDurationSeconds
        guard duration > 0 else { return nil }
        let remaining = countdownRemaining(reference: reference) ?? duration
        return max(0, min(1, remaining / duration))
    }

    /// Seeds an expiry if missing so the countdown can start ticking.
    func seedCountdownIfNeeded(now: Date = .now) {
        guard countdownEnabled, countdownExpiresAt == nil else { return }
        countdownResetAt = nil
        countdownExpiresAt = now.addingTimeInterval(countdownDurationSeconds)
    }

    /// Rescales expiry when duration changes while preserving current fill ratio.
    func rescaleCountdownDuration(toMinutes minutes: Double, now: Date = .now) {
        let ratio = countdownProgress(reference: now) ?? 1.0
        let clampedMinutes = max(1, minutes)
        countdownDurationMinutes = clampedMinutes
        countdownDurationDays = max(1, Int(ceil(clampedMinutes / 1_440)))
        countdownResetAt = nil
        countdownExpiresAt = now.addingTimeInterval(countdownDurationSeconds * ratio)
    }

    /// Pumps the balloon by one or more presses; returns new progress.
    @discardableResult
    func pumpCountdown(now: Date = .now, presses: Int = 1) -> Double {
        guard countdownEnabled else { return 0 }
        let step = countdownDurationSeconds * Self.countdownPumpStep * Double(max(1, presses))
        let base = max(countdownExpiresAt ?? now, now)
        let cap = now.addingTimeInterval(countdownDurationSeconds)
        countdownResetAt = nil
        countdownExpiresAt = min(base + step, cap)
        return countdownProgress(reference: now) ?? 0
    }
}
