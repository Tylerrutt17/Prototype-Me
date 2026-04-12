import Foundation
import GRDB

// MARK: - NotePage

nonisolated struct NotePage: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "notePage"

    let id: UUID
    var title: String
    var body: String              // Markdown
    var kind: NoteKind
    var folderId: UUID?
    var sortIndex: Int
    var version: Int
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NotePage, rhs: NotePage) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let folder = belongsTo(Folder.self, using: ForeignKey(["folderId"]))
    static let noteDirectives = hasMany(NoteDirective.self)
    static let directives = hasMany(Directive.self, through: noteDirectives, using: NoteDirective.directive)
    static let activeMode = hasOne(ActiveMode.self, using: ForeignKey(["noteId"]))

    // MARK: - Codable (custom — encode Optionals as null so sync patches clear fields)

    private enum CodingKeys: String, CodingKey {
        case id, title, body, kind, folderId, sortIndex, version, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(kind, forKey: .kind)
        try c.encode(folderId, forKey: .folderId)
        try c.encode(sortIndex, forKey: .sortIndex)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - ActiveMode

nonisolated struct ActiveMode: Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "activeMode"

    let noteId: UUID
    let activatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(noteId) }
    static func == (lhs: ActiveMode, rhs: ActiveMode) -> Bool { lhs.noteId == rhs.noteId }

    // MARK: Associations
    static let note = belongsTo(NotePage.self, using: ForeignKey(["noteId"]))
}

// MARK: - Directive

nonisolated struct Directive: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "directive"

    let id: UUID
    var title: String
    var body: String?             // Optional longer description
    var color: String?            // User-chosen hex color, e.g. "#FF6B6B"
    var status: DirectiveStatus
    var balloonEnabled: Bool
    var balloonDurationSec: TimeInterval   // Original duration in seconds
    var balloonSnapshotSec: TimeInterval  // Current countdown
    var snoozedUntil: Date?
    var version: Int
    let createdAt: Date
    var updatedAt: Date

    /// Live remaining time, computed from stored snapshot + elapsed wall-clock time.
    /// `balloonSnapshotSec` is the snapshot at `updatedAt`; we subtract elapsed since then.
    var liveRemainingSec: TimeInterval {
        guard balloonEnabled, balloonDurationSec > 0 else { return 0 }
        let elapsed = Date.now.timeIntervalSince(updatedAt)
        return max(0, balloonSnapshotSec - elapsed)
    }

    // Derived pressure level (not stored in DB)
    var pressureLevel: PressureLevel? {
        guard balloonEnabled, balloonDurationSec > 0 else { return nil }
        let hours = liveRemainingSec / 3600
        if hours >= 12 { return .green }
        if hours >= 4 { return .yellow }
        return .red
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Directive, rhs: Directive) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let noteDirectives = hasMany(NoteDirective.self)
    static let notes = hasMany(NotePage.self, through: noteDirectives, using: NoteDirective.note)
    static let scheduleRules = hasMany(ScheduleRule.self)
    static let history = hasMany(DirectiveHistory.self)

    // MARK: - Codable (custom — encode Optionals as null instead of omitting, so
    // sync patches properly clear fields like `body` and `snoozedUntil`)

    private enum CodingKeys: String, CodingKey {
        case id, title, body, color, status, balloonEnabled, balloonDurationSec, balloonSnapshotSec, snoozedUntil, version, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(body, forKey: .body)
        try c.encode(color, forKey: .color)
        try c.encode(status, forKey: .status)
        try c.encode(balloonEnabled, forKey: .balloonEnabled)
        try c.encode(balloonDurationSec, forKey: .balloonDurationSec)
        try c.encode(balloonSnapshotSec, forKey: .balloonSnapshotSec)
        try c.encode(snoozedUntil, forKey: .snoozedUntil)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - NoteDirective (join)

nonisolated struct NoteDirective: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "noteDirective"

    var id: String { "\(noteId)-\(directiveId)" }
    let noteId: UUID
    let directiveId: UUID
    var sortIndex: Int
    var createdAt: Date = Date()

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NoteDirective, rhs: NoteDirective) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let note = belongsTo(NotePage.self, using: ForeignKey(["noteId"]))
    static let directive = belongsTo(Directive.self, using: ForeignKey(["directiveId"]))

    // Computed `id` should not be persisted
    private enum CodingKeys: String, CodingKey {
        case noteId, directiveId, sortIndex, createdAt
    }
}

// MARK: - Folder

