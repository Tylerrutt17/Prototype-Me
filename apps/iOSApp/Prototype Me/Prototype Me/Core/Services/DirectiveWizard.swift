import Foundation

/// Dummy AI suggestion engine for directive creation.
/// Matches keywords in the user's problem description to preset suggestions.
/// Will be replaced with real AI backend calls later.
enum DirectiveWizard {

    struct Suggestion {
        let title: String
        let body: String
    }

    /// Returns 3-5 directive suggestions based on the problem description.
    static func suggest(for problem: String) -> [Suggestion] {
        let lower = problem.lowercased()

        // Match against keyword groups, collect all matches, then dedupe/limit
        var matches: [Suggestion] = []

        if lower.containsAny(["sleep", "tired", "exhausted", "stay up", "staying up", "insomnia", "groggy", "wake", "waking", "morning", "energy", "bed"]) {
            matches.append(contentsOf: sleepSuggestions)
        }
        if lower.containsAny(["focus", "distract", "concentrate", "attention", "phone", "scroll", "procrastinat"]) {
            matches.append(contentsOf: focusSuggestions)
        }
        if lower.containsAny(["eye", "screen", "strain", "headache", "computer", "posture", "sitting", "back", "neck"]) {
            matches.append(contentsOf: ergonomicSuggestions)
        }
        if lower.containsAny(["angry", "irritab", "frustrat", "stress", "anxious", "anxiety", "overwhelm", "mood", "temper", "calm"]) {
            matches.append(contentsOf: emotionalSuggestions)
        }
        if lower.containsAny(["negative", "self-talk", "confidence", "doubt", "worth", "hate myself", "critical", "harsh"]) {
            matches.append(contentsOf: selfTalkSuggestions)
        }
        if lower.containsAny(["exercise", "workout", "gym", "move", "sedentary", "lazy", "active", "fit", "weight"]) {
            matches.append(contentsOf: exerciseSuggestions)
        }
        if lower.containsAny(["social", "friend", "lonely", "isolat", "awkward", "conversation", "people"]) {
            matches.append(contentsOf: socialSuggestions)
        }
        if lower.containsAny(["eat", "diet", "food", "junk", "sugar", "snack", "healthy", "water", "drink"]) {
            matches.append(contentsOf: dietSuggestions)
        }

        // If no keyword matches, return generic suggestions
        if matches.isEmpty {
            matches = genericSuggestions
        }

        // Dedupe by title and limit to 5
        var seen = Set<String>()
        var unique: [Suggestion] = []
        for s in matches {
            if !seen.contains(s.title) {
                seen.insert(s.title)
                unique.append(s)
            }
            if unique.count >= 5 { break }
        }

        return unique
    }

    // MARK: - Suggestion Banks

    private static let sleepSuggestions: [Suggestion] = [
        Suggestion(title: "No screens after 8pm", body: "Blue light kills melatonin. Phone goes on the charger across the room at 8."),
        Suggestion(title: "NSDR for 10 min before bed", body: "Non-sleep deep rest. YouTube has guided ones. Resets the nervous system."),
        Suggestion(title: "Cold water on face in the morning", body: "Triggers the dive reflex. Instant alertness without needing caffeine right away."),
        Suggestion(title: "Same wake time every day — even weekends", body: "Consistency matters more than total hours. Pick a time and stick to it."),
        Suggestion(title: "No caffeine after 12pm", body: "Caffeine has a 6-hour half-life. That 3pm coffee is still in your system at bedtime."),
    ]

    private static let focusSuggestions: [Suggestion] = [
        Suggestion(title: "Phone in another room during work", body: "Not on silent. Not flipped over. In another room. Out of sight, out of mind."),
        Suggestion(title: "One task at a time — no tab switching", body: "Pick one thing. Close everything else. Multitasking is a lie."),
        Suggestion(title: "2-minute rule: if it takes 2 min, do it now", body: "Small tasks pile up and create mental clutter. Knock them out immediately."),
        Suggestion(title: "Set a 25-min timer, then break", body: "Pomodoro technique. Work in focused bursts. The timer creates urgency."),
        Suggestion(title: "Write down what you'll do before you start", body: "Spend 30 seconds writing the specific task. Clarity kills procrastination."),
    ]

    private static let ergonomicSuggestions: [Suggestion] = [
        Suggestion(title: "20-20-20 rule for eyes", body: "Every 20 minutes, look at something 20 feet away for 20 seconds. Prevents eye strain."),
        Suggestion(title: "Stand up and stretch every 45 min", body: "Set a timer. Stand, stretch, walk for 1 minute. Your back will thank you."),
        Suggestion(title: "Monitor at eye level", body: "Top of the screen should be at eye level. Looking down causes neck strain."),
        Suggestion(title: "10 pushups every hour", body: "Gets blood flowing, breaks the sitting cycle, builds a habit without a gym."),
    ]

