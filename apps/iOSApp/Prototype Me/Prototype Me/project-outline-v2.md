## Full outline (updated with offline-first sync, Postgres backend, native iOS-first, and “fun but clean” UI)

### 1) Core app structure (foundation)

* **Notes (NotePages)** = containers for content.
* **Directives** are global items that can be **linked into multiple notes**.
  * A note stores its directive list via a join (`NoteDirective`) for ordering + per-note display.
  * A directive can appear **at most once per note** (no duplicates in the same note).
  * Unlinking a directive from a note **does not delete** the directive itself.
* **Balloons** = a **feature on a directive** (timer/pressure toggle + duration + remaining time).
  * Balloons track urgency/decay; they do **not** control schedule or visibility rules.
* **Balloons tab** = filtered view of directives where `balloonEnabled == true`.
  * Excludes deleted/retired directives by default (configurable later).
* **Directive-first mechanics**: learning/habit features attach to directives, regardless of surface (notes, playbooks, balloons).
  * Example: a “shrink” action always mutates the directive, not the note container.
* **DirectiveHistory** = append-only audit log for every directive mutation.
  * Tracks: `id`, `directiveId`, `action`, `payload`, `createdAt`, `deviceId`.
  * Used for: undo, analytics, AI context, and audit trail.
  * Add from day one — much harder to retrofit later.
* **ID strategy**: all entities use **UUIDv7** (or ULID) for IDs.
  * Sortable by creation time, avoids sync collisions, safe for offline creation.
  * Applies to: notes, directives, dayEntries, playbooks, outboxOps, etc.
* **`updatedByDeviceId`**: all mutable entities include `updatedAt` + `updatedByDeviceId` fields.
  * Required for deterministic LWW conflict resolution — without device ID, timestamp ties are ambiguous.
* **`version` column**: all mutable entities include a monotonic `version: Int` field.
  * Incremented on every mutation. Sync conflict resolution uses highest version wins.
  * Eliminates timestamp-tie ambiguity when two devices edit at the same second.
  * Tables: `NotePage`, `Directive`, `DayEntry`, `Playbook`, `ScheduleRule`, `ScheduleInstance`, `UserSignal`.
* **`metadata` JSONB column**: all core entities include an optional `metadata: JSON` field.
  * Used for: experimentation, AI flags, new features, temporary migrations, A/B tests.
  * Avoids creating new migrations for every small addition.
* **`DirectiveStatus` enum**: define once, use everywhere: `active | maintained | retired`.
  * Referenced by directive graduation, filters, balloon tab exclusions, and sync.

---

### 2) Product thesis

* Problem: **humans can’t hold everything they care about in working memory**.
* Notes = long-term storage.
* Balloons + curated surfaces = **working-memory / attention management**.
* App = “life OS”: **capture → organize → surface → act** without overwhelm.
* Primary loop: capture input → route to note/directive → surface at the right time → quick action → reflect.

---

### 3) Platforms & architecture direction

* **iOS-first** via native **Swift / UIKit**. Android later (Kotlin) if iOS proves out.
* Remains **offline-first**:

  * fully usable without internet
  * local data is the immediate source of truth
  * sync happens opportunistically in the background
* Local persistence uses **GRDB** (Swift SQLite toolkit) for full control over sync queries, outbox, tombstones, and migrations.
* Network is treated as **eventual consistency**, not required for core flows.
* Backend storage uses **Postgres** as the system of record.

**Cross-platform type sharing (OpenAPI)**

* An **OpenAPI spec** (`packages/api-spec/openapi.yaml`) is the single source of truth for all API types and endpoints.
* Codegen produces matching types for each platform:
  * **Swift** → Apple's `swift-openapi-generator` → `Codable` structs
  * **TypeScript** → `openapi-typescript` → backend request/response types
  * **Kotlin** (future) → OpenAPI Generator → data classes
* Changing a model in the spec and re-running codegen keeps every platform in sync.
* This replaces the shared `packages/types/` TypeScript package from the React Native plan.
* **API versioning**: all requests include an `X-API-Version` header. Prevents older clients from breaking when endpoints evolve.

**GRDB migration rules**

* Always **forward-only** migrations. Never rewrite or edit old migrations.
* Example: `v1_create_tables`, `v2_add_directive_status`, `v3_add_user_signal`, `v4_add_schedule`.
* This prevents corruption on devices that haven't updated yet.

---

### 4) Offline-first sync (multi-device)

**User experience**

* Make changes locally anytime (offline or online).
* When online:

  * app **pushes** local pending changes to backend
  * app **pulls** remote changes made on other devices (e.g., iPad catching up)

**Core mechanics**

* **Local DB** stores everything (notes, directives, balloons, playbooks, etc.).
* **Outbox queue** records changes as operations (create/update/delete) to be uploaded when possible.
* **Pull cursor** (`last_sync_token`) to fetch incremental updates from the server.
* **Tombstone table** for deletions (sync deletions reliably).
  * Separate `Tombstone` table: `id`, `entityType`, `entityId`, `deletedAt`, `updatedAt`, `deviceId`.
  * Includes `updatedAt` for deterministic ordering when update + delete collide during sync.
  * Keeps main tables clean (no `deletedAt` on every entity).
  * Simpler sync logic — query one table for all pending deletes.
