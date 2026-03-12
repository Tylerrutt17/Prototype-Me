import Foundation

enum DailyReminderStage {
    case primary
    case followup1
    case followup2
}

enum DailyReminderMessages {
    private static let primaryBodies: [String] = [
        "Morning start: open Improve and pick one move.",
        "Quick morning tap—check Improve and choose one step.",
        "Begin the day with one Improve action.",
        "Open Improve and set your first move for today.",
        "Tap in now: one small morning step on Improve.",
        "Kick off with one tiny Improve action.",
        "Start light: open Improve and nudge one item.",
        "One tap to set the tone—open Improve.",
        "Ease in: pick the smallest Improve step.",
        "Open Improve and line up your first win."
    ]

    private static let followup1Bodies: [String] = [
        "Still morning—open Improve and push one item.",
        "Nudge: grab your phone and tap Improve once.",
        "Keep it light: one quick Improve action now.",
        "Pick up the app—choose one tiny morning move.",
        "Back to Improve: one tap, one step.",
        "Second reminder: open Improve and move one thing.",
        "Stay loose—tap Improve and slide one item forward.",
        "Morning momentum: Improve needs one touch.",
        "Quick check: open Improve and do one small bit.",
        "Two minutes: tap Improve and make a micro-move."
    ]

    private static let followup2Bodies: [String] = [
        "LAST morning call—open Improve right now.",
        "FINAL nudge: pick up the app and tap Improve.",
        "Clock’s ticking—OPEN Improve and move one thing.",
        "Grab the app: one FAST Improve step before you go.",
        "Don’t miss it—Improve needs ONE TAP now.",
        "Last chance this morning—Improve wants one move.",
        "Now or never: tap Improve and push one item.",
        "Time’s almost up—OPEN Improve and act once.",
        "One more push: pick up the phone and tap Improve.",
        "Finish the morning strong—one quick Improve step."
    ]

    static func random(for stage: DailyReminderStage) -> String {
        let pool: [String]
        switch stage {
        case .primary: pool = primaryBodies
        case .followup1: pool = followup1Bodies
        case .followup2: pool = followup2Bodies
        }
        return pool.randomElement() ?? "Time to check in—add a quick note."
    }
}
