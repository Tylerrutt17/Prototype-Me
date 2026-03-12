## Backend infrastructure outline

See also: `frontend-outline.md` for client-side setup and sync wiring.

### 1) Architecture overview

* **Backend**: Node.js + TypeScript + Express API.
* **Database**: Postgres system of record.
* **Sync**: push outbox ops + pull change feed cursor.
* **Storage**: blob store for snapshots (playbook/snapshots export).
* **Hosting**: AWS.
* **ORM/Migrations**: Drizzle.

---

### 2) Data model (core entities)

**Conventions (applies to all entities)**

* `id`: **UUIDv7** (sortable by creation time, avoids sync collisions, safe for offline creation).
* `createdAt`, `updatedAt`: ISO timestamp (or epoch ms).
* `updatedByDeviceId`: string (required for deterministic LWW conflict resolution).
* `version: Int`: monotonic version counter, incremented on every mutation. Sync conflict resolution uses highest version wins.
* `metadata: JSON | null`: optional JSONB column for experimentation, AI flags, new features, A/B tests. Avoids migrations for small additions.
* **Tombstone deletion**: deletions use a separate **`Tombstone`** table (not `deletedAt` on every entity). Main tables stay clean; sync queries one table for all pending deletes. Do not hard-delete locally until server ack + compaction.

**`NotePage`**

* `id: uuid`
* `folderId: uuid | null`
* `title: string`
* `body: string | richtext-blob`
* `kind: 'note' | 'mode' | 'framework'`
* `tier: 'foundation' | 'support' | 'active'` (default `'support'`)
* `pinned: boolean`
* `sortIndex: number`
* `conflictParentId: uuid | null`
* `conflictReason: 'body_concurrent_edit' | 'other' | null`

**`Directive`**

* `id: uuid`
* `title: string`
* `description: string` (long-form body text)
* `status: 'active' | 'maintained' | 'retired'`
* `snoozedUntil: timestamp | null`
* `micro: boolean`
* `priority: 0 | 1 | 2 | 3 | null`
* `color: string | null`
* `lastEngagedAt: timestamp | null`

**`NoteDirective`**

* `id: uuid`
* `noteId: uuid`
* `directiveId: uuid`
* `sortIndex: number`
* `pinned: boolean | null`
* `collapsed: boolean | null`
* `createdAt`, `updatedAt`

**`ScheduleRule`**

* `id: uuid`
* `directiveId: uuid`
* `ruleType: 'weekly' | 'monthly' | 'one-off'`
* `params: JSON` (days, dates, etc.)
* `timezone: string`
* `targetSurface: 'daily_note' | 'focus' | 'both'`
* `version: Int`
* `createdAt`, `updatedAt`

**`ScheduleInstance`**

* `id: uuid`
* `directiveId: uuid`
* `date: yyyy-mm-dd`
* `status: 'pending' | 'done' | 'skipped'`
* `sourceRuleVersion: Int` (links to the rule version that generated it; rule edits can invalidate stale instances)
* `createdAt`, `updatedAt`

**`AudioAttachment`** (voice memos on directives)

* `id: uuid`
* `directiveId: uuid`
* `storageKey: string` (S3 key)
* `durationSec: number | null`
* `transcript: string | null`
* `createdAt`, `updatedAt`

**`Balloon`** (fields on `Directive`)

* `balloonEnabled: boolean`
* `balloonPressure: 'low' | 'medium' | 'high'` (or 0–2)
* `balloonDurationSec: number`
* `balloonState: 'idle' | 'running' | 'paused'`
* `balloonStartedAt: timestamp | null`
* `balloonRemainingSec: number | null`

**`Folder`**

* `id: uuid`
* `parentId: uuid | null`
* `name: string`
* `color: string | null`
* `sortIndex: number`
* `isPlaybook: boolean | null`

**`Tag`**

* `id: uuid`
* `name: string`
* `color: string | null`

**`NoteTag`**

* `id: uuid`
* `noteId: uuid`
* `tagId: uuid`
* `createdAt`, `updatedAt`

**`Situation`**

