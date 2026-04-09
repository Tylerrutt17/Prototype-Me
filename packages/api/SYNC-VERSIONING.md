# Sync Versioning

## How it works

The sync system uses a version contract between the iOS client and the backend to ensure both sides agree on the sync payload format.

### Two sides of the contract

- **Client declares its version**: every sync request includes an `X-Sync-Version` header
- **Server enforces a minimum**: if the client's version is below `minSyncVersion`, the server returns `426 Upgrade Required`

```
Client: "I speak sync version 1"    -->  X-Sync-Version: 1
Server: "I require at least 1"      -->  200 OK (or 426 if too old)
```

### Where the version is defined

| Side    | File                                         | Field                  |
|---------|----------------------------------------------|------------------------|
| iOS     | `APIClient.swift` → `Config.syncVersion`     | Sent as header         |
| Backend | `config.ts` → `minSyncVersion`               | Checked on every sync route |

### What happens on version mismatch

1. iOS sends `X-Sync-Version: 1` with a sync request
2. Backend checks: `clientVersion < config.minSyncVersion`?
3. If yes: returns **426** with `{ error: "upgrade_required" }`
4. iOS `SyncEngine` catches the 426:
   - Stops the poll timer (no more retries)
   - Posts `Notification.Name.syncUpgradeRequired`
5. `AppCoordinator` presents `UpdateRequiredViewController` full-screen
6. User taps "Update Now" which opens the App Store

### When to bump the version

Bump the sync version when the **push/pull payload contract changes** in a way that old clients can't handle. Examples:

- Renaming a field in the sync payload (e.g. `entityType` -> `type`)
- Adding a required field that old clients don't send
- Changing the structure of `patch` JSON for an entity type
- Changing how the cursor/token works

**Don't bump** for:
- Adding a new optional field (old clients just won't send it)
- Adding a new entity type (old clients won't have ops for it)
- Backend-only changes (new queries, new indexes, etc.)

### How to bump

1. **Backend**: increment `minSyncVersion` in `packages/api/src/config.ts`
2. **iOS**: increment `syncVersion` in `APIClient.Config` (`APIClient.swift`)
3. **Tests**: run `npm test` in `packages/api/` — the sync version tests validate 426 behavior automatically

### Testing

**Backend** (`packages/api/`):
```bash
npm test
```
Tests in `src/__tests__/sync-version.test.ts` cover:
- Missing header -> 426
- Old version -> 426
- Invalid values -> 426
- Current version -> 200
- Future version -> 200 (forward-compatible)

**iOS** (Xcode):
- `Cmd+U` runs migration tests in `Prototype MeTests/MigrationTests.swift`
- These test that database schema migrations don't break existing user data
- The sync version enforcement itself is tested on the backend side

### Flow diagram

```
iOS App                          Backend
  |                                |
  |-- POST /v1/sync/push -------->|
  |   X-Sync-Version: 1           |
  |                                |-- clientVersion >= minSyncVersion?
  |                                |   YES: process normally, return 200
  |<-- 200 OK --------------------|
  |                                |
  |   (later, after server bumps   |
  |    minSyncVersion to 2)        |
  |                                |
  |-- POST /v1/sync/push -------->|
  |   X-Sync-Version: 1           |
  |                                |-- 1 < 2? YES: reject
  |<-- 426 Upgrade Required -------|
  |                                |
  |-- stops sync timer             |
  |-- shows "Update Required"      |
  |-- user updates app             |
  |                                |
  |-- POST /v1/sync/push -------->|
  |   X-Sync-Version: 2           |
  |                                |-- 2 >= 2? YES: process normally
  |<-- 200 OK --------------------|
```
