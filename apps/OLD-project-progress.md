<!-- @Daily Check-In App - Name

# Project Spec — “Daily Check-In” iOS App (SwiftUI, Local-First)

## 0) One-paragraph pitch

A private, local-first iOS app where you rate how you’re feeling (e.g., **Anxiety**, **Brain Fog**, etc.), and it instantly builds a **Curated Daily Note** from your own interventions/notes. Some items always show (“Every day”), while additional items appear based on today’s severity. You can freely browse/edit your full notes. The **Home** screen also has a **Situations** carousel (e.g., “Giving a presentation”) with quick search; tapping a situation opens the connected note(s).

---

## 1) Goals & non-goals

**Goals**

* Frictionless daily check-in (sliders → curated recommendations).
* Editable notes with **basic formatting** (bold, italics, lists, color spans).
* Always-show (“Every day”) interventions + severity-gated ones.
* Per-day save & auto-reset the next calendar day.
* Sidebar to browse & edit all topics and free notes any time.
* Situations carousel + search to jump to context-specific notes.
* 100% offline; all data on device (SwiftData).

**Non-goals (v1)**

* Cloud sync, accounts, or backend.
* Push reminders/notifications (nice-to-have v1.1).
* Multimedia attachments (images/audio) in notes (v2+).

---

## 2) Platforms & tech

* **iOS 26+**, **Swift 5.9+**
* **SwiftUI** UI, **SwiftData** persistence
* Optional: **MarkdownUI** for rendering; otherwise minimal Markdown renderer
* Unit tests with **XCTest**

---

## 3) Core entities (SwiftData models)

```swift
@Model
final class Trackable { // A slider on Home
    @Attribute(.unique) var id: String
    var name: String
    var min: Int = 0
    var max: Int = 10
    var defaultValue: Int = 3
    var order: Int = 0
    var colorName: String = "gray"
    init(id: String = UUID().uuidString, name: String) { self.id = id; self.name = name }
}

@Model
final class Folder { // Nested folder hierarchy for notes
    @Attribute(.unique) var id: String
    var name: String
    var parentId: String? // nil = root folder
    var order: Int = 0    // manual sort
    init(id: String = UUID().uuidString, name: String, parentId: String? = nil) {
        self.id = id; self.name = name; self.parentId = parentId
    }
}

@Model
final class NotePage { // Unified note (was Topic & FreeNote)
    @Attribute(.unique) var id: String
    var title: String
    var bodyMarkdown: String = ""
    var trackableId: String? // optional slider link (e.g. Anxiety)
    var interventions: [Intervention] = []
    var folderId: String?    // parent folder
    var isSystem: Bool = false // non-deletable core pages
}

@Model
final class Intervention { // Ranked, severity-gated item inside a page
    @Attribute(.unique) var id: String
    var pageId: String
    var title: String
    var detailsMarkdown: String = ""
    var minSeverity: Int = 0
    var maxSeverity: Int = 10
    var priority: Int = 0
    var isEveryDay: Bool = false
    var tagsCSV: String = ""
    init(id: String = UUID().uuidString, pageId: String, title: String) {
        self.id = id; self.pageId = pageId; self.title = title
    }
}

@Model
final class Situation { // Context bubbles on Home
    @Attribute(.unique) var id: String
    var title: String
    var iconSystemName: String = "circle.fill"
    var colorName: String = "blue"
    var pageIds: [String] = [] // linked NotePages
}

@Model
final class DailyCuratedNote { // Saved per calendar day
    @Attribute(.unique) var id: String // yyyy-MM-dd
    var date: Date
    var metricLevels: [String:Int]
    var interventionIDs: [String]
}
```

**Formatting spec for Markdown fields**

* **Bold**: `**text**`
* *Italics*: `*text*`
* Lists: `- item`
* **Color spans**: `[[color:orange]]text[[/color]]`
  Allowed names: `red, orange, yellow, green, blue, indigo, violet, gray`
  Rendering: map to `foregroundStyle(.orange)` etc.

---

## 4) Home screen spec

**Layout**

* **Header**: title “Daily Check-In” and Today (e.g., “Sun, Nov 2”).
* **Sliders section** (dynamic):

  * One slider per `Trackable` ordered by `order`.
  * Display current value; slider snap to 0…10 ints.
