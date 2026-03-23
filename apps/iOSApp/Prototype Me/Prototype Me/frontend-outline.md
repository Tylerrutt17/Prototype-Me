## Frontend infrastructure outline (iOS — Swift / UIKit / GRDB)

See also: `backend-outline.md` for API, schema, and sync protocol details.
See also: `project-outline-v2.md` for product spec, data model decisions, and build order.

### 1) Architecture overview

* **Platform**: iOS-first, native **Swift / UIKit** ONLY UIKIT.
* **Local DB**: **GRDB** (Swift SQLite toolkit) for full control over sync queries, outbox, tombstones, and migrations.
* **Networking**: REST API for sync + auth. All types generated from OpenAPI spec.
* **ID strategy**: **UUIDv7** for all entities (sortable, offline-safe, no collisions).
* **Offline-first**: app is fully usable without internet; sync is opportunistic.

---

### 2) Local data + sync

* GRDB schema mirrors backend entities (see `backend-outline.md` §2 for full data model).
* All mutable entities include: `version: Int`, `updatedAt`, `updatedByDeviceId`, `metadata: JSON`.
* **Outbox queue** persists `OutboxOp` records until server ack.
  * Each `OutboxOp` includes `schemaVersion` to handle queued ops replaying after app updates.
* **Pull cursor** stored in `SyncState` table (`lastSyncToken`, `lastPushAt`, `lastPullAt`, `deviceId`).
* **Tombstone table** (separate from main entities): `id`, `entityType`, `entityId`, `deletedAt`, `updatedAt`, `deviceId`.
  * Main tables stay clean — no `deletedAt` column on every entity.
  * Compact local tombstones after server ack.
* **Conflict handling**: version-based LWW (highest `version` wins; `updatedAt` + `updatedByDeviceId` as tiebreaker). Note body conflicts create a conflict copy for manual resolution.
* **Background sync**: push first (maximize data safety), then pull. Triggers: app foreground, `BGAppRefreshTask`, manual pull-to-refresh, after successful push.

**GRDB migration rules**

* Always **forward-only** migrations. Never rewrite or edit old migrations.
* Example: `v1_create_tables`, `v2_add_directive_status`, `v3_add_user_signal`, `v4_add_schedule`.

**Local tables (sync infrastructure)**

* **`SyncState`**: `lastSyncToken`, `lastPushAt`, `lastPullAt`, `deviceId` (single-row table).
* **`Device`**: `id`, `name`, `platform`, `createdAt`, `lastSeenAt`.
* **`OutboxOp`**: `id`, `entityType`, `entityId`, `op`, `patch`, `baseUpdatedAt`, `schemaVersion`, `createdAt`, `attemptCount`, `lastError`.
* **`Tombstone`**: `id`, `entityType`, `entityId`, `deletedAt`, `updatedAt`, `deviceId`.

**Local tables (analytics)**

* **`UsageMetric`**: `id`, `userId`, `metric`, `value`, `createdAt` (append-only, fire-and-forget).

---

### 3) Generated types (OpenAPI)

* **OpenAPI spec** (`packages/api-spec/openapi.yaml`) is the single source of truth for all API types and endpoints.
* Swift types generated via Apple's `swift-openapi-generator` → `Codable` structs in `Generated/APITypes.swift`.
* Codegen script: `packages/api-spec/scripts/generate-swift.sh`.
* All API requests include `X-API-Version` header.

---

### 4) Design language ("fun but clean")

* Design tokens (type scale, spacing, radii) defined in `Theme/DesignTokens.swift`.
* "Fun" concentrated in signature areas:
  * Balloons visualization
  * AI chips + bottom sheets
  * subtle haptics (`Theme/Haptics.swift`) + micro-animations
* Everything else stays calm, predictable, and organized.
* Default to a **dark theme** with lighter accents so color pops.
* Premium-but-fun feel: crisp typography + generous spacing, with lively accent colors against the dark base.

---

### 5) Screen map (high level)

* **Focus / Framework** (default launch surface)
* **Notes list** + **Note detail**
* **Directives list**
* **Balloons**
* **Playbooks** + **Playbook detail**
* **Modes** + **Mode detail**
* **Daily diary** + **Calendar**
* **History** (recent days + summaries)
* **Situations** (list + detail)
* **Settings**
* **AI panel** (voice/chat input + directive chips)
* **Sync debug** (outbox size, last push/pull, last error, last cursor, registered devices)
* **Subscription (Settings)**: plan details, Pro badge, manage/restore
* **Paywall** (full screen or sheet; reused for upgrade prompts)
* **Usage / AI limit** (quota remaining, reset time)
* **Onboarding / Intro** (cinematic first-launch experience)
* **Coach marks / Tour** (in-app tips that highlight UI elements)
* **AI signup chat** (optional goal capture + seed plan preview)
* **Profile** (reused for self + friend; name, bio, avatar, mood chips)
* **Friends** (list, requests, and add friend)
* **Supporting screens**: auth/account, permissions prompts, empty states, error/offline states, legal pages, feedback/support

---

### 6) Navigation model

* **Default launch**: Focus/Framework screen.
* **Primary nav**: `UITabBarController` with tabs — Focus, Notes, Playbooks, Diary, Settings.
* **Secondary nav**: optional slide-out or settings sub-page for low-frequency tools (Sync Debug, Admin).
* Home emphasizes **next actions**, not a menu of everything.
* AI entry lives on Focus (no dedicated AI tab).
* On first launch, run a **cinematic intro** before the main app:
  * 3–5 slides for value props + trust ("AI drafts, you confirm").
  * Enter a "Focus Console" screen with ambient motion and a single CTA (glassy panel, soft glow, slow drift).
  * Optional AI signup chat (voice/text), no chat bubbles — single input + submit.
  * "Thinking" animation, then seed plan cards stack in (directives + playbooks).
  * Confirm/edit seed plan, then "Welcome" → Focus screen.
* After onboarding, use inline coach marks on key screens.
* Settings should include **Replay tour** and **Profile privacy** toggle (private/friends/public).
* Reuse AI chat core logic, but keep onboarding vs main AI as separate UI shells.
* Friends UX flow: Search/add friend → pending request → accept/decline → friends list + quick share access from profile.

---

### 7) App architecture + state management

**Dependency container (`AppEnvironment`)**