* **Conflict strategy (pragmatic)**

  * last-write-wins for small fields (balloon flags/durations/priority/etc.)
  * for large text bodies (notes), if both edited: keep one + store a **conflict copy** with a “Resolve” UI

**Sync lifecycle**

* Push triggers: app foreground, background interval, or manual sync.
* Pull occurs after a successful push or on a timed interval.
* Outbox is processed **in order**; each op is idempotent on the server.
* Retry with exponential backoff on network errors; keep last error for debugging.
* Server response includes updated records + new cursor token.
* Deletes are soft until server ack, then eligible for local compaction.

**Background sync strategy (iOS)**

* Triggers: app foreground, `BGAppRefreshTask` periodic fetch, manual pull-to-refresh, after successful push.
* iOS background time is limited — always **push first, then pull** to maximize data safety.
* Register background tasks early in app lifecycle.

**Sync batching**

* Pull endpoint must page changes: `GET /sync/pull?cursor=abc&limit=200`.
* Response: `changes[]` + `nextCursor` + `hasMore`.
* Never return unlimited change sets.

**Tombstone compaction**

* Server job: delete tombstones older than 30 days after server confirmation.
* Client: compact local tombstones after server ack.

**Sync metadata tables**

* **`SyncState`**: `lastSyncToken`, `lastPushAt`, `lastPullAt`, `deviceId`.
  * Single row table — keeps sync cursor and timing in one clean place.
* **`Device`**: `id`, `name`, `platform`, `createdAt`, `lastSeenAt`.
  * Helps debug multi-device sync issues (“which device wrote this?”).
  * Registered on first launch; `lastSeenAt` updated on each sync.

**Ops / debugging**

* Add a “Sync Debug” screen (outbox size, last push/pull, last error, last cursor, registered devices).

**Backend**

* Postgres as primary DB.
* Sync endpoints:

  * `push` (submit outbox ops)
  * `pull` (fetch changes since cursor)

**Push details**

* Client sends ordered `OutboxOp[]` with `deviceId` and last known `lastSyncToken`.
* Each `OutboxOp` includes a `schemaVersion` field to prevent decoding errors when old queued ops replay after an app update.
* Server applies ops idempotently (by `op.id`), updates records, returns applied results.
* Response includes updated records and a new `lastSyncToken`.

**Pull details**

* Client requests changes since `lastSyncToken`.
* Server returns a bounded page of `ChangeEvent[]` + `nextToken`.
* **`ChangeEvent` structure**: `entityType`, `entityId`, `operation` (create/update/delete), `payload`, `version`, `updatedAt`, `updatedByDeviceId`.
  * Universal abstraction — sync pipeline doesn't need entity-specific logic.
  * Same pattern used by Linear, Notion, and Figma.
* Client applies changes in order, updates local records, then advances token.

**Conflict resolution**

* For simple fields, **version-based resolution**: highest `version` wins; `(updatedAt, updatedByDeviceId)` as tiebreaker.
* For note bodies, concurrent edits create a conflict copy for manual resolve.

**Idempotency + safety**

* `OutboxOp.id` prevents duplicate application on retries.
* Server rejects ops with stale `baseUpdatedAt` only when necessary (optional strict mode).
* Local deletes remain tombstoned until server ack.

**Database indexes (GRDB + Postgres)**

* Add indexes for common query patterns from day one:
  * `Directive`: `balloonEnabled`, `updatedAt`, `status`
  * `NoteDirective`: `noteId`, `directiveId`
  * `ScheduleRule`: `nextRun`
  * `OutboxOp`: `createdAt` (process in order)
* GRDB handles large datasets well if indexed properly.

---

### 5) AI role (boundary + UX)

* AI is mainly **input + drafting + editing**, not a constantly-on coach.
* Triggered by user action (button → voice/chat view).
* Optional: **once-per-day** draft batch that creates suggestions (still requires approval).
* **Rule:** AI proposes; user approves. No silent commits.
* AI cannot delete or edit without a visible draft and explicit confirm.
* AI suggestions are scoped to user-owned data; no cross-user data mixing.

---

### 6) AI chat UX: “Directive chips” (primary AI feature)

After voice input, assistant returns tappable chips:

* **Add to Journal** (clean entry + optional day rating + extracted highlights)
* **Create Directive** (with suggested destination note)
* **Create Directive + Balloon** (suggested duration/urgency)
* **Append to Existing Note**
* **Link to Situation / Create Situation**
* **Convert to If–Then plan** (cue → action → fallback)
* **Shrink / Split directive** (tiny version, 3-step breakdown, checklist)
* **Active recall check** (ask for cue/steps before showing the answer)
* **Identity reframing** (“I’m the kind of person who…” rewrite)
* **One-line rule summary** (cue → action → benefit)
  Each chip shows:
* what will be created/changed
* where it will go
* why it was suggested
  User taps to accept; otherwise nothing changes.
* Chips are **single-action** (one change each) unless explicitly marked as a bundle.
* Accepting a chip opens a quick edit/confirm screen before commit.

---

### 7) Background “knobs” (latent state + tuning signals)