* **Recommended today**:

  * Button: **Generate / Regenerate Curated Note**
  * After generation, show preview list (top 3 items with “Open Today’s Curated Note”).
* **Situations** (bottom area):

  * Horizontal **carousel** of situation bubbles (SF Symbol + title, tinted by `colorName`).
  * Leading item: **Search field** (“Search situations…”).
  * Tap a bubble → **Situation Detail** which lists connected notes (FreeNote and/or Topic) and opens them.

**Behavior**

* On launch or on first entry to Home:

  * If `DailyCuratedNote` for **today** exists → use it (show preview, values prefilled).
  * Else → prefill sliders with `defaultValue`s and wait for user to tap **Generate**.
* **Generate/Regenerate**:

  * Runs curation (see §6), updates/creates today’s `DailyCuratedNote`. No duplicates (same id).
* **Auto-reset**:

  * Next calendar day → there is no record yet; user generates anew.

---

## 5) Navigation & IA

* **NavigationSplitView** (iPad & large iPhone landscape) / NavigationStack on phones:

  * **Sidebar**:

    * **Home**
    * **Topics** (list of NoteTopic, with trackable badge if linked)
    * **Free Notes**
    * **Situations**
    * **History** (by date; tapping opens that day’s curated set)
    * **Settings** (theme, color preview, import/export)
* **Detail panes**:

  * **HomeView**
  * **TopicDetailView** (editable bodyMarkdown; segmented: *All • Today’s Level • Pinned*)
  * **InterventionDetailView** (edit title, detailsMarkdown, severity range, priority, isEveryDay)
  * **FreeNoteDetailView** (edit)
  * **SituationDetailView** (shows connected notes with quick open)
  * **CuratedNoteView** (ordered list; tapping items opens live Intervention detail)
  * **HistoryDayView** (same as CuratedNoteView but readonly or “Recreate as Today”)

---

## 6) Curation algorithm

**Inputs**

* `values`: map of `Trackable.id → Int`
* `topics`: all NoteTopic
* `interventions`: all Intervention

**Rules**

1. **Always include** interventions where `isEveryDay == true`.
2. Compute **allLow** = all slider values ≤ 3.

   * If `allLow == true`: include **basic** items (those whose `maxSeverity ≤ 3`) **for each trackable’s topic**.
   * Else:

     * Pick **primary** = the trackable with the highest value (ties: first by order).
     * Include **all** items in the primary topic whose severity range includes its value.
     * For all other trackables: include their **basic** items (maxSeverity ≤ 3).
3. **Sort** chosen set by `(isEveryDay desc, priority desc, title asc)` and store **IDs** in `DailyCuratedNote`.

**Note:** Because the curated record stores **IDs**, edits to interventions update today’s curated view live. If later you want a “freeze content” toggle, store a rendered snapshot alongside IDs.

---

## 7) Situations system

**Purpose**
Quick, context-based entry points (e.g., “Giving a presentation”, “Driving”, “Before bed”).

**Data**

* `Situation` with:

  * `title`, `iconSystemName`, `colorName`
  * `freeNoteIds`: connects to **FreeNote** pages
  * `topicIds`: connects to **NoteTopic** pages

**UI**

* Home bottom **carousel** + search.
* **SituationDetailView**:

  * Shows **linked topics** (tap to open TopicDetail with optional “Filter by Today’s Level” toggle).
  * Shows **linked free notes** (tap to open note).
  * “Add connection” button (pick from Notes/Topics).

**Editing**

* Add/create situations in Situations tab, set icon/color, link notes/topics.

---

## 8) Editing & formatting

**Editors**

* **Topic editor**: title, bodyMarkdown, trackable link picker (or none), preview toggle.
* **Intervention editor**: title, detailsMarkdown (Markdown + color spans), min/max severity (steppers), priority (stepper), Every day (toggle), tags (comma CSV).
* **Free note editor**: title, bodyMarkdown, tags.

**Markdown rendering**

* Bold, italics, lists → render with MarkdownUI or minimal parser.
* Color spans parser (simple state machine) → convert `[[color:NAME]]...[[/color]]` to `Text(...).foregroundStyle(themeColor(NAME))`.