nonisolated struct Folder: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "folder"

    let id: UUID
    var name: String
    var parentFolderId: UUID?
    var sortIndex: Int
    var version: Int = 1
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Folder, rhs: Folder) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let notes = hasMany(NotePage.self, using: ForeignKey(["folderId"]))
    static let subfolders = hasMany(Folder.self, using: ForeignKey(["parentFolderId"]))
    static let parentFolder = belongsTo(Folder.self, using: ForeignKey(["parentFolderId"]))

    // MARK: - Codable (custom — encode Optionals as null so sync patches clear fields)

    private enum CodingKeys: String, CodingKey {
        case id, name, parentFolderId, sortIndex, version, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(parentFolderId, forKey: .parentFolderId)
        try c.encode(sortIndex, forKey: .sortIndex)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - DayEntry

nonisolated struct DayEntry: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "dayEntry"

    let id: UUID
    var date: String              // yyyy-MM-dd
    var rating: Int?              // 1–10
    var diary: String
    var tags: [String]
    var version: Int = 1
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DayEntry, rhs: DayEntry) -> Bool { lhs.id == rhs.id }

    // MARK: Custom encoding — tags stored as JSON column "tagsJSON"

    init(id: UUID, date: String, rating: Int?, diary: String, tags: [String], version: Int = 1, createdAt: Date, updatedAt: Date) {
        self.id = id; self.date = date; self.rating = rating
        self.diary = diary; self.tags = tags; self.version = version
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    init(row: Row) {
        id = row["id"]
        date = row["date"]
        rating = row["rating"]
        diary = row["diary"]
        version = row["version"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]

        let jsonString: String = row["tagsJSON"]
        if let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            tags = decoded
        } else {
            tags = []
        }
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["date"] = date
        container["rating"] = rating
        container["diary"] = diary
        container["version"] = version
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt

        if let data = try? JSONEncoder().encode(tags),
           let json = String(data: data, encoding: .utf8) {
            container["tagsJSON"] = json
        } else {
            container["tagsJSON"] = "[]"
        }
    }

    // MARK: - Codable (custom — encode `rating` as null when nil so sync patches clear it)

    private enum CodingKeys: String, CodingKey {
        case id, date, rating, diary, tags, version, createdAt, updatedAt
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(rating, forKey: .rating)
        try c.encode(diary, forKey: .diary)
        try c.encode(tags, forKey: .tags)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - ScheduleRule

nonisolated struct ScheduleRule: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "scheduleRule"

    let id: UUID
    let directiveId: UUID
    var ruleType: ScheduleType
    var params: [String: [Int]]   // e.g. { "days": [1,3,5] }
    var version: Int = 1
    let createdAt: Date
    var updatedAt: Date = Date()
    var lastCompletedDate: String? // yyyy-MM-dd — nil means never completed

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ScheduleRule, rhs: ScheduleRule) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let directive = belongsTo(Directive.self)

    // MARK: Custom encoding — params stored as JSON column "paramsJSON"

    init(id: UUID, directiveId: UUID, ruleType: ScheduleType, params: [String: [Int]], version: Int = 1, createdAt: Date, updatedAt: Date? = nil, lastCompletedDate: String? = nil) {
        self.id = id; self.directiveId = directiveId
        self.ruleType = ruleType; self.params = params; self.version = version
        self.createdAt = createdAt; self.updatedAt = updatedAt ?? createdAt
        self.lastCompletedDate = lastCompletedDate
    }

    init(row: Row) {
        id = row["id"]
        directiveId = row["directiveId"]
        ruleType = ScheduleType(rawValue: row["ruleType"]) ?? .weekly
        version = row["version"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
        lastCompletedDate = row["lastCompletedDate"]

        let jsonString: String = row["paramsJSON"]
        if let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            params = decoded
        } else {
            params = [:]
        }
    }

    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["directiveId"] = directiveId
        container["ruleType"] = ruleType.rawValue
        container["version"] = version
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
        container["lastCompletedDate"] = lastCompletedDate

        if let data = try? JSONEncoder().encode(params),
           let json = String(data: data, encoding: .utf8) {
            container["paramsJSON"] = json
        } else {
            container["paramsJSON"] = "{}"
        }
    }

    // MARK: - Codable (custom — use encode not encodeIfPresent for Optionals so
    // the server gets explicit nulls for cleared fields like lastCompletedDate)

    private enum CodingKeys: String, CodingKey {
        case id, directiveId, ruleType, params, version, createdAt, updatedAt, lastCompletedDate
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(directiveId, forKey: .directiveId)
        try c.encode(ruleType, forKey: .ruleType)
        try c.encode(params, forKey: .params)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(lastCompletedDate, forKey: .lastCompletedDate)
    }

    // MARK: - Today Matching

    /// Returns true if this rule applies to today's date.
    static func ruleMatchesToday(_ rule: ScheduleRule) -> Bool {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let dayOfMonth = cal.component(.day, from: today)
        let year = cal.component(.year, from: today)
        let month = cal.component(.month, from: today)

        if let weekdays = rule.params["weekdays"] ?? (rule.ruleType == .weekly ? rule.params["days"] : nil) {
            if weekdays.contains(weekday) { return true }
        }
        if let monthDays = rule.params["monthDays"] {
            if monthDays.contains(dayOfMonth) { return true }
        }
        if let flat = rule.params["oneOffs"], flat.count >= 3 {
            for i in stride(from: 0, to: flat.count - 2, by: 3) {
                if flat[i] == year && flat[i+1] == month && flat[i+2] == dayOfMonth { return true }
            }
        }
        return false
    }
}