* A single `AppEnvironment` struct holds all shared dependencies:
  * `database: DatabaseManager` (GRDB `DatabaseQueue`)
  * `apiClient: APIClient`
  * `syncEngine: SyncEngine`
  * `reachability: ReachabilityMonitor`
  * `notificationScheduler: NotificationScheduler`
  * `deepLinkRouter: DeepLinkRouter`
  * Services: `noteService`, `directiveService`, `folderService`, `dayEntryService`, `tagService`, `scheduleService`, `audioService`
* Created once in `AppDelegate.didFinishLaunching` and passed down via coordinators.
* **No singletons** — every dependency is explicit and constructor-injected. Makes testing trivial (swap real deps for mocks/stubs).
* Services accept `DatabaseManager` (and optionally `APIClient`) in their init. They are plain classes, not singletons.

**Coordinator pattern (navigation ownership)**

* View controllers never push, present, or dismiss other view controllers. **Coordinators own all navigation.**
* `AppCoordinator` (root):
  * Owns the `UITabBarController`.
  * Creates child coordinators: `FocusCoordinator`, `NotesCoordinator`, `PlaybooksCoordinator`, `DiaryCoordinator`, `SettingsCoordinator`.
  * Handles deep link routing by delegating to the correct child coordinator.
* Each tab coordinator:
  * Owns its `UINavigationController`.
  * Creates view controllers, injects dependencies from `AppEnvironment`, and defines navigation closures.
  * Manages child coordinators for sub-flows (e.g., `NoteDetailCoordinator`, `DirectiveEditorCoordinator`).
* **Flow example** — Notes tab:
  * `NotesCoordinator` creates `NoteListViewController` → user taps a note → coordinator pushes `NoteDetailViewController` → user taps a directive → coordinator pushes `DirectiveDetailViewController`.
  * Back navigation is handled by `UINavigationController` automatically; coordinator cleans up on pop via `UINavigationControllerDelegate`.
* **Modal flows** (e.g., AI panel, schedule editor, balloon picker):
  * Coordinator presents modally, creates a child coordinator for the modal, and dismisses + cleans up when the child signals completion.
  * Communication back to parent: closures (not delegates) — e.g., `onDirectiveCreated: (Directive) -> Void`.

**Coordinator lifecycle**

* Parent coordinator holds `var childCoordinators: [Coordinator]`.
* Child signals completion → parent removes it from the array → child deallocates → its VC and observation tokens are released.
* Coordinators conform to a simple `Coordinator` protocol:
  ```
  protocol Coordinator: AnyObject {
      var childCoordinators: [Coordinator] { get set }
      func start()
  }
  ```

**Async strategy**

* **Swift concurrency (`async/await`)** for all asynchronous work: network calls, sync operations, file I/O.
* Service methods are `async throws`:
  * `func createDirective(_ draft: DirectiveDraft) async throws -> Directive`
  * `func pushOutbox() async throws`
* View controllers call services from `Task { }` blocks scoped to the VC lifecycle.
* **Task cancellation**: store `Task` handles and cancel them in `deinit` or `viewDidDisappear`:
  ```
  private var loadTask: Task<Void, Never>?

  override func viewWillAppear(_ animated: Bool) {
      super.viewWillAppear(animated)
      loadTask = Task { await refreshData() }
  }

  override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)
      loadTask?.cancel()
  }
  ```
* **No GCD / DispatchQueue** for business logic — only used if a third-party API demands it.
* **`@MainActor`**: all view controllers and coordinators are implicitly main-actor. Service methods that touch UI-bound state use `@MainActor` where needed; pure data methods stay nonisolated.

**GRDB observation (reactive reads)**

* **`ValueObservation`** is the primary mechanism for reactive UI updates.
  * Each screen observes a database request; GRDB delivers updates on the main queue.
  * Example: `NoteListViewController` observes `NotePage.order(Column("sortIndex"))` — updates automatically drive `NSDiffableDataSourceSnapshot` on `UITableView` / `UICollectionView`.
* **No Combine or RxSwift dependency** — `ValueObservation` already handles observation, scheduling, and cancellation.
* **Observation setup pattern**: each VC calls a helper that returns a `DatabaseCancellable`:
  ```
  private var observationToken: DatabaseCancellable?

  func startObserving() {
      observationToken = ValueObservation
          .tracking { db in try NotePage.fetchAll(db) }
          .start(in: env.database.reader, onError: { _ in }, onChange: { [weak self] notes in
              self?.applySnapshot(notes)
          })
  }

  deinit { observationToken?.cancel() }
  ```
* **Compound observations**: for screens that need data from multiple tables (e.g., Focus panel: directives + schedule instances + balloons), use `ValueObservation.tracking` with a single closure that queries all needed data and returns a typed struct.
* Services own all write paths. View controllers **never** write to GRDB directly.

**Base view controller (`BaseViewController`)**

* Optional lightweight base class to reduce boilerplate:
  * `var observationTokens: [DatabaseCancellable]` — automatically cancelled in `deinit`.
  * `var activeTasks: [Task<Void, Never>]` — automatically cancelled in `deinit`.
  * `func showLoadingState()` / `hideLoadingState()` — standard inline spinner.
  * `func showError(_ error: Error)` — standard toast/banner.
  * Keyboard avoidance: listens for `UIResponder.keyboardWillShowNotification` and adjusts `additionalSafeAreaInsets` or scroll view insets.
* Not mandatory — screens can skip it if they don't need the helpers.

**Summary: data flow end-to-end**

```
User action
  → ViewController calls Service method (async)
    → Service writes to GRDB (+ enqueues OutboxOp if syncable)
      → GRDB ValueObservation fires
        → ViewController receives updated data
          → ViewController applies NSDiffableDataSourceSnapshot
            → UI updates
```

```
Sync pull arrives
  → SyncEngine writes remote changes to GRDB
    → GRDB ValueObservation fires on any observing VC
      → UI updates automatically (no manual refresh needed)
```

---

### 8) Networking layer

* **`APIClient`** — thin wrapper around `URLSession` for all HTTP calls.
  * Injects `Authorization: Bearer <token>` and `X-API-Version` headers automatically.
  * Request/response types are the generated `Codable` structs from OpenAPI.