Voice/journal input updates **internal values** that improve routing and suggestions. These do not auto-change the user’s system; they’re used to propose better drafts and surfacing.
* Knobs are **non-user-visible by default**, but can be inspected or reset later.
* Knob updates are local-first and can be synced as lightweight state.

**Knobs/signals examples**

* **Theme frequency** (sleep, anxiety, confidence, avoidance, etc.)
* **Per-note / per-directive relevance**

  * “mentioned lately” score
  * “associated with stress” score
  * “associated with wins” score
* **Behavioral preference signals**

  * prefers tiny actions vs deep plans
  * suppresses certain suggestion types
  * engages with certain modes/playbooks

**Uses**

* Better auto-routing (“where should this directive go?”)
* Better playbook suggestions (Lite vs Standard vs Deep)
* Better balloon tuning drafts (cadence, duration, pressure)
* Better “Active Modes” recommendations (“this keeps recurring—make it active”)

**Storage**

* **`UserSignal`** table: `key`, `value` (numeric), `updatedAt`.
  * Examples: `theme.sleep = 0.7`, `directive.abc.relevance = 0.4`, `pref.tiny_actions = 0.8`.
  * Avoids schema churn — new signal types don't require migrations.
  * Synced as lightweight key-value pairs.

**Transparency**

* Optional “Why” popover for any suggestion.

---

### 8) AI across the app: “Simplify / Refactor” affordances

When content becomes large or unwieldy, the UI offers calm, optional AI tools.
* Triggered by explicit user action or soft nudges at thresholds (length, number of directives).
* Never auto-rewrites; always draft + confirm.

**Examples**

* If a note is getting long:

  * **Simplify / Organize**
  * group into sections, merge duplicates, extract top 5 “keep alive,” convert some to a Mode
* If a directive is too big/unclear:

  * **Shrink**, **Split**, **Rewrite**
* “This is a lot to hold” hint → offer a **shortlist for today**

All changes remain draft/confirm.

---

### 9) Tuning suggestions (execution-focused, draft-only)

* Balloon tuning drafts:

  * repeatedly pumped → shrink/split or change cadence
  * consistently ignored → de-emphasize/archive/convert cadence
  * too many ballooned directives → propose a cap + shortlist
* “Stuck” diagnostics:

  * too big / forgot / unclear / wrong timing / not important → suggest one fix
* **Skipped repeatedly** → propose tiny-step fallback or micro version
* **Stable adherence** → suggest a small difficulty bump (desirable difficulty)
* **Surface rotation** → interleave items to reduce serial-position bias
* **Variable reinforcement** → occasional surprise wins summary (draft-only)
* Suggestions appear after repeated signals (e.g., 3+ ignores, 5+ pumps).
* User can dismiss a suggestion type; dismissed types are suppressed.

---

### 10) Playbooks/templates (Option A: tagged folders of notes)

**Definition**

* **Playbook = a tagged Folder** containing a set of **NotePages**, each with **Directives** (some balloon-enabled).
* Used for personal organization and as the unit of community sharing.
* A note can belong to **one** playbook folder at a time (via folderId).
* Directives can be linked across notes even if notes are in different playbooks.

**Playbook intent (optional, lightweight)**

* `intent: general | learning | execution | maintenance` (default: `general`).
* Intent is a **soft label**, not a new surface. It unlocks small defaults/affordances, never a separate tab.
* Example affordances:
  * **learning**: progress bar + “Next up” section (based on directive status + sortIndex)
  * **execution**: “Today’s focus” shortlist + quick mark/snooze
  * **maintenance**: reminder-heavy view + gentle cadence nudges

**AI behavior**

* When user mentions a struggle/goal:

  * suggest **Open existing related playbook/note**
  * else suggest **Create playbook from template**
* Offer **parallel variants**:

  * Lite / Standard / Deep (same idea, different intensity)

---

### 11) “GitHub-style” community playbooks (forks + versions)

**Mental model**

* Community Playbooks behave like repos:

  * browse
  * fork
  * edit locally
  * publish versions
  * others can fork your version

**Versioning approach**

* “Publish version” = create a **snapshot** of:

  * playbook folder metadata + included notes + directives (including balloon settings)
* No complex merges required.
* Publishing is explicit: user picks title, changelog, and visibility.

**Forking**

* Fork = copy playbook folder + contents into user’s local DB.
* Preserve lineage metadata:

  * origin playbook ID + origin version ID + fork parent version ID.
* Users can publish their fork as a new version line.
* Forks are local copies; edits never affect the original playbook.

**Optional “diff-lite” UI**

* On publish: “2 notes added, 5 directives edited, 3 balloon durations changed.”

---

### 12) Troubleshoot assistant (scoped AI mode, same component)

**Purpose**

* Help users personalize/repair a playbook or note when it “isn’t working.”

**UI**

* Button inside a playbook or note: **Troubleshoot / Not working?**
* Opens the same AI panel, scoped to that playbook/note.

**Loop**

* AI asks at most one question (remembering vs doing vs knowing what matters).
* Returns chips: simplify, shrink/split, adjust balloons, add cues, create a Mode, link situations, add a tiny-step fallback, or write a “why this matters” line.
* Troubleshoot is **scoped**: it can only read/edit within the selected note or playbook.
* Output is always draft + confirm.