// MARK: - Tag

nonisolated struct Tag: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tag"

    let id: UUID
    var name: String
    var color: String?            // hex, e.g. "#FF6B6B"
    var version: Int = 1

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Tag, rhs: Tag) -> Bool { lhs.id == rhs.id }

    // MARK: - Codable (custom — encode `color` as null when nil so sync patches clear it)

    private enum CodingKeys: String, CodingKey {
        case id, name, color, version
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(color, forKey: .color)
        try c.encode(version, forKey: .version)
    }
}

// MARK: - DirectiveHistory

nonisolated struct DirectiveHistory: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "directiveHistory"

    let id: UUID
    let directiveId: UUID
    var action: DirectiveHistoryAction
    var payload: String           // JSON string for flexibility
    let createdAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DirectiveHistory, rhs: DirectiveHistory) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let directive = belongsTo(Directive.self)
}

// MARK: - SpeakHistoryRecord
// Flat GRDB-persisted form of SpeakHistoryEntry (local-only, not synced).
// Before-state is JSON-encoded; the service layer handles conversion.

nonisolated struct SpeakHistoryRecord: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "speakHistory"

    let id: UUID
    let timestamp: Date
    var actionType: String      // "create"|"update"|"retire"|"activate"|"deactivate"
    var entityType: String      // "directive"|"note"|"journal"|"folder"|"mode"
    var entityId: String        // UUID string, or yyyy-MM-dd for journal
    var itemName: String
    var beforeJSON: String?     // JSON snapshot, nil for creates

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SpeakHistoryRecord, rhs: SpeakHistoryRecord) -> Bool { lhs.id == rhs.id }
}

// MARK: - OutboxOp

nonisolated struct OutboxOp: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "outboxOp"

    let id: UUID
    var entityType: String
    var entityId: String
    var op: String               // "create" | "update" | "delete"
    var patch: String            // JSON payload
    var baseUpdatedAt: Date?
    var schemaVersion: Int
    let createdAt: Date
    var attemptCount: Int
    var lastError: String?
    var nextRetryAt: Date?       // nil = eligible immediately; otherwise defer until this time

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: OutboxOp, rhs: OutboxOp) -> Bool { lhs.id == rhs.id }
}

// MARK: - Tombstone

nonisolated struct Tombstone: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tombstone"

    let id: UUID
    var entityType: String
    var entityId: String
    var deletedAt: Date
    var updatedAt: Date
    var deviceId: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Tombstone, rhs: Tombstone) -> Bool { lhs.id == rhs.id }
}

// MARK: - SyncState

nonisolated struct SyncState: Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "syncState"

    let id: String               // Always "singleton"
    var lastSyncToken: String?
    var lastPushAt: Date?
    var lastPullAt: Date?
    var deviceId: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: SyncState, rhs: SyncState) -> Bool { lhs.id == rhs.id }

    static let singletonId = "singleton"

    static func current(in db: Database) throws -> SyncState? {
        try SyncState.fetchOne(db, key: singletonId)
    }
}

// MARK: - Device

nonisolated struct Device: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "device"

    let id: UUID
    var name: String
    var platform: String
    let createdAt: Date
    var lastSeenAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Device, rhs: Device) -> Bool { lhs.id == rhs.id }
}

// MARK: - Sync Helpers

private let _syncEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}()

extension Encodable {
    /// Serialize to JSON string for outbox patch payload.
    func syncPatch() -> String {
        guard let data = try? _syncEncoder.encode(self),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }
}

extension OutboxOp {