* **Token refresh interceptor**: if a request returns `401`, automatically call `/auth/refresh`, retry the original request once, then fail if still unauthorized.
* **Reachability monitor** (`NWPathMonitor`): tracks online/offline state.
  * Sync engine subscribes to reachability changes — triggers push when connectivity returns.
  * UI can show a subtle offline banner when `path.status != .satisfied`.
* **Retry + backoff**: network errors use exponential backoff (1s → 2s → 4s → max 30s) with jitter. Outbox ops retry independently.
* **Timeout policy**: 15s for normal requests, 30s for sync push (larger payloads), 60s for AI requests.
* **Certificate pinning**: optional, add if/when publishing to App Store for extra transport security.

---

### 9) AI client flow

* **All AI requests are proxied through the backend** — the client never talks to OpenAI directly.
* **Request pipeline** (client side):
  1. User triggers AI (voice button or text input on Focus / Troubleshoot panel).
  2. Client builds a **context bundle**: current note/directive IDs, recent diary entries, active situations, relevant UserSignal keys.
  3. `POST /ai/chips` with context bundle → backend runs routing prompt → returns `AiDraft` with chip suggestions.
  4. Client renders chips in a bottom sheet.
* **Chip rendering**: each chip is a tappable card showing: action label, target destination, and a "why" subtitle.
  * Tapping a chip opens a **quick edit/confirm screen** (pre-filled fields, editable before commit).
  * Dismissing the sheet discards all unaccepted chips (status → `dismissed`).
* **Troubleshoot mode**: same AI panel, but scoped — context bundle only includes the selected note/playbook IDs. UI shell is distinct (in-place sheet vs full panel).
* **Onboarding AI chat**: separate UI shell (no chat bubbles — single input + submit + "thinking" animation + seed cards). Reuses the same `APIClient` + `/ai/chips` endpoint with an `isOnboarding` flag.
* **Streaming** (optional future): if backend supports SSE for longer responses, use `URLSession` byte stream and append to UI incrementally.
* **Quota display**: after each AI response, backend returns `remainingQuota` + `resetAt` — client stores and surfaces in the AI panel header and Usage screen.

---

### 10) Focus panel (launch surface)

* **Default launch screen** — the Focus tab in the tab bar.
* **Composition** (top to bottom):
  * **Active Modes strip** (horizontal scroll, max 3): each shows mode name + 1–2 micro-directives. Tap to drill into Mode detail.
  * **Urgent Balloons preview** (top 3–5 by remaining time): compact cards with pressure indicator + countdown. Tap to open directive.
  * **Scheduled today** section: directives with a `ScheduleInstance` for today's date, status = `pending`.
  * **AI entry**: floating action button (voice/text) anchored bottom-right.
  * **Quick add directive**: inline text field below the AI button for fast capture.
* **Tailoring rules** (applied when building the focus snapshot):
  * **Urgency bias**: sort balloons by `balloonRemainingSec` ascending.
  * **Recent intent bias**: boost the last-opened Mode/Note.
  * **Streak protection**: surface a directive at risk of breaking a streak.
  * **Energy toggle**: "Low energy" mode (persisted in `UserDefaults`) swaps directives for their `micro` variants or tiny-step fallbacks.
* **Routing override**: if the app is opened from a notification or deep link, skip Focus and navigate directly to the target directive/note.
* **Empty state**: if no Active Modes are selected, show a "Pick Modes" card with a CTA to browse Modes/Playbooks.
* **Observation**: Focus panel observes a compound GRDB query joining Directives + ScheduleInstances + Balloons — updates live as data changes.

---

### 11) Directives lifecycle UI

* **Status display**: directives show a status badge — `active` (default), `maintained`, `retired`.
* **Quick actions** (swipe or long-press context menu):
  * **Graduate** → moves to `maintained` (collapsed in note, hidden from focus).
  * **Snooze** → sets `snoozedUntil` date; hidden until that date, then auto-resurfaces.
  * **Retire** → moves to `retired` (hidden from all normal views, searchable in archive).
  * **Balloon toggle** → enable/disable balloon with pressure/duration picker.
  * **Schedule** → open schedule rule editor (weekly/monthly/one-off).
  * **Link to Note** → picker to add this directive to another note.
* **In-note display**:
  * Active directives render normally.
  * Maintained directives collapse into a "Maintained" section (expandable).
  * Retired directives hidden behind an "Archived" toggle at the bottom.
* **Balloon interaction**: when `balloonEnabled`, directive row shows a pressure indicator (color-coded: green/yellow/red) + countdown. Tap to "pump" (reset timer) or open detail.
* **DirectiveHistory**: every mutation (create, update, graduate, snooze, balloon pump, shrink, split) appends to the local `DirectiveHistory` table. Displayed in a "History" section on the directive detail screen.

---

### 12) Modes

* **Mode** = `NotePage` with `kind = 'mode'`. Contains a short description + linked directives (some marked `micro`).
* **Framework note** = `NotePage` with `kind = 'framework'`. One allowed at a time; pinned to top of Notes list with confirm-before-edit protection.
* **Active Modes selection**: user picks 1–3 modes as "active" (stored as a lightweight local setting or metadata flag). Capped at 3 unless user changes a setting.
* **Mode detail screen**: shows mode description, linked directives (with inline status/balloon indicators), linked situations, and a "Troubleshoot" button.

---

### 13) Deep linking + routing

* **URL scheme**: `prototypeme://` for internal links.
  * `prototypeme://directive/{id}` → open directive detail.
  * `prototypeme://note/{id}` → open note detail.
  * `prototypeme://playbook/{id}` → open playbook detail.
  * `prototypeme://focus` → open Focus tab.
  * `prototypeme://diary/{yyyy-MM-dd}` → open diary for a specific date.
* **Universal links** (future): `https://prototypeme.app/share/{id}` for shared playbooks/notes.
* **Router**: a `DeepLinkRouter` class registered in `AppDelegate` / `SceneDelegate`.
  * Parses incoming URL → determines target tab + view controller → pushes onto the correct navigation stack.
  * Handles cold launch (queued URL) and warm launch (immediate navigation).
* **Notification payloads**: local notifications include a deep link URL in `userInfo` — tapping a notification routes through the same `DeepLinkRouter`.

---

### 14) Notifications