**Community synergy**

* Import → Troubleshoot/Personalize → Use → Publish improved fork/version.

---

### 13) Two-layer improvement system: Modes/Principles → Directives

**Layer 1: Modes (compressed)**

* Short “operating instruction” (e.g., “Don’t perform,” “Stay curious,” “Make it smaller”).
* Include a one-line rule summary (cue → action → benefit) for fast recall.
* Modes are **optional** and can be created manually or via AI.

**Layer 2: Directives (expanded)**

* Specific actions under each mode (plus optional balloons).
* Optional identity framing (“I’m the kind of person who…”).
* Directives can be linked across modes/notes; the mode is just a grouping surface.

**Tiering (foundation → active)**

* Notes (and Modes) can be tagged with a **Tier** to reflect how they’re used:
  * **Foundation** = passive, always-on habits (sleep, stress, nutrition).
  * **Support** = supporting routines (prep, planning, maintenance).
  * **Active** = situational, effortful directives (“when out and about”).
* Tier is **explicit metadata**, not just a row color.
* Colors are a **visual accent mapped to Tier**, never the source of truth.
* Tier powers sorting + filters (e.g., “Show only Foundation + Support” on low-energy days).
* Tier defaults to `support` unless explicitly changed.

**Implementation**

* Mode is a special note type: `NotePage.kind = mode`
* Mode note contains: short description + directives (some marked “micro” for focus preview) + optional linked situations.
* Note metadata includes: `tier = foundation | support | active` (default: support).

**Framework note (personal constitution)**

* Single, user-designated note: `NotePage.kind = framework`.
* Treated like a normal note, but with light affordances:
  * Pinned to top of Notes and 1-tap access from the Notes list.
  * Confirm before edits (avoid accidental drift).
  * Optional weekly review reminder (not daily).
* Only one framework note is allowed at a time.

**Directive “Graduation” (hide without deleting)**

* Avoid “completed” framing for habits; use **focus states**:
  * **Active** = in the current working set (shows normally).
  * **Maintained** = stable habit; **collapsed/hidden by default** but preserved.
  * **Retired** = no longer relevant; hidden from normal views but searchable/history-safe.
* **Optional twist: Hibernation/Snooze**
  * Hide for a duration (e.g., 2 weeks / 1 month) and auto-resurface.
  * Lightweight spaced-repetition check-in: “Still true / still doing naturally?”
* **UX**
  * Primary interaction is a quick action (swipe / menu): **Graduate**, **Snooze**, **Retire**.
  * In-note display: a collapsed “Maintained” section (and optional “Retired” section behind a toggle).
  * Global access: a filter or “Archive/Hidden” view (not a primary tab unless needed).
* Graduation changes state only; it does **not** delete data.

**UX**

* Users select 1–3 **Active Modes** (today/this week).
* Focus preview appears inside the Mode note or Playbook overview, showing 1–2 micro-directives each.
* Drill down for the full set.
* Occasional recall-check cards appear before revealing details.
* Active Modes selection is capped at 3 unless user changes a setting.

---

### 14) Science-aligned features (habits + remembering)

These mechanics are embedded throughout chips, tuning, and Notes/Playbook surfaces.

* **Implementation intentions** (If–Then plans with explicit cues)
* **Spaced retrieval + active recall** (prompt before reveal; 1d/3d/7d checks)
* **Tiny/Standard/Stretch** tiers + **tiny-step fallback** after skips
* **Situation/time-window surfacing** + **habit stacking**
* **Elaboration + identity framing** (“why this matters”)
* **Desirable difficulty** (gentle increases after stability)
* **Interleaving/rotation** in note/playbook focus previews to reduce serial-position bias
* **Variable reinforcement** (occasional wins summaries)
* **Gentle streaks + recovery tracking**
* **Weekly review**: keep alive / stuck / drop / tune
* These mechanics are surfaced as optional suggestions, not mandatory flows.

---

### 15) Daily diary + day rating (calendar-first)

**Core UX**

* Each day has a **diary entry**: free text, autosave, editable anytime that day.
* Each day has a **rating 1–10** (optional).
* **Calendar view** with color-coded day cells based on rating.
* **Day detail view** shows rating + diary + quick tags (“why was this day good/bad?”).
* **Monthly summary**: averages, best/worst days, and “why” highlights from diary.
* Day boundaries follow the user’s local timezone.

**Data model**

**`DayEntry`**

* `id: uuid`
* `date: yyyy-mm-dd` (local day key; one entry per day)
* `rating: number | null` (1–10)
* `diary: string` (free text; can be empty)
* `tags: string[]` (optional quick labels)
* `createdAt`, `updatedAt`
* `deletedAt: timestamp | null`

**Notes**

* Store as a **first-class entity** (not a NotePage) to support calendar queries.
* Calendar colors are **derived from rating**, never source of truth.

---

### 16) Scheduling + resurfacing (directive cadence)

**Goal**

* Allow directives to appear on **specific days**, **weekly/monthly**, or **one-off** prompts.
* Support quick actions like “show this tomorrow” without making a full schedule.

**Examples**