    /// Find an existing pending outbox op for the same entity.
    private static func findPending(entityType: String, entityId: String, in db: Database) throws -> OutboxOp? {
        try OutboxOp
            .filter(Column("entityType") == entityType && Column("entityId") == entityId)
            .order(Column("createdAt").desc)
            .fetchOne(db)
    }

    /// Enqueue a create/update sync operation inside an existing database transaction.
    /// Coalesces with any pending op for the same entity to keep the outbox minimal.
    @discardableResult
    static func enqueue(
        entityType: String,
        entityId: String,
        op: String,
        patch: String = "{}",
        baseUpdatedAt: Date? = nil,
        in db: Database
    ) throws -> OutboxOp {
        if let existing = try findPending(entityType: entityType, entityId: entityId, in: db) {
            switch (existing.op, op) {

            // Pending delete + new create → entity exists on server, treat as update
            case ("delete", "create"):
                try existing.delete(db)
                // Remove the tombstone that was created with the delete
                try Tombstone
                    .filter(Column("entityType") == entityType && Column("entityId") == entityId)
                    .deleteAll(db)
                return try insertOp(entityType: entityType, entityId: entityId, op: "update", patch: patch, baseUpdatedAt: baseUpdatedAt, in: db)

            // Pending create + new update → keep as create with latest patch
            case ("create", "update"):
                try existing.delete(db)
                return try insertOp(entityType: entityType, entityId: entityId, op: "create", patch: patch, baseUpdatedAt: baseUpdatedAt, in: db)

            // Pending update + new update → replace with latest
            case ("update", "update"):
                try existing.delete(db)
                return try insertOp(entityType: entityType, entityId: entityId, op: "update", patch: patch, baseUpdatedAt: baseUpdatedAt, in: db)

            default:
                break
            }
        }

        return try insertOp(entityType: entityType, entityId: entityId, op: op, patch: patch, baseUpdatedAt: baseUpdatedAt, in: db)
    }

    /// Enqueue a delete: creates a tombstone + outbox op inside an existing transaction.
    /// If there's a pending create for this entity (never synced), both cancel out.
    static func enqueueDelete(
        entityType: String,
        entityId: String,
        in db: Database
    ) throws {
        // If there's a pending create, the entity was never synced — cancel both
        if let existing = try findPending(entityType: entityType, entityId: entityId, in: db),
           existing.op == "create" {
            try existing.delete(db)
            return
        }

        // If there's a pending update, remove it — the delete supersedes it
        if let existing = try findPending(entityType: entityType, entityId: entityId, in: db),
           existing.op == "update" {
            try existing.delete(db)
        }

        let deviceId = (try? SyncState.current(in: db)?.deviceId) ?? "unknown"
        let tombstone = Tombstone(
            id: UUID(),
            entityType: entityType,
            entityId: entityId,
            deletedAt: Date(),
            updatedAt: Date(),
            deviceId: deviceId
        )
        try tombstone.insert(db)
        try insertOp(entityType: entityType, entityId: entityId, op: "delete", in: db)
    }

    @discardableResult
    private static func insertOp(
        entityType: String,
        entityId: String,
        op: String,
        patch: String = "{}",
        baseUpdatedAt: Date? = nil,
        in db: Database
    ) throws -> OutboxOp {
        let outboxOp = OutboxOp(
            id: UUID(),
            entityType: entityType,
            entityId: entityId,
            op: op,
            patch: patch,
            baseUpdatedAt: baseUpdatedAt,
            schemaVersion: 1,
            createdAt: Date(),
            attemptCount: 0,
            lastError: nil,
            nextRetryAt: nil
        )
        try outboxOp.insert(db)
        return outboxOp
    }
}

// MARK: - PeriodicReview (server-authored, read-only cache)