* **Local notifications** (no push server required for v1):
  * **Scheduled directives**: when a `ScheduleInstance` is generated for tomorrow, schedule a local notification at the user's preferred morning time.
  * **Balloon reminders**: when a balloon's remaining time hits a threshold (e.g., 25% remaining), fire a notification: "Your [directive name] balloon is running low."
  * **Snooze resurface**: when `snoozedUntil` date arrives, notify: "[directive name] is back from snooze."
  * **Daily diary prompt**: optional evening notification to encourage a diary entry + day rating.
  * **Weekly review**: optional weekly notification to review kept/stuck/dropped directives.
* **Permission flow**: request notification permission after onboarding (not on first launch — explain value first).
* **Management**: all scheduled notifications are rebuilt on app foreground to stay in sync with data changes. Use `UNUserNotificationCenter` with category-based actions (e.g., "Mark Done" / "Snooze" directly from the notification).
* **Push notifications** (phase 2+): for friend requests, shared playbook updates, and server-triggered alerts. Requires APNs registration + backend integration.

---

### 15) Rich text editing

* **Approach**: `NSTextView` / `UITextView` with **TextKit 2** (`NSTextContentManager` + `NSTextLayoutManager`).
  * Provides native performance, accessibility, and full control over styling.
* **Supported formatting**: bold, italic, strikethrough, headings (H1–H3), bullet lists, numbered lists, inline code, blockquotes.
* **Storage format**: note `body` stored as a lightweight **Markdown string** in GRDB.
  * On load, parsed to `NSAttributedString` for display.
  * On save, converted back to Markdown.
  * Markdown is sync-friendly (plain text diffing), human-readable, and compact.
* **Formatting toolbar**: a custom `UIInputAccessoryView` with formatting buttons (bold, italic, list, heading, etc.). Visible when the text view is first responder.
* **Conflict resolution**: since bodies are stored as Markdown strings, concurrent edits produce a conflict copy (see sync §2). A "Resolve" UI shows both versions side-by-side for manual merge.

---

### 16) Audio recording + playback

* **Recording**: `AVAudioRecorder` with AAC encoding (`.m4a`). Saved to a temp file, then moved to the app's documents directory with a UUID-based filename.
* **Playback**: `AVAudioPlayer` with standard controls (play/pause, scrub, speed toggle).
* **Attachment flow**: from a directive detail screen, tap "Add voice memo" → record → save creates an `AudioAttachment` record in GRDB with a local `storageKey` (file path).
* **Sync**: on push, audio files are uploaded to S3 via a presigned URL (separate from the sync outbox — large binary uploads are handled independently). The `AudioAttachment.storageKey` is updated to the S3 key after upload.
* **Transcript** (optional): after upload, backend can run transcription (Whisper or similar) and populate `AudioAttachment.transcript`. Pulled down on next sync.
* **UI**: audio attachments displayed as compact player rows below the directive body. Swipe to delete.

---

### 17) Subscriptions + payments

* Use **RevenueCat** SDK for iOS in-app purchases (wraps StoreKit 2, handles receipt validation, entitlements, and analytics).
* RevenueCat dashboard manages products, offerings, and experiments — no custom receipt validation or server-side App Store API integration needed.
* Entitlements checked via RevenueCat SDK on client and RevenueCat webhooks on backend; client hides/shows UI but is not trusted.
* Free plan: local-only, small daily AI quota, basic scheduling.
* Pro plan: sync, higher AI quota, publish/fork playbooks, advanced scheduling, sharing.

---

### 18) Error handling + offline states

* **Offline banner**: when `NWPathMonitor` reports no connectivity, show a subtle top banner ("Offline — changes saved locally"). Auto-dismiss when connectivity returns.
* **Sync errors**: if push/pull fails after retries, show a non-blocking toast with "Sync failed — will retry" and update the Sync Debug screen with the last error.
* **Conflict UI**: when a note body conflict is detected during pull, show an inline banner on the affected note: "Conflict detected — tap to resolve." Resolution screen shows both versions side-by-side.
* **Empty states**: every list screen (Notes, Directives, Balloons, Playbooks, Diary) has a designed empty state with:
  * Illustration or icon.
  * Short explanation of what belongs here.
  * Primary CTA to create the first item.
* **Error screens**: for unrecoverable errors (DB corruption, auth failure), show a full-screen error with a "Retry" button and a "Contact Support" link.
* **Graceful degradation**: AI features degrade silently when offline — the AI button shows a disabled state with "Available when online" tooltip. All other features work fully offline.

---

### 19) Accessibility

* **VoiceOver**: all interactive elements have accessibility labels and traits. Custom views (balloon pressure indicator, chip cards) implement `UIAccessibilityElement` with descriptive labels.
* **Dynamic Type**: all text uses `UIFont.preferredFont(forTextStyle:)` or scaled custom fonts via `UIFontMetrics`. Layouts accommodate larger text sizes without truncation or overlap.
* **Minimum tap targets**: all tappable elements are at least 44×44pt.
* **Color contrast**: all text meets WCAG AA contrast ratios (4.5:1 for body text, 3:1 for large text) against the dark theme background.
* **Reduce Motion**: respect `UIAccessibility.isReduceMotionEnabled` — disable balloon animations, card stacking effects, and micro-animations when enabled. Use simple fades instead.
* **Bold Text**: respect `UIAccessibility.isBoldTextEnabled` for users who prefer bold.
* **Haptics**: gated behind `UIAccessibility.isReduceMotionEnabled` check — skip haptic feedback when reduce motion is on.

---

### 20) Testing strategy

* **Unit tests** (XCTest):
  * Service layer tests (`DirectiveServiceTests`, `NoteServiceTests`, etc.) using an **in-memory GRDB database** for fast, isolated tests.
  * Sync engine tests: mock `APIClient` responses, verify outbox processing order, conflict resolution, and tombstone handling.
  * Model tests: encoding/decoding, validation, computed properties.
* **Integration tests**:
  * Full sync round-trip: local write → outbox → mock server → pull → verify local state.
  * GRDB migration tests: apply migrations sequentially on a fresh DB, verify schema integrity.
* **UI tests** (XCUITest):
  * Critical flows: onboarding, create note, create directive, balloon toggle, AI chip accept/dismiss.
  * Accessibility audit: verify VoiceOver labels on key screens.
