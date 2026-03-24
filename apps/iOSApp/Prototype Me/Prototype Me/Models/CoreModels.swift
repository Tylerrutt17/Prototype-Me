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
}

// MARK: - NoteDirective (join)

nonisolated struct NoteDirective: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "noteDirective"

    var id: String { "\(noteId)-\(directiveId)" }
    let noteId: UUID
    let directiveId: UUID
    var sortIndex: Int

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: NoteDirective, rhs: NoteDirective) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let note = belongsTo(NotePage.self, using: ForeignKey(["noteId"]))
    static let directive = belongsTo(Directive.self, using: ForeignKey(["directiveId"]))

    // Computed `id` should not be persisted
    private enum CodingKeys: String, CodingKey {
        case noteId, directiveId, sortIndex
    }
}

// MARK: - Folder

nonisolated struct Folder: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "folder"

    let id: UUID
    var name: String
    var parentFolderId: UUID?
    var sortIndex: Int
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Folder, rhs: Folder) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let notes = hasMany(NotePage.self, using: ForeignKey(["folderId"]))
    static let subfolders = hasMany(Folder.self, using: ForeignKey(["parentFolderId"]))
    static let parentFolder = belongsTo(Folder.self, using: ForeignKey(["parentFolderId"]))
}

// MARK: - DayEntry

nonisolated struct DayEntry: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "dayEntry"

    let id: UUID
    var date: String              // yyyy-MM-dd
    var rating: Int?              // 1–10
    var diary: String
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: DayEntry, rhs: DayEntry) -> Bool { lhs.id == rhs.id }

    // MARK: Custom encoding — tags stored as JSON column "tagsJSON"

    init(id: UUID, date: String, rating: Int?, diary: String, tags: [String], createdAt: Date, updatedAt: Date) {
        self.id = id; self.date = date; self.rating = rating
        self.diary = diary; self.tags = tags
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    init(row: Row) {
        id = row["id"]
        date = row["date"]
        rating = row["rating"]
        diary = row["diary"]
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
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt

        if let data = try? JSONEncoder().encode(tags),
           let json = String(data: data, encoding: .utf8) {
            container["tagsJSON"] = json
        } else {
            container["tagsJSON"] = "[]"
        }
    }
}

// MARK: - ScheduleRule

nonisolated struct ScheduleRule: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "scheduleRule"

    let id: UUID
    let directiveId: UUID
    var ruleType: ScheduleType
    var params: [String: [Int]]   // e.g. { "days": [1,3,5] }
    let createdAt: Date
    var lastCompletedDate: String? // yyyy-MM-dd — nil means never completed

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ScheduleRule, rhs: ScheduleRule) -> Bool { lhs.id == rhs.id }

    // MARK: Associations
    static let directive = belongsTo(Directive.self)

    // MARK: Custom encoding — params stored as JSON column "paramsJSON"

    init(id: UUID, directiveId: UUID, ruleType: ScheduleType, params: [String: [Int]], createdAt: Date, lastCompletedDate: String? = nil) {
        self.id = id; self.directiveId = directiveId
        self.ruleType = ruleType; self.params = params
        self.createdAt = createdAt; self.lastCompletedDate = lastCompletedDate
    }

    init(row: Row) {
        id = row["id"]
        directiveId = row["directiveId"]
        ruleType = ScheduleType(rawValue: row["ruleType"]) ?? .weekly
        createdAt = row["createdAt"]
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
        container["createdAt"] = createdAt
        container["lastCompletedDate"] = lastCompletedDate

        if let data = try? JSONEncoder().encode(params),
           let json = String(data: data, encoding: .utf8) {
            container["paramsJSON"] = json
        } else {
            container["paramsJSON"] = "{}"
        }
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

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Tag, rhs: Tag) -> Bool { lhs.id == rhs.id }
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

// MARK: - OutboxOp

nonisolated struct OutboxOp: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "outboxOp"

    let id: UUID
    var entityType: String
    var entityId: UUID
    var op: String               // "create" | "update" | "delete"
    var patch: String            // JSON payload
    var baseUpdatedAt: Date?
    var schemaVersion: Int
    let createdAt: Date
    var attemptCount: Int
    var lastError: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: OutboxOp, rhs: OutboxOp) -> Bool { lhs.id == rhs.id }
}

// MARK: - Tombstone

nonisolated struct Tombstone: Identifiable, Hashable, Sendable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tombstone"

    let id: UUID
    var entityType: String
    var entityId: UUID
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