* `id: uuid`
* `name: string`
* `icon: string | null`

**`DirectiveSituation`**

* `id: uuid`
* `directiveId: uuid`
* `situationId: uuid`
* `createdAt`, `updatedAt`

**`DayEntry`**

* `id: uuid`
* `date: yyyy-mm-dd` (local day key; one entry per day)
* `rating: number | null` (1–10)
* `diary: string` (free text; can be empty)
* `tags: string[]` (optional quick labels)
* `createdAt`, `updatedAt`

**`Snapshot`**

* `id: uuid`
* `scope: 'note' | 'directive_set' | 'playbook'`
* `title: string | null`
* `sourceIds: uuid[]`
* `snapshotRef: string`
* `schemaVersion: number` (ensures old snapshots remain readable as schema evolves)
* `createdAt`, `updatedAt`

**`ShareLink`**

* `id: uuid`
* `scope: 'note' | 'directive_set' | 'playbook'`
* `sourceIds: uuid[]`
* `permission: 'view' | 'edit'`
* `expiresAt: timestamp | null`
* `createdAt`, `updatedAt`

**`AccessGrant`**

* `id: uuid`
* `targetUserId: uuid`
* `scope: 'note' | 'directive_set' | 'playbook'`
* `sourceIds: uuid[]`
* `permission: 'view' | 'edit'`
* `createdAt`, `updatedAt`

**`FriendRequest`**

* `id: uuid`
* `fromUserId: uuid`
* `toUserId: uuid`
* `status: 'pending' | 'accepted' | 'declined' | 'canceled'`
* `createdAt`, `updatedAt`

**`Friend`**

* `id: uuid`
* `userId: uuid`
* `friendUserId: uuid`
* `createdAt`, `updatedAt`

**`DirectiveHistory`** (append-only audit log)

* `id: uuid`
* `directiveId: uuid`
* `action: string` (e.g., 'created', 'updated', 'shrunk', 'split', 'graduated', 'ballooned')
* `payload: JSON` (snapshot of changed fields)
* `createdAt: timestamp`
* `deviceId: string`
* Used for: undo, analytics, AI context, and audit trail.
* Add from day one — much harder to retrofit later.

**`UserSignal`** (background knobs / tuning state)

* `id: uuid`
* `userId: uuid`
* `key: string` (e.g., `theme.sleep`, `directive.abc.relevance`, `pref.tiny_actions`)
* `value: number`
* `updatedAt: timestamp`
* Avoids schema churn — new signal types don't require migrations.
* Synced as lightweight key-value pairs.

**`UsageMetric`** (analytics — add from day one)

* `id: uuid`
* `userId: uuid`
* `metric: string` (enum-like key: `directives_created`, `notes_created`, `ai_actions`, `balloons_enabled`, `playbooks_forked`, `sync_events`, `diary_entries_written`, `schedule_rules_created`)
* `value: number` (count, duration, etc.)
* `createdAt: timestamp`
* Append-only — one row per event, not an upsert counter.
* Written locally first; synced to backend when online.

**`Tombstone`** (sync deletions)

* `id: uuid`
* `entityType: string`
* `entityId: uuid`
* `deletedAt: timestamp`
* `updatedAt: timestamp`
* `deviceId: string`
* Keeps main tables clean (no `deletedAt` on every entity).
* Server compaction: delete tombstones older than 30 days after confirmation.

**`SyncState`** (client-side, single-row table)

* `lastSyncToken: string`
* `lastPushAt: timestamp | null`
* `lastPullAt: timestamp | null`
* `deviceId: string`

---

### 3) Sync protocol

**Outbox operation (`OutboxOp`)**

* `id: uuid`
* `entityType: 'note' | 'directive' | 'noteDirective' | 'scheduleRule' | 'scheduleInstance' | 'audioAttachment' | 'snapshot' | 'shareLink' | 'accessGrant' | 'friendRequest' | 'friend' | 'folder' | 'tag' | 'situation' | 'noteTag' | 'tombstone' | 'directiveHistory' | 'userSignal' | 'usageMetric' | ...`
* `entityId: uuid`
* `op: 'create' | 'update' | 'delete'`
* `patch: object`
* `baseUpdatedAt: timestamp | null`
* `schemaVersion: number` (prevents decoding errors when old queued ops replay after an app update)
* `createdAt: timestamp`
* `attemptCount: number`
* `lastError: string | null`