/// AI-generated weekly or monthly review. Generated by the backend cron job
/// and cached locally for offline access + reactive UI. Not user-editable.
nonisolated struct PeriodicReview: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "periodicReview"

    struct Theme: Codable, Hashable, Sendable {
        let name: String
        let mentions: Int
    }
    struct DirectiveWin: Codable, Hashable, Sendable {
        let directiveTitle: String
        let evidence: String
    }
    struct DirectiveFocus: Codable, Hashable, Sendable {
        let directiveTitle: String
        let reason: String
    }
    struct DirectiveGap: Codable, Hashable, Sendable {
        let theme: String
        let suggestedTitle: String
    }
    struct MissedScheduled: Codable, Hashable, Sendable {
        let directiveTitle: String
        let missedCount: Int
        let missedDates: [String]
        var scheduledDates: [String] = []

        private enum CodingKeys: String, CodingKey {
            case directiveTitle, missedCount, missedDates, scheduledDates
        }
        init(directiveTitle: String, missedCount: Int, missedDates: [String], scheduledDates: [String]) {
            self.directiveTitle = directiveTitle
            self.missedCount = missedCount
            self.missedDates = missedDates
            self.scheduledDates = scheduledDates
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            directiveTitle = try c.decode(String.self, forKey: .directiveTitle)
            missedCount = try c.decode(Int.self, forKey: .missedCount)
            missedDates = try c.decode([String].self, forKey: .missedDates)
            scheduledDates = (try? c.decode([String].self, forKey: .scheduledDates)) ?? []
        }
    }

    let id: UUID
    let period: String           // "weekly" | "monthly"
    let periodStart: String      // yyyy-MM-dd
    let periodEnd: String        // yyyy-MM-dd

    // Structured insights
    var themes: [Theme]
    var directiveWins: [DirectiveWin]
    var directiveFocus: [DirectiveFocus]
    var directiveGaps: [DirectiveGap]
    var missedScheduled: [MissedScheduled]
    let suggestion: String?

    // Context
    let summary: String
    let bestDay: String?
    let bestDayNote: String?
    let lowestDay: String?
    let lowestDayNote: String?
    let avgRating: Double?
    let entryCount: Int
    let createdAt: String        // ISO8601 from server

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PeriodicReview, rhs: PeriodicReview) -> Bool { lhs.id == rhs.id }

    // Standard synthesized init for API decoding
    init(
        id: UUID, period: String, periodStart: String, periodEnd: String,
        themes: [Theme], directiveWins: [DirectiveWin],
        directiveFocus: [DirectiveFocus], directiveGaps: [DirectiveGap],
        missedScheduled: [MissedScheduled],
        suggestion: String?, summary: String,
        bestDay: String?, bestDayNote: String?,
        lowestDay: String?, lowestDayNote: String?,
        avgRating: Double?, entryCount: Int, createdAt: String
    ) {
        self.id = id
        self.period = period
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.themes = themes
        self.directiveWins = directiveWins
        self.directiveFocus = directiveFocus
        self.directiveGaps = directiveGaps
        self.missedScheduled = missedScheduled
        self.suggestion = suggestion
        self.summary = summary
        self.bestDay = bestDay
        self.bestDayNote = bestDayNote
        self.lowestDay = lowestDay
        self.lowestDayNote = lowestDayNote
        self.avgRating = avgRating
        self.entryCount = entryCount
        self.createdAt = createdAt
    }

    // GRDB row decoding (JSON arrays stored in TEXT columns)
    init(row: Row) {
        id = row["id"]
        period = row["period"]
        periodStart = row["periodStart"]
        periodEnd = row["periodEnd"]
        suggestion = row["suggestion"]
        summary = row["summary"]
        bestDay = row["bestDay"]
        bestDayNote = row["bestDayNote"]
        lowestDay = row["lowestDay"]
        lowestDayNote = row["lowestDayNote"]
        avgRating = row["avgRating"]
        entryCount = row["entryCount"]
        createdAt = row["createdAt"]
        themes = Self.decodeJSON(row["themesJSON"]) ?? []
        directiveWins = Self.decodeJSON(row["directiveWinsJSON"]) ?? []
        directiveFocus = Self.decodeJSON(row["directiveFocusJSON"]) ?? []
        directiveGaps = Self.decodeJSON(row["directiveGapsJSON"]) ?? []
        missedScheduled = Self.decodeJSON(row["missedScheduledJSON"]) ?? []
    }

    // GRDB row encoding
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["period"] = period
        container["periodStart"] = periodStart
        container["periodEnd"] = periodEnd
        container["suggestion"] = suggestion
        container["summary"] = summary
        container["bestDay"] = bestDay
        container["bestDayNote"] = bestDayNote
        container["lowestDay"] = lowestDay
        container["lowestDayNote"] = lowestDayNote
        container["avgRating"] = avgRating
        container["entryCount"] = entryCount
        container["createdAt"] = createdAt
        container["themesJSON"] = Self.encodeJSON(themes)
        container["directiveWinsJSON"] = Self.encodeJSON(directiveWins)
        container["directiveFocusJSON"] = Self.encodeJSON(directiveFocus)
        container["directiveGapsJSON"] = Self.encodeJSON(directiveGaps)
        container["missedScheduledJSON"] = Self.encodeJSON(missedScheduled)
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private static func decodeJSON<T: Decodable>(_ jsonString: String?) -> T? {
        guard let jsonString, let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
