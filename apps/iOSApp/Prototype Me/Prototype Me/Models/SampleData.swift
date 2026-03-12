import Foundation
import UIKit

// MARK: - SampleData

/// Realistic dummy data for all screens. Replace with GRDB ValueObservation later.
enum SampleData {

    // MARK: Stable UUIDs

    enum IDs {
        // Folders
        static let folderMorning   = UUID(uuidString: "00000001-0001-0001-0001-000000000001")!
        static let folderFitness   = UUID(uuidString: "00000001-0001-0001-0001-000000000002")!
        static let folderLearning  = UUID(uuidString: "00000001-0001-0001-0001-000000000003")!

        // Notes
        static let noteFramework   = UUID(uuidString: "00000002-0002-0002-0002-000000000001")!
        static let noteModeDeep    = UUID(uuidString: "00000002-0002-0002-0002-000000000002")!
        static let noteModeSocial  = UUID(uuidString: "00000002-0002-0002-0002-000000000003")!
        static let noteModeRecov   = UUID(uuidString: "00000002-0002-0002-0002-000000000004")!
        static let noteHabits      = UUID(uuidString: "00000002-0002-0002-0002-000000000005")!
        static let noteMealPrep    = UUID(uuidString: "00000002-0002-0002-0002-000000000006")!
        static let noteReading     = UUID(uuidString: "00000002-0002-0002-0002-000000000007")!
        static let noteJournal     = UUID(uuidString: "00000002-0002-0002-0002-000000000008")!

        // Directives
        static let dirMeditate     = UUID(uuidString: "00000003-0003-0003-0003-000000000001")!
        static let dirExercise     = UUID(uuidString: "00000003-0003-0003-0003-000000000002")!
        static let dirRead30       = UUID(uuidString: "00000003-0003-0003-0003-000000000003")!
        static let dirHydrate      = UUID(uuidString: "00000003-0003-0003-0003-000000000004")!
        static let dirJournal      = UUID(uuidString: "00000003-0003-0003-0003-000000000005")!
        static let dirMealPrep     = UUID(uuidString: "00000003-0003-0003-0003-000000000006")!
        static let dirDeepWork     = UUID(uuidString: "00000003-0003-0003-0003-000000000007")!
        static let dirStretch      = UUID(uuidString: "00000003-0003-0003-0003-000000000008")!
        static let dirGratitude    = UUID(uuidString: "00000003-0003-0003-0003-000000000009")!
        static let dirNoPhone      = UUID(uuidString: "00000003-0003-0003-0003-00000000000A")!
        static let dirColdShower   = UUID(uuidString: "00000003-0003-0003-0003-00000000000B")!
        static let dirReview       = UUID(uuidString: "00000003-0003-0003-0003-00000000000C")!
        static let dirSleep        = UUID(uuidString: "00000003-0003-0003-0003-00000000000D")!
        static let dirVocab        = UUID(uuidString: "00000003-0003-0003-0003-00000000000E")!
        static let dirWalk         = UUID(uuidString: "00000003-0003-0003-0003-00000000000F")!

        // Tags
        static let tagHealth       = UUID(uuidString: "00000004-0004-0004-0004-000000000001")!
        static let tagMindset      = UUID(uuidString: "00000004-0004-0004-0004-000000000002")!
        static let tagProductivity = UUID(uuidString: "00000004-0004-0004-0004-000000000003")!
        static let tagWellness     = UUID(uuidString: "00000004-0004-0004-0004-000000000004")!
        static let tagStress       = UUID(uuidString: "00000004-0004-0004-0004-000000000005")!

        // DayEntries
        static let day1 = UUID(uuidString: "00000005-0005-0005-0005-000000000001")!
        static let day2 = UUID(uuidString: "00000005-0005-0005-0005-000000000002")!
        static let day3 = UUID(uuidString: "00000005-0005-0005-0005-000000000003")!
        static let day4 = UUID(uuidString: "00000005-0005-0005-0005-000000000004")!
        static let day5 = UUID(uuidString: "00000005-0005-0005-0005-000000000005")!
        static let day6 = UUID(uuidString: "00000005-0005-0005-0005-000000000006")!
        static let day7 = UUID(uuidString: "00000005-0005-0005-0005-000000000007")!
        static let day8 = UUID(uuidString: "00000005-0005-0005-0005-000000000008")!
        static let day9 = UUID(uuidString: "00000005-0005-0005-0005-000000000009")!
        static let day10 = UUID(uuidString: "00000005-0005-0005-0005-00000000000A")!
    }