* “Every Monday + Thursday”
* “1st of the month”
* “Hold → show in Daily Note tomorrow”

**Behavior**

* Scheduled directives surface in Daily Note or Focus panel.
* If skipped, they can resurface based on rule (or be snoozed).
* Scheduling is **separate from balloons** (which track urgency/decay).
* “Show tomorrow” = create a one-off schedule instance for the next local day.

**Data model (two-table approach)**

* **`ScheduleRule`**: `id`, `directiveId`, `ruleType` (weekly/monthly/one-off), `params` (JSON: days, dates, etc.), `version: Int`
* **`ScheduleInstance`**: `id`, `directiveId`, `date`, `status` (pending/done/skipped), `sourceRuleVersion: Int`
  * `sourceRuleVersion` links each instance to the rule version that generated it — rule edits can invalidate stale instances.
* Splitting rules from instances avoids recomputing schedules constantly.
* Instances are generated ahead of time (e.g., next 7–14 days) and queried by date.

---

### 17) AI onboarding + personality input (seeded setup)

* Optional onboarding flow collects **goals, preferences, and personality traits**.
* AI uses that input to **seed initial directives** + recommended playbooks.
* Users can edit/reject all suggestions; no silent writes.
* Ongoing feedback (wins/skips) tunes future suggestions.
* Onboarding can be skipped; the app still works fully without it.
* Optional “AI concierge” intro: a short, cinematic chat where users talk about goals
  and the app builds an initial setup (flashy, animated, but still skippable).
* Suggested flow:
  * Short intro slides (3–5) for value props + trust.
  * Optional AI signup chat (voice or text) to capture goals.
  * Draft seed plan preview with confirm/edit before save.
  * “Welcome” and drop into Focus.
* Visual notes (optional): subtle floating motivational chips, pulsing voice ring,
  “thinking” animation after submit, and seed cards stacking in.
* Implementation note: reuse the core AI chat logic, but use **separate UI shells**
  for onboarding vs the main in‑app AI experience.

---

### 18) Sharing + collaboration + snapshots

* **Share links** for a note, directive set, or playbook (read-only by default).
* **Friends list / access list** (optional) to grant edit or view.
* **Snapshots**: “save state” for personal or shared collections; restore/compare later.
  * **`Snapshot`** table: `id`, `type` (playbook/note/directive-set), `entityId`, `data` (JSON blob), `schemaVersion`, `createdAt`.
  * `schemaVersion` ensures old snapshots remain readable as the schema evolves.
  * Used for: playbook publish, share links, version history.
* Community publishing still uses the **playbook fork/version** system.
* Edits by collaborators create a local history entry for audit/undo.

---

### 19) UI/UX goals: “fun but clean”

* Design tokens (type scale, spacing, radii) + consistent components.
* “Fun” concentrated in signature areas:

  * Balloons visualization
  * chips + bottom sheets
  * subtle haptics + micro-animations
* Everything else stays calm, predictable, and organized.
* Default typography and spacing remain consistent across all screens.

**Launch surface (first screen)**

* Default to a **Focus panel** inside the Framework note (no separate “Home” screen).
* Focus panel shows:
  * **Active Modes** (1–3) with 1–2 micro-directives each (rotated/interleaved)
  * **Urgent Balloons preview** (top 3–5)
  * **AI entry** (voice/chat button) + quick add directive
* Tailoring rules:
  * **Recent intent bias**: surface last used Mode/Note
  * **Urgency bias**: bubble up expiring balloons
  * **Streak protection**: surface a daily directive at risk
  * **Energy toggle**: “low energy” view swaps in tiny-step versions
* Routing override:
  * If opened from notification/deep link, land on the targeted directive/note.
* If no Active Modes are selected, show a “Pick Modes” empty state.

---

### 20) Guardrails (trust + tone)

* AI is a **compressor + organizer**, not a coach.
* Neutral tone; avoid “you should.”
* Always show what will change, where it will go, and why.
* No silent background edits or destructive changes without confirmation.
* Clear “undo” or “revert” affordance for AI-applied changes.

---

### 21) Monetization (subscription, soft limits)

**Payments infrastructure**

* Use **RevenueCat** for all purchase handling (wraps StoreKit 2, receipt validation, entitlements, analytics, and experiments).
* RevenueCat webhooks notify the backend of subscription changes — backend stores entitlement state in Postgres for server-side checks.
* No custom App Store Server API integration needed.

**Goal**

* Keep the core app genuinely useful for free.
* Gate the highest-cost and highest-power features behind Pro.

**Free (suggested)**

* Local-only data (no cloud sync).
* Small daily AI quota (e.g., 3–5 actions/day) to try features.
* Basic scheduling (simple cadence + “show tomorrow”).

**Pro (suggested)**

* Higher AI quota or “fair use” (soft caps).
* Multi-device sync.
* Publish/fork playbooks + version history.
* Advanced scheduling (complex rules, hibernation/snooze automation).
* Sharing + access grants.

**Why these limits**

* AI usage is the primary cost driver.
* Sync + sharing are clear “Pro” value without breaking offline-first.
* Power features feel like upgrades, not paywalls on core behavior.

**Usage metrics (add from day one)**