    private static let emotionalSuggestions: [Suggestion] = [
        Suggestion(title: "4-7-8 breathing when triggered", body: "Inhale 4 seconds, hold 7, exhale 8. Does something physiological — actually calms the nervous system."),
        Suggestion(title: "Name the emotion out loud", body: "\"I'm feeling frustrated.\" Labeling it reduces its intensity. It's neuroscience."),
        Suggestion(title: "Walk away for 90 seconds", body: "The chemical spike from anger lasts about 90 seconds. Wait it out, then respond."),
        Suggestion(title: "Ask: will this matter in a week?", body: "Most things that feel urgent aren't. This question creates instant perspective."),
        Suggestion(title: "Find humor in whatever's happening", body: "Not toxic positivity — just finding the absurdity. Laughter resets your state faster than anything."),
    ]

    private static let selfTalkSuggestions: [Suggestion] = [
        Suggestion(title: "Catch the thought, then reframe it", body: "When you hear \"I'm terrible at this\" — pause and reframe: \"I'm learning this.\""),
        Suggestion(title: "Talk to yourself like you'd talk to a friend", body: "You'd never say that stuff to someone you care about. Extend yourself the same kindness."),
        Suggestion(title: "Write down 1 thing you did well today", body: "Not 3, not 5. Just 1. Make it specific. Build evidence against the inner critic."),
        Suggestion(title: "Replace \"I should\" with \"I could\"", body: "\"Should\" creates guilt. \"Could\" creates options. Small word change, big shift."),
    ]

    private static let exerciseSuggestions: [Suggestion] = [
        Suggestion(title: "10-min walk after every meal", body: "Lowest barrier to entry. No gym, no gear. Improves digestion and clears the head."),
        Suggestion(title: "Do 1 pushup. That's it.", body: "The goal isn't the pushup — it's showing up. Once you're down there, you'll do more."),
        Suggestion(title: "Lay out workout clothes the night before", body: "Remove the decision in the morning. See them, put them on, go."),
        Suggestion(title: "Exercise before the brain has time to argue", body: "Don't think about it. First 30 minutes of the day, just move. Think later."),
    ]

    private static let socialSuggestions: [Suggestion] = [
        Suggestion(title: "Text one person per day — just to check in", body: "Not a novel. Just \"hey, how's it going?\" Low effort, high connection over time."),
        Suggestion(title: "Say yes to the next invite", body: "Don't think about it. The next thing someone invites you to, go. Break the pattern."),
        Suggestion(title: "Ask one real question in every conversation", body: "Not \"how are you.\" Something specific. People remember when you're genuinely curious."),
        Suggestion(title: "Compliment someone every day", body: "Genuine, specific compliments. \"That was a great point you made.\" Opens doors."),
    ]

    private static let dietSuggestions: [Suggestion] = [
        Suggestion(title: "Drink a full glass of water before eating", body: "Dehydration feels like hunger. Water first, then decide if you're actually hungry."),
        Suggestion(title: "No eating after 8pm", body: "Late eating disrupts sleep and digestion. Kitchen closes at 8."),
        Suggestion(title: "Keep junk food out of the house", body: "You can't eat what isn't there. Willpower is finite — environment design isn't."),
        Suggestion(title: "Prep one healthy meal on Sunday", body: "Just one. Having one go-to meal ready removes the \"I'll just order food\" excuse."),
    ]

    private static let genericSuggestions: [Suggestion] = [
        Suggestion(title: "Write down what's bothering you", body: "Get it out of your head and onto paper. Clarity comes from seeing it written out."),
        Suggestion(title: "Do the thing you're avoiding for just 2 min", body: "Start the timer. You can stop after 2 minutes. You won't want to."),
        Suggestion(title: "Identify the trigger, not just the symptom", body: "\"I feel off\" isn't enough. What happened right before? That's what you fix."),
        Suggestion(title: "Remove one thing that drags you down", body: "Don't add a new habit. Remove something bad. Via negativa — subtraction beats addition."),
        Suggestion(title: "Ask: what would make tomorrow 10% better?", body: "Not a whole new routine. Just one small thing. Then do that."),
    ]
}

// MARK: - String Helper

private extension String {
    func containsAny(_ keywords: [String]) -> Bool {
        keywords.contains { self.contains($0) }
    }
}