---

## 9) Settings & theming

* **Theme color previews** per `colorName`.
* Toggle: “Prefer large text” (also rely on Dynamic Type).
* Import/Export (v1.1): JSON backup of all SwiftData entities.

---

## 10) Accessibility & UX polish

* Full **Dynamic Type** support; avoid fixed sizes.
* High contrast colors for chips and situation bubbles.
* VoiceOver labels: include severity and priority where relevant (e.g., “Physiological Sigh, Every day, priority 100”).
* Haptics: light success when generating curated note.

---

## 11) Error & edge cases

* Missing links (e.g., Situation linked to deleted note) → show placeholder and “Fix link”.
* Empty state: no interventions match → show message and button “View topic to add items”.
* Data migrations: SwiftData model versioning v1 → v2 (future: add attachments) with lightweight migration plan.

---

## 12) Performance

* Entities are small; default SwiftData fetches.
* Precompute “basic” subsets per topic on app start; cache in memory (invalidate on edit).
* Use `@Query` filters for Topic → Interventions.

---

## 13) File/Module structure

```
App/
  DailyCheckInApp.swift

Core/
  Models/ (Trackable.swift, Folder.swift, NotePage.swift, Intervention.swift, Situation.swift, DailyCuratedNote.swift)
  Persistence/ (SeedData.swift, Backups.swift)
  Logic/
    CurationEngine.swift
    ColorSpanParser.swift
    DateUtils.swift

UI/
  Home/
    HomeView.swift
    SlidersSection.swift
    SituationsCarousel.swift
  Curated/
    CuratedNoteView.swift
  Notes/
    NotesListView.swift
    NotePageDetailView.swift
    InterventionEditorView.swift
    FolderTreeView.swift
    BreadcrumbView.swift
  Situations/
    SituationsListView.swift
    SituationDetailView.swift
    SituationEditorView.swift
  History/
    HistoryListView.swift
    HistoryDayView.swift
  Common/
    TagBubble.swift
    SeveritySlider.swift
    MarkdownText.swift

Settings/
  SettingsView.swift
```

---

## 14) Key algorithms (pseudo)

**Curation**

```swift
func curatedIDsForToday(trackables: [Trackable],
                        values: [String:Int],
                        topics: [NoteTopic],
                        ints: [Intervention]) -> [String] {
    var chosen = Set(ints.filter{$0.isEveryDay}.map{$0.id})
    let allLow = values.values.allSatisfy{ $0 <= 3 }

    func topicIds(for trackableId: String) -> [String] { topics.filter{$0.trackableId == trackableId}.map{$0.id} }
    func items(for trackableId: String, level: Int) -> [Intervention] {
        let tids = Set(topicIds(for: trackableId))
        return ints.filter { tids.contains($0.topicId) && level >= $0.minSeverity && level <= $0.maxSeverity }
    }
    func basicItems(for trackableId: String) -> [Intervention] {
        let tids = Set(topicIds(for: trackableId))
        return ints.filter { tids.contains($0.topicId) && $0.maxSeverity <= 3 }
    }

    if allLow {
        for t in trackables { chosen.formUnion(basicItems(for: t.id).map{$0.id}) }
    } else if let (primaryId, primaryLevel) = values.max(by: {$0.value < $1.value}) {
        chosen.formUnion(items(for: primaryId, level: primaryLevel).map{$0.id})
        for t in trackables where t.id != primaryId {
            chosen.formUnion(basicItems(for: t.id).map{$0.id})
        }
    }

    let byId = Dictionary(uniqueKeysWithValues: ints.map{ ($0.id, $0) })
    return chosen.compactMap{ byId[$0] }
                 .sorted { ($0.isEveryDay, $0.priority, $0.title) > ($1.isEveryDay, $1.priority, $1.title) }
                 .map{ $0.id }
}
```

**Color span parsing**

* Token: `[[color:NAME]]` opens span; `[[/color]]` closes.
* Validate allowed names; unmatched close just ignored.
* Fallback to body text if nested/invalid.

---

## 15) Seeding & import

* On first run, seed:

  * Trackables: **Anxiety** (orange), **Brain Fog** (indigo)
  * Topics bound to each
  * A few interventions across severity bands (+ “Every day”)
  * A couple of **Situations** (e.g., “Giving a presentation” → links to Anxiety topic + FreeNote “Presentation checklist”)