* **Snapshot tests** (optional, via `swift-snapshot-testing`):
  * Capture UI screenshots for key screens across device sizes and Dynamic Type settings.
* **Test data**: a `SeedData` helper that populates an in-memory GRDB database with realistic fixtures (notes, directives, folders, schedule rules).
* **CI**: run unit + integration tests on every PR. UI tests on nightly or pre-release.

---

### 21) Dependencies

* **GRDB** — SQLite toolkit (local DB, migrations, observation).
* **swift-openapi-generator** + **swift-openapi-runtime** + **swift-openapi-urlsession** — OpenAPI codegen + client transport.
* **swift-snapshot-testing** (dev only) — snapshot tests for UI.
* No Combine framework dependency. No third-party reactive library.
* No third-party networking library — `URLSession` is sufficient with the `APIClient` wrapper.
* No third-party UI component libraries — all custom UIKit.
* Evaluate adding later if needed: **KeychainAccess** (secure token storage), **Nuke** (image loading for avatars/playbook covers).

---

### 22) iOS project setup checklist

* Xcode project (`apps/ios/PrototypeMe.xcodeproj`) with UIKit app lifecycle (`AppDelegate` + `SceneDelegate`).
* GRDB integrated via Swift Package Manager.
* `DatabaseManager.swift` — GRDB `DatabaseQueue` setup + migration runner.
* Forward-only GRDB migrations in `Persistence/Migrations/`.
* `APIClient.swift` — `URLSession` wrapper with auth header injection + token refresh.
* `ReachabilityMonitor.swift` — `NWPathMonitor` wrapper, publishes connectivity state.
* `DeepLinkRouter.swift` — URL scheme parser + navigation dispatcher.
* Sync engine wired to `/sync/push` + `/sync/pull`.
* Background sync via `BGAppRefreshTask` + foreground triggers.
* Local notifications registered via `UNUserNotificationCenter`.
* OpenAPI codegen script in CI/pre-build phase.
* `Generated/APITypes.swift` auto-generated from `openapi.yaml`.
* Design tokens in `Theme/DesignTokens.swift`.
* Haptics in `Theme/Haptics.swift`.
* In-memory GRDB test harness + `SeedData` fixture helper.
* XCTest target with unit + integration tests.

---

### Progress Tracking

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 0 | Remove storyboard wiring (pbxproj, Info.plist, delete Main.storyboard + ViewController.swift) | Done | 2026-03-11 |
| 1 | Theme foundation (DesignTokens.swift + Haptics.swift) | Done | 2026-03-11 |
| 2 | App bootstrap (AppEnvironment stub, move files to App/, rewrite AppDelegate + SceneDelegate, Coordinator protocol, AppCoordinator) | Done | 2026-03-11 |
| 3 | BaseViewController (dark bg, placeholder helpers, demo button factory) | Done | 2026-03-11 |
| 4 | Shared UI component stubs (EmptyStateView + AppButton using UIButton.Configuration) | Done | 2026-03-11 |
| 5 | Tab coordinators (FocusCoordinator, NotesCoordinator, PlaybooksCoordinator, DiaryCoordinator, SettingsCoordinator) | Done | 2026-03-11 |
| 6 | Placeholder view controllers (12 screens: Focus, NoteList, NoteDetail, DirectiveList, DirectiveDetail, Balloons, Diary, Calendar, PlaybookList, PlaybookDetail, Settings, SyncDebug) | Done | 2026-03-11 |
| 7 | Build verification — 0 errors, 0 warnings | Done | 2026-03-11 |

**Approach change:** Building full UI screens with dummy/hardcoded data before wiring up GRDB, services, or networking. This lets us get the look and feel right first, then swap in real persistence later. Models will be defined as plain Swift structs initially; GRDB `Record` conformance and services come after the UI is solid.

**Next up (UI-first with dummy data):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 8 | Model structs: Enums.swift, CoreModels.swift, ViewData.swift (nonisolated + Sendable for diffable data sources) | Done | 2026-03-11 |
| 9 | SampleData.swift — realistic dummy data (3 folders, 8 notes, 15 directives, 10 diary entries, schedule rules/instances, tags, history) | Done | 2026-03-11 |
| 10 | Shared views: StatusBadgeView, PressureIndicator, RatingCircleView | Done | 2026-03-11 |
| 11 | Shared cells: NoteCell, DirectiveCell, BalloonCard, DayEntryCell, ScheduleInstanceRowCell | Done | 2026-03-11 |
| 12 | List screens rewritten: NoteList, DirectiveList (with segmented filter), Diary, PlaybookList (with PlaybookCell), Balloons (2-col grid) — all UICollectionView + compositional layout + diffable data source | Done | 2026-03-11 |
| 13 | Detail screens rewritten: NoteDetail (header + linked directives), DirectiveDetail (header + balloon + schedule + history), PlaybookDetail (header + notes), Calendar (7-col grid with rating circles) | Done | 2026-03-11 |
| 14 | Focus screen rewritten: 3-section compositional layout (horizontal modes, 2-col balloons, vertical schedule) + floating AI button placeholder | Done | 2026-03-11 |
| 15 | Settings + SyncDebug rewritten: insetGrouped list with toggles/navigation/info rows | Done | 2026-03-11 |
| 16 | Coordinators updated: UUID-based closures (onNoteSelected(UUID), onDirectiveSelected(UUID), etc.), detail VCs accept entity IDs, full drill-down navigation | Done | 2026-03-11 |
| 17 | SectionHeaderView reusable supplementary view for multi-section screens | Done | 2026-03-11 |
| 18 | Build verification — 0 errors, 0 warnings | Done | 2026-03-11 |