**Pull cursor**

* `lastSyncToken: string`

**Server change feed item (`ChangeEvent`)**

* `token: string`
* `entityType: string`
* `entityId: uuid`
* `operation: 'create' | 'update' | 'delete'`
* `payload: object | null`
* `version: Int`
* `updatedAt: timestamp`
* `updatedByDeviceId: string`

**Push**

* Client sends ordered `OutboxOp[]` + `deviceId` + `lastSyncToken`.
* Server applies ops idempotently and returns updated records + new token.

**Pull**

* Client requests changes since `lastSyncToken`.
* Server returns `ChangeEvent[]` + `nextToken` until empty.

**Conflict rule**

* **Version-based resolution**: highest `version` wins; `(updatedAt, updatedByDeviceId)` as tiebreaker.
* Note body conflicts create a conflict copy for manual resolution.

**API examples**

`POST /sync/push`

Request:
```
{
  "deviceId": "device-123",
  "lastSyncToken": "token-100",
  "ops": [
    {
      "id": "op-1",
      "entityType": "note",
      "entityId": "note-1",
      "op": "update",
      "patch": { "title": "Updated title" },
      "baseUpdatedAt": "2026-02-01T12:00:00Z",
      "schemaVersion": 1,
      "createdAt": "2026-02-01T12:01:00Z"
    }
  ]
}
```

Response:
```
{
  "applied": [
    {
      "entityType": "note",
      "entityId": "note-1",
      "record": { "id": "note-1", "title": "Updated title", "updatedAt": "2026-02-01T12:01:05Z" }
    }
  ],
  "lastSyncToken": "token-101"
}
```

`GET /sync/pull?cursor=token-101`

Response:
```
{
  "events": [
    {
      "token": "token-102",
      "entityType": "directive",
      "entityId": "dir-1",
      "operation": "update",
      "payload": { "id": "dir-1", "title": "Drink water", "updatedAt": "2026-02-01T12:05:00Z" },
      "version": 3,
      "updatedAt": "2026-02-01T12:05:00Z",
      "updatedByDeviceId": "device-456"
    }
  ],
  "nextToken": "token-102"
}
```

**Database indexes (Postgres — add from day one)**

* `Directive`: `balloonEnabled`, `updatedAt`, `status`
* `NoteDirective`: `noteId`, `directiveId`
* `ScheduleRule`: `directiveId`
* `ScheduleInstance`: `date`, `directiveId`, `status`
* `OutboxOp`: `createdAt` (process in order)
* `Tombstone`: `entityType`, `entityId`
* `UsageMetric`: `userId`, `metric`, `createdAt`
* `DirectiveHistory`: `directiveId`, `createdAt`

---

### 4) Routes (HTTP API)

**Conventions**

* Each route has a **route file** and a **validation file**.
* Route handlers are thin; business logic lives in `services/`.
* Validation runs before hitting services; reject invalid payloads early.

**Auth**

* `POST /auth/anonymous`
* `POST /auth/login`
* `POST /auth/link`
* `POST /auth/refresh`

**Sync**

* `POST /sync/push`
* `GET /sync/pull?cursor=...`

**Playbooks**

* `POST /playbooks/publish`
* `GET /playbooks/:id`
* `GET /playbooks/:id/versions`
* `POST /playbooks/:id/fork`

**Sharing**

* `POST /share-links`
* `POST /share-links/:id/revoke`
* `POST /access-grants`
* `POST /access-grants/:id/revoke`

---

### 5) Community playbooks (publish/fork/version)

**Key idea**

* A **published playbook** is a stable container.
* A **version** is an immutable snapshot of a folder + its contents at a point in time.
* A **fork** is a local import that preserves lineage metadata.

**Server entities (phase 2+)**

**`PublishedPlaybook`**