* Track lightweight per-user usage counters for future pricing, retention, and conversion analysis.
* Add the table now even if dashboards come later — retrofitting event history is impossible.

**Data model**

**`UsageMetric`**

* `id: uuid`
* `userId: uuid`
* `metric: string` (enum-like key)
* `value: number` (count, duration, etc.)
* `createdAt: timestamp`

**Tracked metrics (initial set)**

* `directives_created`
* `notes_created`
* `ai_actions` (any AI chip accepted or AI draft confirmed)
* `balloons_enabled`
* `playbooks_forked`
* `sync_events` (push or pull completed)
* `diary_entries_written`
* `schedule_rules_created`

**Usage**

* **Retention analysis**: which features correlate with daily/weekly return?
* **Pro conversion**: what usage patterns predict upgrade?
* **Pricing validation**: are free-tier limits set correctly?
* **Feature prioritization**: what do users actually use vs. ignore?

**Notes**

* Metrics are **append-only** — one row per event, not an upsert counter.
* Written locally first; synced to backend when online (piggyback on existing sync, or batch separately).
* Keep writes cheap: fire-and-forget into a local table, no blocking on user actions.
* No PII in metric values — just counts and identifiers.

---

### 22) Recommended build order (high ROI)

1. Xcode project + **GRDB local DB** + offline CRUD for notes/directives/balloons (UIKit)
2. **Basic UI** (notes list, directive list, note detail, balloon view — usable locally before API work)
3. **OpenAPI spec** + codegen pipeline (Swift types + TS types)
4. **Offline-first sync** (outbox push + cursor pull + tombstones + conflicts)
5. AI chat + **directive chips** + auto-routing
6. Background knobs + tuning suggestions
7. Simplify/Organize + directive refactor tools
8. Modes layer + Active Modes in Notes/Playbooks
9. Playbooks as tagged folders + Lite/Standard/Deep templates
10. Troubleshoot mode
11. Community playbooks (forks + snapshot versions + diff-lite)
12. Scheduling + resurfacing rules
13. Sharing + collaboration + snapshots

---

### Appendix) Infra + schema details

Backend routes, schema, and sync specifics live in `backend-outline.md` to keep this document idea/UX-focused.
iOS setup details live in `frontend-outline.md` (to be updated for Swift/GRDB).

---

### Appendix) Monorepo structure (detailed)