* **Share Extension** (v1.1): accept text from Apple Notes; user picks Topic or Free Note; optional auto-split by headings into Interventions.

---

## 16) Acceptance criteria (MVP)

* **Home** shows dynamic sliders for all Trackables; values persist while apprunning.
* Tapping **Generate Curated Note** creates/updates **today**’s `DailyCuratedNote`, with:

  * Always the “Every day” items
  * Basic items for all topics when all sliders ≤ 3
  * Else: full set for the highest slider’s topic + basic for others
  * Ordered by (Every day, priority)
* **CuratedNoteView** displays items; tapping opens live Intervention.
* **Topics** list and **TopicDetail** allow full edit (body markdown, interventions add/edit/delete, reorder, ranges, priority, every-day).
* **Free Notes** list & detail: edit markdown.
* **Situations** carousel + search on Home; tapping shows connected notes; can open them.
* **History** shows prior days; can open read-only curated sets.
* **Formatting** renders bold/italics/lists + color spans.

---

## 17) Testing plan

* **Unit**

  * Curation logic: allLow true/false; equal highest; priorities; every-day inclusion.
  * Color parser: valid/invalid spans; nested handling; allowed names only.
  * Date id generation & startOfDay correctness.
* **UI**

  * Snapshot tests for Home/Curated/TopicDetail with sample data.
* **Integration**

  * Create/edit interventions → curated view updates without app restart.
  * Deleting linked notes from a Situation shows “Fix link” affordance.

---

## 18) Milestones

**M1 – Foundations (3–4 days)**

* Models, seed data, basic Home with sliders, Topics list/detail.
* Curation engine + CuratedNoteView (manual trigger).

**M2 – Editing (3–4 days)**

* Intervention editor (ranges, priority, every-day).
* Reorder support; Markdown render + color spans.

**M3 – Situations & History (2–3 days)**

* Situations data + carousel + search; detail view.
* History list + open prior day.

**M4 – Polish (2–3 days)**

* Accessibility, haptics, empty states, settings (color preview).

---

## 19) Handoff notes for the developer

* Target **iOS 26**; app named “Daily Check-In”.
* Feature flags via simple `AppConfig` struct (e.g., `useMarkdownUI`).
* Keep the curated record **IDs-based** (live) for v1; if you later need “freeze snapshot”, add an optional `renderedMarkdown` field.
* Avoid heavy dependencies; if using MarkdownUI, add via SPM.
* Ensure SwiftData model versioning is set (Schema V1).

---

If you want, I can also generate a **starter Xcode project** with the models, seed data, Home view, curation engine, the Situations carousel, and placeholder editors wired up to match this spec so your dev can run and iterate immediately.

### Progress Log (updated Nov 3 2025)

- **Core models** complete (no change).
- **SeedData** unchanged.

- **Logic / Utilities**
  - Added `ColorSpanParser` for custom color spans.
  - Added `DateUtils.todayID()` & `startOfToday()` helpers.

- **UI Enhancements**
  - Created reusable `MarkdownText` component; integrated into Topic, Free Note, Intervention editors and Curated view.
  - Added colored priority badges with numeric overlay to curated items; hue from purple→green.
  - `CuratedNoteView` & `HistoryDayView` now support Flat vs Grouped-by-Topic layouts via segmented picker.
  - SituationDetailView fully implemented: shows linked topics/notes and link-picker sheet.
  - History list opens dedicated read-only day view with “Recreate as Today.”
  - Intervention editor:
    * New severity mode picker (≤, =, ≥) with colored slider.
    * Priority slider colored green→red with Low/Medium/High/Critical label.
    * Details editor simplified (removed live preview duplicating text).
  - Topic detail intervention rows display metadata (Every day, severity, priority) with icons.
  - AppShell sidebar navigation fixed; buttons now work.
  - Generate Curated Note uses NavigationPath to push today’s note view.

- **Visual polish**
  - Colored sliders & badges; accessibility labels added.
  - UI explanatory captions added for severity & priority controls.

Project builds cleanly with new features; next focus: accessibility sweep, empty-state views, theme previews. -->