    // MARK: - Helpers

    private static let cal = Calendar.current

    private static func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: .now)!
    }

    private static func dateString(_ daysAgo: Int) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: self.daysAgo(daysAgo))
    }

    // MARK: - Folders

    static let folders: [Folder] = [
        Folder(id: IDs.folderMorning,  name: "Morning Routine",    intent: .execution,   createdAt: daysAgo(60), updatedAt: daysAgo(2)),
        Folder(id: IDs.folderFitness,  name: "Fitness & Recovery",  intent: .maintenance, createdAt: daysAgo(45), updatedAt: daysAgo(1)),
        Folder(id: IDs.folderLearning, name: "Learning System",     intent: .learning,    createdAt: daysAgo(30), updatedAt: daysAgo(3)),
    ]

    // MARK: - Notes

    static let notes: [NotePage] = [
        // Framework note (one per user)
        NotePage(id: IDs.noteFramework, title: "Personal Framework", body: """
            ## Core Values
            - **Growth**: Always be learning and improving.
            - **Discipline**: Consistency over motivation.
            - **Balance**: Mind, body, relationships.

            ## Guiding Principles
            1. Start small, build momentum.
            2. Protect your energy — say no more often.
            3. Review weekly, adjust monthly.
            """, kind: .framework, tier: .foundation, folderId: nil, sortIndex: 0, version: 3, createdAt: daysAgo(90), updatedAt: daysAgo(5)),

        // Mode notes
        NotePage(id: IDs.noteModeDeep, title: "Deep Work Mode", body: """
            Phone on DND. Close Slack. Work in 50-min blocks with 10-min breaks.
            Only check messages between blocks.
            """, kind: .mode, tier: .active, folderId: nil, sortIndex: 1, version: 2, createdAt: daysAgo(60), updatedAt: daysAgo(7)),

        NotePage(id: IDs.noteModeSocial, title: "Social Mode", body: """
            Be present. Put phone away. Ask questions and listen.
            Remember: connection > content.
            """, kind: .mode, tier: .active, folderId: nil, sortIndex: 2, version: 1, createdAt: daysAgo(45), updatedAt: daysAgo(20)),

        NotePage(id: IDs.noteModeRecov, title: "Recovery Mode", body: """
            Low-energy protocol. No screens after 9 PM. Light stretching only.
            Permission to do the minimum today.
            """, kind: .mode, tier: .support, folderId: nil, sortIndex: 3, version: 1, createdAt: daysAgo(30), updatedAt: daysAgo(10)),

        // Regular notes linked to folders
        NotePage(id: IDs.noteHabits, title: "Morning Habits Stack", body: """
            1. Wake at 6:30 AM
            2. Cold water + hydrate
            3. 10-min meditation
            4. Gratitude journaling
            5. 30-min exercise
            """, kind: .regular, tier: .foundation, folderId: IDs.folderMorning, sortIndex: 0, version: 4, createdAt: daysAgo(60), updatedAt: daysAgo(1)),

        NotePage(id: IDs.noteMealPrep, title: "Meal Prep Guide", body: """
            ## Sunday Prep
            - Cook protein (chicken / tofu)
            - Prep vegetables
            - Make overnight oats x3

            ## Mid-week Top-up
            - Fresh salad ingredients
            - Smoothie packs
            """, kind: .regular, tier: .support, folderId: IDs.folderFitness, sortIndex: 0, version: 2, createdAt: daysAgo(40), updatedAt: daysAgo(8)),

        NotePage(id: IDs.noteReading, title: "Reading List & Notes", body: """
            ## Currently Reading
            - *Atomic Habits* — Ch. 12
            - *Deep Work* — Finished

            ## Key Takeaways
            - Systems > Goals
            - Environment design matters more than willpower
            """, kind: .regular, tier: .support, folderId: IDs.folderLearning, sortIndex: 0, version: 5, createdAt: daysAgo(30), updatedAt: daysAgo(2)),

        NotePage(id: IDs.noteJournal, title: "Weekly Review Template", body: """
            ## What went well?
            _List 3 wins from this week._

            ## What needs attention?
            _Identify 1–2 areas to improve._

            ## Next week's focus
            _Pick your top 3 priorities._
            """, kind: .regular, tier: .active, folderId: nil, sortIndex: 4, version: 1, createdAt: daysAgo(14), updatedAt: daysAgo(7)),
    ]

    // MARK: - Directives

    static let directives: [Directive] = [
        // Foundation tier — always‑on habits
        Directive(id: IDs.dirMeditate, title: "Meditate 10 min", body: "Sit quietly, focus on breath. Use Headspace if needed.", status: .active, balloonEnabled: true, balloonDurationSec: 86400, balloonRemainingSec: 72000, snoozedUntil: nil, version: 3, createdAt: daysAgo(60), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirHydrate, title: "Drink 2L water", body: "Track with water bottle marks. Front-load morning.", status: .active, balloonEnabled: true, balloonDurationSec: 43200, balloonRemainingSec: 10000, snoozedUntil: nil, version: 2, createdAt: daysAgo(55), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirSleep, title: "Lights out by 10:30 PM", body: "No screens after 10 PM. Set alarm. Wind-down routine.", status: .active, balloonEnabled: false, balloonDurationSec: 0, balloonRemainingSec: 0, snoozedUntil: nil, version: 1, createdAt: daysAgo(50), updatedAt: daysAgo(5)),

        Directive(id: IDs.dirGratitude, title: "Write 3 gratitudes", body: nil, status: .active, balloonEnabled: true, balloonDurationSec: 86400, balloonRemainingSec: 60000, snoozedUntil: nil, version: 1, createdAt: daysAgo(45), updatedAt: daysAgo(0)),

        // Support tier
        Directive(id: IDs.dirExercise, title: "30-min workout", body: "Alternate: strength / cardio / yoga. Log in fitness app.", status: .active, balloonEnabled: true, balloonDurationSec: 86400, balloonRemainingSec: 5400, snoozedUntil: nil, version: 5, createdAt: daysAgo(60), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirStretch, title: "Morning stretch routine", body: "10 min. Hamstrings, shoulders, spine.", status: .active, balloonEnabled: false, balloonDurationSec: 0, balloonRemainingSec: 0, snoozedUntil: nil, version: 1, createdAt: daysAgo(40), updatedAt: daysAgo(3)),

        Directive(id: IDs.dirMealPrep, title: "Sunday meal prep", body: "Prep protein, veggies, and overnight oats for the week.", status: .active, balloonEnabled: true, balloonDurationSec: 604800, balloonRemainingSec: 172800, snoozedUntil: nil, version: 2, createdAt: daysAgo(35), updatedAt: daysAgo(1)),

        Directive(id: IDs.dirWalk, title: "20-min walk after lunch", body: "Get outside. No phone.", status: .active, balloonEnabled: false, balloonDurationSec: 0, balloonRemainingSec: 0, snoozedUntil: nil, version: 1, createdAt: daysAgo(30), updatedAt: daysAgo(0)),

        // Active tier
        Directive(id: IDs.dirRead30, title: "Read 30 pages", body: "Current book. No phone nearby. Take notes.", status: .active, balloonEnabled: true, balloonDurationSec: 86400, balloonRemainingSec: 43200, snoozedUntil: nil, version: 2, createdAt: daysAgo(30), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirDeepWork, title: "2-hr deep work block", body: "Phone on DND. One task only. 50/10 split.", status: .active, balloonEnabled: true, balloonDurationSec: 28800, balloonRemainingSec: 3600, snoozedUntil: nil, version: 3, createdAt: daysAgo(45), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirJournal, title: "Evening journal entry", body: "Reflect on the day. What went well? What to improve?", status: .active, balloonEnabled: true, balloonDurationSec: 86400, balloonRemainingSec: 80000, snoozedUntil: nil, version: 1, createdAt: daysAgo(20), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirNoPhone, title: "No phone first hour", body: "Leave phone in another room until after morning routine.", status: .maintained, balloonEnabled: false, balloonDurationSec: 0, balloonRemainingSec: 0, snoozedUntil: nil, version: 2, createdAt: daysAgo(50), updatedAt: daysAgo(15)),

        Directive(id: IDs.dirColdShower, title: "Cold shower 2 min", body: "End every shower with 2 min cold. Breathe through it.", status: .active, balloonEnabled: false, balloonDurationSec: 0, balloonRemainingSec: 0, snoozedUntil: daysAgo(-2), version: 1, createdAt: daysAgo(25), updatedAt: daysAgo(10)),

        Directive(id: IDs.dirReview, title: "Weekly review", body: "Use the weekly review template. Sunday afternoon.", status: .active, balloonEnabled: true, balloonDurationSec: 604800, balloonRemainingSec: 259200, snoozedUntil: nil, version: 2, createdAt: daysAgo(30), updatedAt: daysAgo(0)),

        Directive(id: IDs.dirVocab, title: "Learn 5 new words", body: "Use Anki deck. Review + add new cards.", status: .retired, balloonEnabled: false, balloonDurationSec: 0, balloonRemainingSec: 0, snoozedUntil: nil, version: 3, createdAt: daysAgo(60), updatedAt: daysAgo(20)),
    ]

    // MARK: - NoteDirective Links

    static let noteDirectives: [NoteDirective] = [
        // Morning Habits → meditate, hydrate, gratitude, stretch, no phone
        NoteDirective(noteId: IDs.noteHabits, directiveId: IDs.dirMeditate,  sortIndex: 0),
        NoteDirective(noteId: IDs.noteHabits, directiveId: IDs.dirHydrate,   sortIndex: 1),
        NoteDirective(noteId: IDs.noteHabits, directiveId: IDs.dirGratitude, sortIndex: 2),
        NoteDirective(noteId: IDs.noteHabits, directiveId: IDs.dirStretch,   sortIndex: 3),
        NoteDirective(noteId: IDs.noteHabits, directiveId: IDs.dirNoPhone,   sortIndex: 4),

        // Meal Prep Guide → meal prep
        NoteDirective(noteId: IDs.noteMealPrep, directiveId: IDs.dirMealPrep, sortIndex: 0),

        // Reading List → read 30, vocab
        NoteDirective(noteId: IDs.noteReading, directiveId: IDs.dirRead30, sortIndex: 0),
        NoteDirective(noteId: IDs.noteReading, directiveId: IDs.dirVocab, sortIndex: 1),

        // Weekly Review Template → review, journal
        NoteDirective(noteId: IDs.noteJournal, directiveId: IDs.dirReview,  sortIndex: 0),
        NoteDirective(noteId: IDs.noteJournal, directiveId: IDs.dirJournal, sortIndex: 1),

        // Deep Work Mode → deep work
        NoteDirective(noteId: IDs.noteModeDeep, directiveId: IDs.dirDeepWork, sortIndex: 0),
        NoteDirective(noteId: IDs.noteModeDeep, directiveId: IDs.dirNoPhone,  sortIndex: 1),

        // Recovery Mode → stretch, sleep
        NoteDirective(noteId: IDs.noteModeRecov, directiveId: IDs.dirStretch, sortIndex: 0),
        NoteDirective(noteId: IDs.noteModeRecov, directiveId: IDs.dirSleep,   sortIndex: 1),
    ]

    // MARK: - Tags

    static let tags: [Tag] = [
        Tag(id: IDs.tagHealth,       name: "health",       color: "#4ECDC4"),
        Tag(id: IDs.tagMindset,      name: "mindset",      color: "#A78BFA"),
        Tag(id: IDs.tagProductivity, name: "productivity",  color: "#60A5FA"),
        Tag(id: IDs.tagWellness,     name: "wellness",     color: "#34D399"),
        Tag(id: IDs.tagStress,       name: "stress",       color: "#F87171"),
    ]

    // MARK: - DayEntries

    static let dayEntries: [DayEntry] = [
        DayEntry(id: IDs.day1,  date: dateString(0), rating: 8, diary: "Great morning routine. Hit all habits. Deep work session was productive — shipped the auth feature. Feeling energized.", tags: ["productive", "health"], createdAt: daysAgo(0), updatedAt: daysAgo(0)),
        DayEntry(id: IDs.day2,  date: dateString(1), rating: 6, diary: "Decent day but lost focus after lunch. Skipped workout. Need to get back on track tomorrow.", tags: ["health"], createdAt: daysAgo(1), updatedAt: daysAgo(1)),
        DayEntry(id: IDs.day3,  date: dateString(2), rating: 9, diary: "One of the best days in a while. Morning meditation was deep. Crushed the reading goal. Great conversation with a friend.", tags: ["mindset", "productive"], createdAt: daysAgo(2), updatedAt: daysAgo(2)),
        DayEntry(id: IDs.day4,  date: dateString(3), rating: 4, diary: "Rough day. Didn't sleep well, felt groggy. Only managed the basics. That's okay — rest is productive too.", tags: ["stress"], createdAt: daysAgo(3), updatedAt: daysAgo(3)),
        DayEntry(id: IDs.day5,  date: dateString(4), rating: 7, diary: "Solid day. Meal prep done for the week. Read 40 pages. Evening walk was refreshing.", tags: ["health", "productive"], createdAt: daysAgo(4), updatedAt: daysAgo(4)),
        DayEntry(id: IDs.day6,  date: dateString(5), rating: 5, diary: "Average. Work was stressful. Managed to meditate and journal but skipped exercise.", tags: ["stress"], createdAt: daysAgo(5), updatedAt: daysAgo(5)),
        DayEntry(id: IDs.day7,  date: dateString(6), rating: 8, diary: "Great workout. Cold shower streak continues. Weekly review helped me refocus priorities.", tags: ["health", "mindset"], createdAt: daysAgo(6), updatedAt: daysAgo(6)),
        DayEntry(id: IDs.day8,  date: dateString(7), rating: 3, diary: "Burnout day. Took it easy. Recovery mode activated. Just did stretching and early bed.", tags: ["stress", "wellness"], createdAt: daysAgo(7), updatedAt: daysAgo(7)),
        DayEntry(id: IDs.day9,  date: dateString(8), rating: 7, diary: "Bounced back. Morning routine on point. Deep work block was focused.", tags: ["productive"], createdAt: daysAgo(8), updatedAt: daysAgo(8)),
        DayEntry(id: IDs.day10, date: dateString(9), rating: 6, diary: "Fine day. Nothing special but hit the basics. Consistency counts.", tags: ["wellness"], createdAt: daysAgo(9), updatedAt: daysAgo(9)),
    ]

    // MARK: - Schedule Rules

    static let scheduleRules: [ScheduleRule] = [
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000001")!, directiveId: IDs.dirMeditate,  ruleType: .weekly, params: ["days": [1,2,3,4,5,6,7]], createdAt: daysAgo(60)),
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000002")!, directiveId: IDs.dirExercise,  ruleType: .weekly, params: ["days": [1,3,5]], createdAt: daysAgo(55)),
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000003")!, directiveId: IDs.dirRead30,    ruleType: .weekly, params: ["days": [1,2,3,4,5]], createdAt: daysAgo(30)),
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000004")!, directiveId: IDs.dirMealPrep,  ruleType: .weekly, params: ["days": [7]], createdAt: daysAgo(35)),
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000005")!, directiveId: IDs.dirReview,    ruleType: .weekly, params: ["days": [7]], createdAt: daysAgo(30)),
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000006")!, directiveId: IDs.dirJournal,   ruleType: .weekly, params: ["days": [1,2,3,4,5,6,7]], createdAt: daysAgo(20)),
        ScheduleRule(id: UUID(uuidString: "00000006-0006-0006-0006-000000000007")!, directiveId: IDs.dirHydrate,   ruleType: .weekly, params: ["days": [1,2,3,4,5,6,7]], createdAt: daysAgo(50)),
    ]

    // MARK: - Schedule Instances (today)

    static let scheduleInstances: [ScheduleInstance] = [
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000001")!, directiveId: IDs.dirMeditate, date: dateString(0), status: .done),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000002")!, directiveId: IDs.dirHydrate,  date: dateString(0), status: .pending),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000003")!, directiveId: IDs.dirExercise, date: dateString(0), status: .pending),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000004")!, directiveId: IDs.dirRead30,   date: dateString(0), status: .pending),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000005")!, directiveId: IDs.dirJournal,  date: dateString(0), status: .pending),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000006")!, directiveId: IDs.dirStretch,  date: dateString(0), status: .done),

        // Yesterday
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000007")!, directiveId: IDs.dirMeditate, date: dateString(1), status: .done),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000008")!, directiveId: IDs.dirHydrate,  date: dateString(1), status: .done),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-000000000009")!, directiveId: IDs.dirExercise, date: dateString(1), status: .skipped),
        ScheduleInstance(id: UUID(uuidString: "00000007-0007-0007-0007-00000000000A")!, directiveId: IDs.dirJournal,  date: dateString(1), status: .done),
    ]

    // MARK: - Directive History

    static let directiveHistory: [DirectiveHistory] = [
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000001")!, directiveId: IDs.dirMeditate, action: .create, payload: "{}", createdAt: daysAgo(60)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000002")!, directiveId: IDs.dirMeditate, action: .balloonPump, payload: "{\"resetTo\": 86400}", createdAt: daysAgo(1)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000003")!, directiveId: IDs.dirExercise, action: .create, payload: "{}", createdAt: daysAgo(60)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000004")!, directiveId: IDs.dirExercise, action: .update, payload: "{\"field\": \"body\", \"old\": \"Run 30 min\", \"new\": \"Alternate: strength / cardio / yoga\"}", createdAt: daysAgo(20)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000005")!, directiveId: IDs.dirNoPhone, action: .graduate, payload: "{\"from\": \"active\", \"to\": \"maintained\"}", createdAt: daysAgo(15)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000006")!, directiveId: IDs.dirVocab, action: .update, payload: "{\"field\": \"status\", \"old\": \"active\", \"new\": \"retired\"}", createdAt: daysAgo(20)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000007")!, directiveId: IDs.dirColdShower, action: .snooze, payload: "{\"until\": \"2 days from now\"}", createdAt: daysAgo(4)),
        DirectiveHistory(id: UUID(uuidString: "00000008-0008-0008-0008-000000000008")!, directiveId: IDs.dirDeepWork, action: .balloonPump, payload: "{\"resetTo\": 28800}", createdAt: daysAgo(0)),
    ]

    // MARK: - Composed View Data

    static var noteListItems: [NoteListItem] {
        notes.map { note in
            let count = noteDirectives.filter { $0.noteId == note.id }.count
            let folderName = folders.first { $0.id == note.folderId }?.name
            return NoteListItem(note: note, directiveCount: count, folderName: folderName)
        }
    }

    static var directiveRowData: [DirectiveRowData] {
        let today = dateString(0)
        return directives.map { dir in
            let todayInstance = scheduleInstances.first { $0.directiveId == dir.id && $0.date == today }
            return DirectiveRowData(
                directive: dir,
                scheduledToday: todayInstance != nil,
                instanceStatus: todayInstance?.status
            )
        }
    }

    static var activeDirectiveRowData: [DirectiveRowData] {
        directiveRowData.filter { $0.directive.status == .active }
    }

    static var focusSnapshot: FocusSnapshot {
        let modes = notes.filter { $0.kind == .mode }
        let balloons = directiveRowData
            .filter { $0.directive.balloonEnabled && $0.directive.status == .active }
            .sorted { $0.directive.balloonRemainingSec < $1.directive.balloonRemainingSec }
        let today = dateString(0)
        let todayRows = scheduleInstances
            .filter { $0.date == today }
            .compactMap { inst -> ScheduleInstanceRow? in
                guard let dir = directives.first(where: { $0.id == inst.directiveId }) else { return nil }
                return ScheduleInstanceRow(instance: inst, directiveTitle: dir.title)
            }
        return FocusSnapshot(
            activeModes: Array(modes.prefix(3)),
            urgentBalloons: Array(balloons.prefix(5)),
            todaySchedule: todayRows
        )
    }

    static var dayEntrySummaries: [DayEntrySummary] {
        dayEntries.map { entry in
            let preview = String(entry.diary.prefix(100))
            return DayEntrySummary(entry: entry, tagNames: entry.tags, diaryPreview: preview)
        }
    }

    static var playbookListItems: [PlaybookListItem] {
        folders.map { folder in
            let noteIds = notes.filter { $0.folderId == folder.id }.map(\.id)
            let dirCount = noteDirectives.filter { noteIds.contains($0.noteId) }.count
            return PlaybookListItem(folder: folder, noteCount: noteIds.count, directiveCount: dirCount)
        }
    }

    /// Directives linked to a specific note.
    static func directives(forNoteId noteId: UUID) -> [DirectiveRowData] {
        let linkedIds = noteDirectives
            .filter { $0.noteId == noteId }
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.directiveId)
        let today = dateString(0)
        return linkedIds.compactMap { dirId in
            guard let dir = directives.first(where: { $0.id == dirId }) else { return nil }
            let todayInstance = scheduleInstances.first { $0.directiveId == dirId && $0.date == today }
            return DirectiveRowData(directive: dir, scheduledToday: todayInstance != nil, instanceStatus: todayInstance?.status)
        }
    }

    /// Notes belonging to a specific folder.
    static func notes(forFolderId folderId: UUID) -> [NoteListItem] {
        noteListItems.filter { $0.note.folderId == folderId }
    }

    /// History for a specific directive.
    static func history(forDirectiveId directiveId: UUID) -> [DirectiveHistory] {
        directiveHistory
            .filter { $0.directiveId == directiveId }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