```
apps/
  ios/                                  # Native iOS app (Swift / UIKit)
    PrototypeMe.xcodeproj
    PrototypeMe/

      # ── App bootstrap ──────────────────────────────────────────────
      App/
        AppDelegate.swift                   # UIKit app lifecycle entry point
        SceneDelegate.swift                 # Scene lifecycle + window setup
        AppEnvironment.swift                # DI container (DB, API client, all services)

      # ── Coordinators (navigation ownership) ─────────────────────────
      Coordinators/
        Coordinator.swift                   # Protocol: start(), childCoordinators
        AppCoordinator.swift                # Root: owns UITabBarController + tab coordinators
        Tab/                                # One coordinator per tab
          FocusCoordinator.swift
          NotesCoordinator.swift
          PlaybooksCoordinator.swift
          DiaryCoordinator.swift
          SettingsCoordinator.swift
        Flows/                              # Modal / multi-step flows (reused from any tab)
          OnboardingCoordinator.swift       # Cinematic intro + AI signup chat
          AICoordinator.swift               # AI panel (chips + confirm)
          DirectiveEditorCoordinator.swift  # Create/edit directive (used from Notes, Focus, Balloons, etc.)
          ScheduleEditorCoordinator.swift   # Schedule rule editor
          BalloonConfigCoordinator.swift    # Balloon pressure/duration picker

      # ── Core (zero UI dependencies) ────────────────────────────────
      Core/
        Protocols/                          # Service interfaces (swap real ↔ mock)
          NoteServiceProtocol.swift
          DirectiveServiceProtocol.swift
          FolderServiceProtocol.swift
          TagServiceProtocol.swift
          DayEntryServiceProtocol.swift
          ScheduleServiceProtocol.swift
          AudioServiceProtocol.swift
          SituationServiceProtocol.swift
          SyncEngineProtocol.swift
          APIClientProtocol.swift

        Models/                             # GRDB Record types (local DB models)
          NotePage.swift
          Directive.swift
          Folder.swift
          Tag.swift
          Situation.swift
          DayEntry.swift
          ScheduleRule.swift
          ScheduleInstance.swift
          AudioAttachment.swift
          DirectiveHistory.swift
          UserSignal.swift
          UsageMetric.swift
          NoteDirective.swift
          NoteTag.swift
          DirectiveSituation.swift
          Tombstone.swift
          OutboxOp.swift
          SyncState.swift

        ViewData/                           # Composed structs for UI (read-only, not GRDB records)
          DirectiveRowData.swift            # Directive + balloon state + schedule status
          NoteListItem.swift                # NotePage + directive count + folder name
          FocusSnapshot.swift               # Active modes + urgent balloons + today's schedule
          DayEntrySummary.swift             # DayEntry + tag names + diary preview
          PlaybookListItem.swift            # Folder + note count + directive count

        Services/                           # Business logic (all async throws, protocol-conforming)
          NoteService.swift
          DirectiveService.swift
          FolderService.swift
          TagService.swift
          DayEntryService.swift
          ScheduleService.swift
          AudioService.swift
          SituationService.swift

        Sync/
          SyncEngine.swift                  # Outbox push + cursor pull orchestration
          OutboxQueue.swift                 # Pending operations queue
          ConflictResolver.swift

        Networking/
          APIClient.swift                   # URLSession wrapper + auth header injection
          TokenRefreshInterceptor.swift     # Auto-refresh on 401
          ReachabilityMonitor.swift         # NWPathMonitor wrapper

        Persistence/
          DatabaseManager.swift             # GRDB DatabaseQueue setup + migration runner
          Migrations/                       # Forward-only GRDB migrations
            V1_CreateTables.swift

        Notifications/
          NotificationScheduler.swift       # Local notification scheduling + rebuild

        Extensions/                         # Pure Swift + Foundation helpers
          Date+Formatting.swift             # Relative dates, ISO strings, day keys
          String+Markdown.swift             # Markdown ↔ NSAttributedString
          UUID+V7.swift                     # UUIDv7 generation
          Collection+Safe.swift             # Safe subscript (avoids index-out-of-range)
          Encodable+JSON.swift              # Quick dictionary/JSON serialization

        Formatters/                         # Shared formatters (reused across UI + services)
          DurationFormatter.swift           # "2h 15m", "30s"
          RelativeDateFormatter.swift       # "Today", "Yesterday", "3 days ago"

      # ── UI (all UIKit, depends on Core) ─────────────────────────────
      UI/
        Base/
          BaseViewController.swift          # Observation tokens, tasks, loading/error, keyboard
          BaseCollectionViewController.swift # Diffable data source boilerplate

        # ── Shared cells + views (reused across multiple screens) ───
        Shared/
          Cells/                            # Reusable cells registered once, used everywhere
            DirectiveCell.swift             # Used in: Notes detail, Directives list, Focus, Balloons, Mode detail, Playbook detail
            NoteCell.swift                  # Used in: Notes list, Playbook detail, search results
            BalloonCard.swift               # Used in: Focus (urgent preview), Balloons tab
            ScheduleInstanceRow.swift       # Used in: Focus (today), Directive detail
            AudioPlayerRow.swift            # Used in: Directive detail, Note detail
            DayEntryCell.swift              # Used in: Diary list, History
          Views/                            # Reusable non-cell views
            EmptyStateView.swift            # Illustration + message + CTA (configured per screen)
            OfflineBannerView.swift         # Top banner, auto-show/hide on reachability
            CoachMarkView.swift             # Tooltip overlay for onboarding tips
            StatusBadgeView.swift           # Active / Maintained / Retired pill
            PressureIndicator.swift         # Balloon pressure gauge (green/yellow/red)
            TierLabel.swift                 # Foundation / Support / Active label
            FormattingToolbar.swift         # Rich text input accessory view
            TagChipView.swift               # Compact tag pill (used in notes, diary, directives)
          Controls/                         # Reusable interactive controls
            AppButton.swift                 # Single button with style enum: .primary, .secondary, .destructive, .icon, .chip, .fab
            AppSegmentedControl.swift       # Styled segmented picker (tier filter, status filter)
            AppToggleRow.swift              # Label + UISwitch row (settings, balloon enable)
            AppSliderRow.swift              # Label + UISlider + value label (pressure, duration)
          Sheets/                           # Reusable modal pickers (presented from any coordinator)
            TagPickerViewController.swift   # Multi-select tags
            SituationPickerViewController.swift
            NoteLinkerViewController.swift  # Pick a note to link a directive into
            TierPickerViewController.swift
            ConflictResolverViewController.swift  # Side-by-side merge UI

        # ── Screen-specific folders (only screen-unique code) ───────
        Focus/
          FocusViewController.swift
        Notes/
          NoteListViewController.swift
          NoteDetailViewController.swift
        Directives/
          DirectiveListViewController.swift
          DirectiveDetailViewController.swift
        Balloons/
          BalloonsViewController.swift
        Diary/
          DiaryViewController.swift
          CalendarViewController.swift
        Playbooks/
          PlaybookListViewController.swift
          PlaybookDetailViewController.swift
        AI/
          AIViewController.swift
          ChipCardView.swift
          ChipConfirmViewController.swift
        Onboarding/
          OnboardingIntroViewController.swift
          AISignupChatViewController.swift
          SeedPlanPreviewViewController.swift
        Profile/
          ProfileViewController.swift
        Friends/
          FriendsListViewController.swift
          FriendRequestViewController.swift
        Settings/
          SettingsViewController.swift
          SyncDebugViewController.swift
          SubscriptionViewController.swift

      # ── Theme ───────────────────────────────────────────────────────
      Theme/
        DesignTokens.swift                  # Colors, spacing, radii, type scale
        Haptics.swift
        UIKit+Theme.swift                   # UIColor/UIFont convenience extensions using tokens

      # ── Generated ───────────────────────────────────────────────────
      Generated/
        APITypes.swift                      # ← auto-generated from openapi.yaml

      # ── Resources ───────────────────────────────────────────────────
      Resources/
        Assets.xcassets
        Info.plist

    # ── Tests ─────────────────────────────────────────────────────────
    PrototypeMeTests/
      Core/
        Services/
          DirectiveServiceTests.swift
          NoteServiceTests.swift
        Sync/
          SyncEngineTests.swift
          ConflictResolverTests.swift
        Persistence/
          MigrationTests.swift
        Models/
          ModelCodingTests.swift
        ViewData/
          FocusSnapshotTests.swift
      Helpers/
        TestDatabase.swift                  # In-memory GRDB setup
        SeedData.swift                      # Realistic test fixtures
        MockAPIClient.swift                 # Conforms to APIClientProtocol
        MockNoteService.swift               # Conforms to NoteServiceProtocol
        MockDirectiveService.swift          # Conforms to DirectiveServiceProtocol
    PrototypeMeUITests/
      OnboardingFlowTests.swift
      NoteCreationTests.swift

  backend/
    src/
      routes/                   # HTTP route handlers
      validators/               # route payload validation
      middlewares/              # auth, rate-limit, validation
      services/                 # sync, ai, playbooks, sharing (business logic)
      jobs/                     # compaction, snapshots, cleanup
      config/                   # env, feature flags
      generated/
        apiTypes.ts             # ← auto-generated from openapi.yaml
      index.ts
    tests/

packages/
  api-spec/
    openapi.yaml                # Single source of truth for all API types + endpoints
    scripts/
      generate-swift.sh         # → apps/ios/PrototypeMe/Generated/APITypes.swift
      generate-typescript.sh    # → apps/backend/src/generated/apiTypes.ts
      generate-kotlin.sh        # → (future Android app)

  config/
    src/
      env.ts                    # environment variable loading + validation
      featureFlags.ts           # feature flag definitions
      constants.ts              # shared constants (limits, defaults, enums)
      index.ts

  db/
    src/
      schema/                   # Drizzle table definitions (Postgres)
      migrations/               # Drizzle migrations
      queries/                  # reusable query functions
      index.ts

  cache/
    src/
      client.ts                 # Valkey client
      keys.ts                   # key helpers
      index.ts

  storage/
    src/
      client.ts                 # S3 client (AWS SDK v3)
      keys.ts                   # key path builders (snapshots/, audio/, exports/)
      presign.ts                # presigned URL generation (upload + download)
      index.ts
```