* `id: uuid`
* `ownerUserId: uuid`
* `slug: string` (stable URL id; optional)
* `title: string`
* `description: string`
* `visibility: 'private' | 'unlisted' | 'public'` (start with `unlisted`)
* `createdAt`, `updatedAt`
* `latestVersionId: uuid | null`
* `tags: string[]` (server-side for discovery; not the same as in-app tags)
* `license: 'all_rights_reserved' | 'cc_by' | 'cc_by_sa' | 'cc0' | 'custom'`
* `moderationStatus: 'ok' | 'flagged' | 'removed'`

**`PlaybookVersion`**

* `id: uuid`
* `publishedPlaybookId: uuid`
* `versionNumber: integer` (or semver string)
* `title: string` (optional “v2 — lighter daily routine”)
* `changelog: string | null`
* `createdAt`
* `createdByUserId: uuid`
* `parentVersionId: uuid | null` (for lineage; supports “fork publish”)
* `diffSummary: object | null` (precomputed: counts of notes/directives changes)
* `snapshotRef: string` (pointer to stored snapshot blob/object storage key)

**`PlaybookSnapshot` (stored as a blob; immutable)**

Keep this as a single JSON document initially to avoid complex relational reconstruction:

* `schemaVersion: number`
* `exportedAt: timestamp`
* `source`:
  * `publishedPlaybookId`, `versionId`, `ownerUserId`
* `folder`: serialized folder metadata (name, color, etc.)
* `notes[]`: serialized notes (including `kind`, `tier`, `sortIndex`, etc.)
* `directives[]`: serialized directives (including balloon fields, status, sortIndex, etc.)
* `joins[]`: optional joins (noteTags, directiveSituations)

**Local lineage fields (on imported/forked content)**

* On local `Folder` (and optionally on each Note):
  * `originPublishedPlaybookId: uuid | null`
  * `originVersionId: uuid | null`
  * `forkedFromVersionId: uuid | null`
* Optional: `importedAt`, `importedByUserId` (if user identity exists locally)

**Rollout recommendation**

* **V1 (fast + safe): Export/Import bundles**
  * Export snapshot JSON to file/share sheet; import creates local folder + notes + directives.
  * No accounts, no browsing, no moderation required.
* **V2: Unlisted publish + version history**
  * Auth required; publish snapshot to server; share link; import via link.
  * Still no feed/search required.
* **V3: Public browse + fork**
  * Add discovery/search, tagging, moderation, reporting, and basic creator attribution pages.

---

### 6) Identity + auth (minimal, offline-first, community-ready)

Goal: support **multi-device sync** and later **publishing** without forcing accounts on day 1.

**Principles**

* The app works fully **anonymous/local-first**.
* Sync + publish require an identity, but that identity can start as a lightweight account.
* Device identity is always present (`deviceId`) for sync debugging and LWW reasoning.

**Local**

* `deviceId: string` (generated once, stored securely)
* `installId: string` (optional; for analytics/diagnostics)
* `authState`:
  * `mode: 'anonymous' | 'signed_in'`
  * `userId: uuid | null`
  * `accessToken: string | null`
  * `refreshToken: string | null`
  * `expiresAt: timestamp | null`

**Server**

**`User`**

* `id: uuid`
* `handle: string | null` (for community; optional initially)
* `email: string | null` (only if using email login)
* `displayName: string | null`
* `bio: string | null`
* `avatarUrl: string | null`
* `moodTags: string[] | null` (optional public chips)
* `profileVisibility: 'private' | 'public' | 'friends'`
* `plan: 'free' | 'pro'`
* `subscriptionStatus: 'none' | 'trialing' | 'active' | 'past_due' | 'canceled'`
* `subscriptionProvider: 'app_store' | 'stripe' | null`
* `currentPeriodEnd: timestamp | null`
* `trialEndsAt: timestamp | null`
* `createdAt`, `updatedAt`
* `status: 'active' | 'disabled'`

**`Device`**

* `id: uuid`
* `userId: uuid`
* `deviceId: string` (from client; unique per install)
* `label: string | null` (“Tyler’s iPhone”)
* `createdAt`, `lastSeenAt`

