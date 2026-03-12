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

### 12) Modes + tiers

* **Mode** = `NotePage` with `kind = 'mode'`. Contains a short description + linked directives (some marked `micro`).
* **Framework note** = `NotePage` with `kind = 'framework'`. One allowed at a time; pinned to top of Notes list with confirm-before-edit protection.
* **Active Modes selection**: user picks 1–3 modes as "active" (stored as a lightweight local setting or metadata flag). Capped at 3 unless user changes a setting.
* **Tier** (`foundation` / `support` / `active`): displayed as a subtle label or accent color on notes and directives.
  * **Filtering**: Notes list and Focus panel can filter by tier (e.g., "show only Foundation + Support" for low-energy days).
  * **Sorting**: tier is a primary sort key (Foundation → Support → Active) with `sortIndex` as secondary.
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
| 10 | Shared views: StatusBadgeView, PressureIndicator, TierLabel, RatingCircleView | Done | 2026-03-11 |
| 11 | Shared cells: NoteCell, DirectiveCell, BalloonCard, DayEntryCell, ScheduleInstanceRowCell | Done | 2026-03-11 |
| 12 | List screens rewritten: NoteList, DirectiveList (with segmented filter), Diary, PlaybookList (with PlaybookCell), Balloons (2-col grid) — all UICollectionView + compositional layout + diffable data source | Done | 2026-03-11 |
| 13 | Detail screens rewritten: NoteDetail (header + linked directives), DirectiveDetail (header + balloon + schedule + history), PlaybookDetail (header + notes), Calendar (7-col grid with rating circles) | Done | 2026-03-11 |
| 14 | Focus screen rewritten: 3-section compositional layout (horizontal modes, 2-col balloons, vertical schedule) + floating AI button placeholder | Done | 2026-03-11 |
| 15 | Settings + SyncDebug rewritten: insetGrouped list with toggles/navigation/info rows | Done | 2026-03-11 |
| 16 | Coordinators updated: UUID-based closures (onNoteSelected(UUID), onDirectiveSelected(UUID), etc.), detail VCs accept entity IDs, full drill-down navigation | Done | 2026-03-11 |
| 17 | SectionHeaderView reusable supplementary view for multi-section screens | Done | 2026-03-11 |
| 18 | Build verification — 0 errors, 0 warnings | Done | 2026-03-11 |

**Later (after UI is solid):**
- GRDB integration (DatabaseManager, migrations, Record conformance)
- Service layer (NoteService, DirectiveService, etc.)
- Wire ValueObservation into screens (replace SampleData calls)
- OpenAPI codegen + networking
- Sync engine