---

---

### Appendix) Community + infra details

Community playbook schema + rollout now live in `backend-outline.md` to keep this doc UX-focused.

---

### Appendix) Identity + auth

Identity/auth details now live in `backend-outline.md` to keep this doc UX-focused.

---

### Appendix) Legacy files

* `apps/iOSApp/` is the legacy iOS app kept for reference.
* `OLD-project-progress.md` is archived progress from the earlier version.

---

### Progress Tracking

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 0 | Remove storyboard wiring (programmatic window setup) | Done | 2026-03-11 |
| 1 | Theme foundation (DesignTokens.swift + Haptics.swift) | Done | 2026-03-11 |
| 2 | App bootstrap (AppEnvironment, Coordinator pattern, AppCoordinator with UITabBarController) | Done | 2026-03-11 |
| 3 | BaseViewController + shared UI stubs (EmptyStateView, AppButton) | Done | 2026-03-11 |
| 4 | 5 tab coordinators (Focus, Notes, Playbooks, Diary, Settings) | Done | 2026-03-11 |
| 5 | 12 placeholder view controllers with navigation flow | Done | 2026-03-11 |
| 6 | Build verification — 0 errors, 0 warnings | Done | 2026-03-11 |

**Approach change:** Building full UI with dummy data first (UI-first approach). Models start as plain Swift structs with hardcoded sample data. GRDB, services, and networking come after the UI is solid. This avoids premature wiring and lets us iterate on the look/feel faster.

**Next up (UI-first with dummy data):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 7 | Model structs (Enums, CoreModels, ViewData) + SampleData with realistic dummy data | Done | 2026-03-11 |
| 8 | Shared views (StatusBadge, PressureIndicator, TierLabel, RatingCircle) + shared cells (NoteCell, DirectiveCell, BalloonCard, DayEntryCell, ScheduleInstanceRow) | Done | 2026-03-11 |
| 9 | All list screens rewritten with UICollectionView + compositional layout + diffable data sources | Done | 2026-03-11 |
| 10 | All detail screens rewritten (NoteDetail, DirectiveDetail, PlaybookDetail, Calendar) | Done | 2026-03-11 |
| 11 | Focus screen: 3-section layout (modes, balloons, schedule) + floating AI button | Done | 2026-03-11 |
| 12 | Settings + SyncDebug: insetGrouped lists with toggles and dummy sync stats | Done | 2026-03-11 |
| 13 | Coordinator closures updated to pass UUIDs, full drill-down navigation wired | Done | 2026-03-11 |
| 14 | Build verification — 0 errors, 0 warnings | Done | 2026-03-11 |

**Later (after UI is solid):**
- GRDB integration + migrations + Record conformance
- Service layer + AppEnvironment wiring
- ValueObservation replacing SampleData calls
- OpenAPI codegen + networking + sync engine