**Auth**

* Token-based auth (access + refresh) is simplest for native iOS clients.
* Endpoints:
  * `POST /auth/anonymous` → creates user + returns tokens (optional v1)
  * `POST /auth/login` / `POST /auth/link` → upgrades anonymous to email/OAuth
  * `POST /auth/refresh` → rotates access token
* Sync endpoints (`push`/`pull`) require `Authorization: Bearer <token>`.
* Subscriptions: verify via **App Store Server Notifications V2** (or App Store Server API) to update `User.plan` + status.

**Entitlements / feature gating**

* Enforce plan checks on the server for AI requests, sync, sharing, and publish/fork.
* Free plan can allow a small AI quota; reject/soft-limit after quota is reached.
* Prefer server as source of truth; client may hide UI but must not be trusted.
* Consider returning remaining AI quota + next reset time in API responses.

**Account linking (important for product)**

* If user starts anonymous and later signs in, provide “**Link this device’s data**” flow:
  * server either accepts the current user as canonical, or merges by creating a new “account-owned” namespace.
  * keep it simple: one account owns one dataset; if conflict, require explicit choice (don’t auto-merge silently).

---

### 7) AI provider + implementation requirements

**Provider**

* OpenAI API with server-side key management.
* Client never talks to OpenAI directly; backend proxies requests.

**Core AI data models**

**`AiDraft`** (stored draft suggestions)

* `id: uuid`
* `userId: uuid`
* `sourceType: 'voice' | 'text' | 'import' | 'batch'`
* `inputText: string`
* `suggestions: object[]` (typed per chip)
* `status: 'pending' | 'accepted' | 'dismissed' | 'expired'`
* `createdAt`, `updatedAt`

**`AiSignal`** (deprecated — use `UserSignal` in §2 instead)

Note: the `UserSignal` table (§2) is the canonical store for all background knobs and tuning signals. `AiSignal` is kept here for reference but should not be implemented separately.

**`AiRunLog`** (optional, for debugging + cost)

* `id: uuid`
* `userId: uuid`
* `model: string`
* `tokenCount: number | null`
* `latencyMs: number | null`
* `purpose: 'chips' | 'rewrite' | 'summarize' | 'route'`
* `createdAt`

**AI request pipeline**

* Build a **context bundle** (recent notes, linked directives, situations, recent diary).
* Run a routing prompt to select the best chips.
* Generate draft output; save as `AiDraft`.
* Present chips in UI; apply only after user confirms.

**Safety + controls**

* Rate limits per user + daily caps.
* Redact sensitive fields before logging.
* No cross-user data mixing; only user-owned context.

---

### 8) Backend infrastructure setup checklist

**Backend**

* API stack: Node.js + TypeScript + Express + middleware.
* Define Postgres migrations for all core entities.
* Set up blob storage for snapshots (S3 or compatible).
* Add auth middleware + token issuance endpoints.

**Sync**

* Implement `/sync/push` + `/sync/pull`.
* Ensure idempotency by `OutboxOp.id`.
* Add retry/backoff and server-side logging for failed ops.
* Add tombstone compaction job (server + client).

**Identity**

* Anonymous auth + device registration.
* Account linking flow (anonymous → signed-in).
* Refresh token rotation and revocation.

**Observability**

* Structured logging with request IDs.
* Error tracking (Sentry).
* Metrics for sync latency + error rates.

**Deployment**

* Hosting on AWS (e.g., ECS/EC2/Lambda + RDS + S3 + ALB + VPC).
* CI/CD for tests + migrations.
* Secrets management (env vars or secret manager).

**Caching**

* Use **Valkey** (Redis-compatible) via AWS ElastiCache.
* Primary uses: auth/session tokens, rate limits, sync cursors, and hot lookups.
* Postgres (RDS) remains the system of record; cache is optional and disposable.

---

### 9) Local dev environment

* Use Docker Compose to run Postgres + Valkey locally.
* Provide `.env.example` with DB/Redis connection strings.
* One command to boot local infra (e.g., `docker compose up -d`).