**GRDB Persistence (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 19 | GRDB package added via SPM (v7.x, static linking) | Done | 2026-03-11 |
| 20 | DatabaseManager — SQLite in Application Support, forward-only migrations for all 9 tables | Done | 2026-03-11 |
| 21 | CoreModels updated: FetchableRecord + PersistableRecord conformances, GRDB associations, custom JSON encoding for DayEntry.tags and ScheduleRule.params | Done | 2026-03-11 |
| 22 | AppEnvironment updated: holds DatabaseManager, live() and inMemory() factory methods | Done | 2026-03-11 |
| 23 | DatabaseSeeder — seeds sample data on first launch (no-op if DB already has data) | Done | 2026-03-11 |
| 24 | All coordinators pass dbQueue to view controllers | Done | 2026-03-11 |
| 25 | All 10 VCs use ValueObservation — screens auto-update when DB changes | Done | 2026-03-11 |
| 26 | Build verification — 0 errors, 0 warnings | Done | 2026-03-11 |

**Create/Edit Flows (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 27 | Form controls: FormTextField, FormTextView, FormSegmentedRow, FormToggleRow | Done | 2026-03-11 |
| 28 | AppNavBar: custom nav bar with back button, left/right buttons, animated title | Done | 2026-03-11 |
| 29 | Editor VCs: NoteEditorViewController, DirectiveEditorViewController, DayEntryEditorViewController, PlaybookEditorViewController — all with GRDB read/write, create + edit modes | Done | 2026-03-11 |
| 30 | Coordinators wired: all tab coordinators present editors modally (onAddTapped → create, onEditTapped → edit), dismiss on save | Done | 2026-03-11 |
| 31 | List VCs: + button in nav bar triggers onAddTapped closure; swipe-to-delete with confirmation | Done | 2026-03-11 |
| 32 | Detail VCs: pencil button in nav bar triggers onEditTapped closure | Done | 2026-03-11 |
| 33 | BalloonNode + BalloonSkyView: full balloon visualization with pressure colors, floating animation, rise-from-ground entrance | Done | 2026-03-11 |
| 34 | AppNavBar deprecation fix (contentEdgeInsets → UIButton.Configuration) | Done | 2026-03-16 |
| 35 | DirectivePickerViewController — searchable picker to link directives to notes, writes NoteDirective join | Done | 2026-03-16 |
| 36 | NoteDetail: "Link Directive" button cell at bottom of directives section + swipe-to-unlink | Done | 2026-03-16 |
| 37 | All 3 coordinators (Notes, Playbooks, Focus) wired to present DirectivePicker from NoteDetail | Done | 2026-03-16 |
| 38 | Build verification — 0 errors, 0 warnings | Done | 2026-03-16 |

**Missing Core Screens (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 39 | v2 DB migration: activeMode, situation, directiveSituation, noteSituation tables | Done | 2026-03-16 |
| 40 | New models: ActiveMode, Situation, DirectiveSituation, NoteSituation + through-associations on NotePage and Directive | Done | 2026-03-16 |
| 41 | View data structs: SituationListItem, ModeDetailData, HistoryMonthSummary | Done | 2026-03-16 |
| 42 | Sample data: 4 situations, directive-situation joins, note-situation joins, 2 active modes + seeder | Done | 2026-03-16 |
| 43 | SituationCell — shared cell for situation lists | Done | 2026-03-16 |
| 44 | SituationListViewController — searchable list with swipe-to-delete, ValueObservation | Done | 2026-03-16 |
| 45 | SituationDetailViewController — header + linked directives + linked notes sections | Done | 2026-03-16 |
| 46 | SituationEditorViewController — create/edit form (title + body) | Done | 2026-03-16 |
| 47 | SituationPickerViewController — searchable picker to link situations to directives or notes | Done | 2026-03-16 |
| 48 | NoteListViewController: Situations nav bar button (cloud.sun icon) | Done | 2026-03-16 |
| 49 | NotesCoordinator: full Situation routing (list → detail → editor) + SituationPicker | Done | 2026-03-16 |
| 50 | ModeDetailViewController — active toggle, linked directives + situations with link buttons | Done | 2026-03-16 |
| 51 | ActiveModePickerViewController — pick 1–3 active modes with checkmarks | Done | 2026-03-16 |
| 52 | LinkButtonCell — reusable "Link X" button cell for detail screens | Done | 2026-03-16 |
| 53 | FocusViewController: query updated to use activeMode join table; "Pick Modes" nav bar button | Done | 2026-03-16 |
| 54 | FocusCoordinator: mode detail routing + ActiveModePicker + SituationPicker + SituationEditor | Done | 2026-03-16 |
| 55 | NotesCoordinator + PlaybooksCoordinator: kind-check on note tap → ModeDetail for modes, NoteDetail for others | Done | 2026-03-16 |
| 56 | HistoryViewController — monthly summaries with avg rating, best/worst days, top tags | Done | 2026-03-16 |
| 57 | DiaryViewController: History nav bar button (chart.bar icon) | Done | 2026-03-16 |
| 58 | DiaryCoordinator: History routing | Done | 2026-03-16 |
| 59 | Build verification — 0 errors, 0 warnings | Done | 2026-03-16 |

**Onboarding + AI Signup (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 60 | AmbientParticleScene — SpriteKit scene with dual particle emitters (dust + slow orbs) | Done | 2026-03-17 |
| 61 | GlassPanelView — glassmorphism: UIVisualEffectView + frosted border gradient + pulsing glow | Done | 2026-03-17 |
| 62 | ThinkingAnimationView — 3-dot sequential pulse for AI thinking state | Done | 2026-03-17 |
| 63 | SeedPlanCardView — card with accent bar, icon, title, body for onboarding seed items | Done | 2026-03-17 |
| 64 | SeedPlanCard + SeedCardType data models + sample seed plan data | Done | 2026-03-17 |
| 65 | IntroPageViewController — 4 swipeable value-prop slides with spring animations, page dots, Skip | Done | 2026-03-17 |
| 66 | FocusConsoleViewController — SpriteKit particles + gradient sky + glass panel CTA + ambient drift | Done | 2026-03-17 |
| 67 | AISignupChatViewController — text input → thinking animation → seed cards stack in with stagger | Done | 2026-03-17 |
| 68 | SeedPlanReviewViewController — collection view of seed cards + bottom Confirm button | Done | 2026-03-17 |
| 69 | WelcomeViewController — celebration particles (2x intensity) + checkmark spring-in + auto-dismiss | Done | 2026-03-17 |
| 70 | OnboardingTransition — custom UIViewControllerAnimatedTransitioning (Crossfade, SlideUp, FlashBurst) | Done | 2026-03-17 |
| 71 | OnboardingCoordinator — manages full Intro → Console → AI Chat → Review → Welcome flow | Done | 2026-03-17 |
| 72 | AppCoordinator updated: gates on hasCompletedOnboarding, crossfade transition to main tab bar | Done | 2026-03-17 |
| 73 | Build verification — 0 errors, 0 warnings | Done | 2026-03-17 |

**Paywall, Subscription, Profile, Friends, Coach Marks (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 74 | Enums: SubscriptionPlan, FriendRequestStatus | Done | 2026-03-17 |
| 75 | View data: SubscriptionInfo, UsageQuota, UserProfile, FriendItem, PaywallFeature, CoachMark | Done | 2026-03-17 |
| 76 | Sample data: subscription, usage quota, profile, 4 friends, 7 paywall features, 4 coach marks | Done | 2026-03-17 |
| 77 | PaywallViewController — full-screen upgrade with crown hero, Free vs Pro comparison table, CTA, restore + legal links | Done | 2026-03-17 |
| 78 | SubscriptionViewController — settings sub-screen with plan badge, trial/quota details, manage actions | Done | 2026-03-17 |
| 79 | UsageLimitViewController — AI quota with big count, color-coded progress bar, reset time, 5-day history, upgrade prompt | Done | 2026-03-17 |
| 80 | ProfileViewController — avatar, name, plan badge, bio card, mood chips, action rows; works for self + friend views | Done | 2026-03-17 |
| 81 | FriendsListViewController — sectioned list (Pending Requests / Friends), swipe actions, empty state, add friend button | Done | 2026-03-17 |
| 82 | CoachMarkOverlayView — reusable overlay with dim, tooltip card, step counter, Next/Skip, spring animations | Done | 2026-03-17 |
| 83 | SettingsViewController: added Subscription, AI Usage, Friends, Replay Tour navigation items | Done | 2026-03-17 |
| 84 | SettingsCoordinator: full routing — Profile, Subscription, Usage, Friends, Friend Profile, Paywall (modal), Coach Mark tour | Done | 2026-03-17 |
| 85 | Build verification — 0 errors, 0 warnings | Done | 2026-03-17 |

**AI Panel (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 87 | Enums: ChipAction, ChipStatus | Done | 2026-03-17 |
| 88 | View data: AiChip, AiDraft | Done | 2026-03-17 |
| 89 | Sample data: 5 AI chips (create directive, update, activate mode, add schedule, create situation) + draft wrapper | Done | 2026-03-17 |
| 90 | AIPanelViewController — bottom sheet with text input, thinking animation, chip card list, quota display, empty-quota upgrade prompt, stagger-in animations | Done | 2026-03-17 |
| 91 | ChipConfirmViewController — pre-filled edit/confirm screen with action badge, title/body fields, Accept/Skip buttons | Done | 2026-03-17 |
| 92 | FocusViewController: wired FAB sparkle button → onAITapped callback | Done | 2026-03-17 |
| 93 | FocusCoordinator: presentAIPanel (medium/large sheet), presentChipConfirm, presentPaywall from AI panel | Done | 2026-03-17 |
| 94 | Build verification — 0 errors | Done | 2026-03-17 |

**Bug Fixes:**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 86 | IntroPageViewController: Get Started button pulse animation — added .allowUserInteraction so button is tappable during animation | Done | 2026-03-17 |

**Service Layer (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 95 | NoteService — CRUD, linkDirective/unlinkDirective, linkSituation/unlinkSituation, reorderDirectives, moveToFolder | Done | 2026-03-17 |
| 96 | DirectiveService — CRUD, graduate/retire/reactivate, pumpBalloon/shrinkBalloon, snooze/unsnooze, auto history tracking | Done | 2026-03-17 |
| 97 | FolderService — CRUD for playbooks | Done | 2026-03-17 |
| 98 | DayEntryService — createOrUpdate (upsert by date), delete, fetch by id/date | Done | 2026-03-17 |
| 99 | ScheduleService — createRule, deleteRule, markInstance, generateInstances (weekday/monthly rule matching) | Done | 2026-03-17 |
| 100 | SituationService — CRUD, linkDirective/unlinkDirective, linkNote/unlinkNote | Done | 2026-03-17 |
| 101 | ModeService — activate (enforces max 3), deactivate, deactivateAll, isActive | Done | 2026-03-17 |
| 102 | TagService — CRUD, findOrCreate, fetchAll | Done | 2026-03-17 |
| 103 | AppEnvironment: added all 8 services, private init wires them from DatabaseManager | Done | 2026-03-17 |
| 104 | Build verification — 0 errors | Done | 2026-03-17 |

**Networking + Sync Engine (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 105 | GRDB migration v3: OutboxOp, Tombstone, SyncState, Device tables | Done | 2026-03-17 |
| 106 | GRDB migration v4: added updatedByDeviceId to notePage, directive, dayEntry, situation | Done | 2026-03-17 |
| 107 | CoreModels: OutboxOp, Tombstone, SyncState (with singleton pattern), Device record types | Done | 2026-03-17 |
| 108 | ReachabilityMonitor — NWPathMonitor wrapper with Status struct, observer pattern, wifi/cellular/wired detection | Done | 2026-03-17 |
| 109 | APIClient — URLSession wrapper with auth headers (Bearer + X-API-Version + X-Device-Id), 401 token refresh interceptor, GET/POST/DELETE, 3-tier timeouts (15s/30s/60s), device ID persistence | Done | 2026-03-17 |
| 110 | SyncEngine — push/pull orchestration, outbox FIFO processing, enqueue/enqueueDelete helpers, pull pagination (200/page), version-based LWW conflict resolution, tombstone creation, auto-sync on connectivity change, DebugInfo for Sync Debug screen | Done | 2026-03-17 |
| 111 | Sync API types: PushRequest, PushResponse, PullResponse with ChangeEvent | Done | 2026-03-17 |
| 112 | AppEnvironment: added apiClient, syncEngine, reachability — all wired in private init | Done | 2026-03-17 |
| 113 | Build verification — 0 errors | Done | 2026-03-17 |

**Service Wiring + SampleData Removal (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 114 | SubscriptionVC: removed SampleData — injected subscriptionInfo + usageQuota from coordinator | Done | 2026-03-17 |
| 115 | UsageLimitVC: removed SampleData — injected quota + plan from coordinator | Done | 2026-03-17 |
| 116 | FriendsListVC: removed SampleData — injected friends array from coordinator | Done | 2026-03-17 |
| 117 | AIPanelVC: removed SampleData — injected initialQuota from coordinator | Done | 2026-03-17 |
| 118 | SyncDebugVC: wired to real SyncEngine.debugInfo() + Force Sync triggers syncEngine.sync() | Done | 2026-03-17 |
| 119 | NoteEditorVC: save now uses noteService.create/update (async) | Done | 2026-03-17 |
| 120 | DirectiveEditorVC: save now uses directiveService.create/update (with auto history) | Done | 2026-03-17 |
| 121 | PlaybookEditorVC: save now uses folderService.create/update | Done | 2026-03-17 |
| 122 | DayEntryEditorVC: save now uses dayEntryService.createOrUpdate (upsert) | Done | 2026-03-17 |
| 123 | SituationEditorVC: save now uses situationService.create/update | Done | 2026-03-17 |
| 124 | DirectivePickerVC: link now uses noteService.linkDirective | Done | 2026-03-17 |
| 125 | SituationPickerVC: link now uses situationService.linkDirective/linkNote | Done | 2026-03-17 |
| 126 | ActiveModePickerVC: toggle now uses modeService.activate/deactivate | Done | 2026-03-17 |
| 127 | All 5 coordinators updated to pass services to editors/pickers | Done | 2026-03-17 |
| 128 | Build verification — 0 errors | Done | 2026-03-17 |

**Legal Screens (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 129 | LegalViewController — scrollable sheet with styled headings, Terms of Service + Privacy Policy full text | Done | 2026-03-17 |
| 130 | SettingsViewController: added Terms of Service + Privacy Policy nav items in About section | Done | 2026-03-17 |
| 131 | SettingsCoordinator: showLegal(title:) presents sheet with grabber | Done | 2026-03-17 |
| 132 | Build verification — 0 errors | Done | 2026-03-17 |

**Voice Input (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 133 | VoiceInputButton — reusable tap-to-record mic button using SFSpeechRecognizer + AVAudioEngine, on-device transcription, pulsing red ring animation while recording, partial + final result callbacks, permission handling | Done | 2026-03-17 |
| 134 | AIPanelVC: mic button added between text field and send button, transcribes voice into text field | Done | 2026-03-17 |
| 135 | AISignupChatVC: mic button added inside input panel, transcribes voice into text view | Done | 2026-03-17 |
| 136 | Info.plist: NSMicrophoneUsageDescription + NSSpeechRecognitionUsageDescription | Done | 2026-03-17 |
| 137 | Build verification — 0 errors | Done | 2026-03-17 |

**Backend + Zod Validation (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 138 | Node.js backend: Fastify + Drizzle ORM + Postgres schema + Cognito auth middleware | Done | 2026-03-20 |
| 139 | DB queries layer: notes, directives, folders, dayEntries, tags, schedules, modes, links, sync, profiles, friends, devices, usage | Done | 2026-03-20 |
| 140 | Features layer: notes, directives, sync (push/pull + conflict resolution), friends, subscription, AI | Done | 2026-03-20 |
| 141 | Routes layer: all 16 route files with Zod validation on request bodies | Done | 2026-03-20 |
| 142 | Zod validation schemas: 13 files in src/validation/ — single source of truth for backend types | Done | 2026-03-20 |
| 143 | OpenAPI spec deleted — replaced by Zod schemas for validation | Done | 2026-03-20 |
| 144 | TypeScript build verification — 0 errors | Done | 2026-03-20 |

**UI Refinements (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 145 | DirectivePickerVC: renamed "Link Directive" → "Add Directive", added + button to create new directive inline | Done | 2026-03-20 |
| 146 | Focus: modes carousel — full-width paging, "No Mode" card, swipe to select, debounced mode change | Done | 2026-03-20 |
| 147 | Focus: mode selection animation — spring scale, color crossfade (CABasicAnimation for border), glow pulse, check badge, icon spin | Done | 2026-03-20 |
| 148 | Focus: directives section — shows linked directives for active mode, hidden when no mode | Done | 2026-03-20 |
| 149 | Focus: balloon condensing — 4 or fewer inline, 5+ collapses to "X balloons need attention" row with count badge | Done | 2026-03-20 |
| 150 | Focus: balloons sorted by liveRemainingSec (closest to expiry first), only <5h shown inline, badge counts <1h | Done | 2026-03-20 |
| 151 | Focus: section layout fix — uses snapshot section identifiers instead of raw index to prevent section mismatch | Done | 2026-03-20 |
| 152 | Focus: "See All" button on Modes header opens ActiveModePickerVC | Done | 2026-03-20 |
| 153 | ActiveModePickerVC: single-select with "No Mode" option, auto-dismisses on selection | Done | 2026-03-20 |
| 154 | Focus: carousel scrolls to new mode when changed externally (from picker) | Done | 2026-03-20 |
| 155 | Balloons screen: two sections — "Needs Attention" (<5h, full opacity) + "On Track" (5h+, grayed out 45%) | Done | 2026-03-20 |
| 156 | Diary: emoji rating picker (😣→🔥) replaces stepper, single-select with spring animation | Done | 2026-03-20 |
| 157 | Focus: modes header padding fix | Done | 2026-03-20 |

**Architecture Simplification (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 158 | Folder model: removed `intent`, added `parentFolderId` for nested folders | Done | 2026-03-21 |
| 159 | Notes tab: merged Playbooks into Notes — folder system with subfolders, "+" menu (New Note / New Folder) | Done | 2026-03-21 |
| 160 | Tab bar: 5 → 4 tabs (Focus, Notes, Diary, Settings) — Playbooks tab removed | Done | 2026-03-21 |
| 161 | Situations merged into NoteKind.situation — deleted Situation model, tables, service, 6 VCs | Done | 2026-03-21 |
| 162 | Backend updated: removed situation routes/queries/schema, updated folder schema for nesting | Done | 2026-03-21 |
| 163 | Build verification — 0 errors (iOS + TypeScript) | Done | 2026-03-21 |

**Tier Removal (completed):**

| Step | Description | Status | Date |
|------|-------------|--------|------|
| 164 | Removed Tier system (foundation/support/active), NoteEditor wizard now 3 steps, TierLabel deleted, kind colors added (blue/purple/gold/teal) | Done | 2026-03-22 |

**Later:**
- Background sync registration (`BGAppRefreshTask`)
- Keychain token storage (swap from UserDefaults stub)
- Offline banner UI component
