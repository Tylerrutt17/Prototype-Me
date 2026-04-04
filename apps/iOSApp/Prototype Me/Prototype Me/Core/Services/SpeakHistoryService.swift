import Foundation
import GRDB

/// Persists AI-driven changes locally so the user can undo them. Local-only
/// (not synced). Caps at `maxEntries`, evicting the oldest.
final class SpeakHistoryService: Sendable {

    private let db: DatabaseManager
    private let maxEntries: Int

    init(db: DatabaseManager, maxEntries: Int = 50) {
        self.db = db
        self.maxEntries = maxEntries
    }

    // MARK: - Public API

    func record(_ entry: SpeakHistoryEntry) async throws {
        let record = try Self.toRecord(entry)
        try await db.dbQueue.write { db in
            try record.insert(db)
            // Evict oldest beyond cap
            let count = try SpeakHistoryRecord.fetchCount(db)
            if count > self.maxEntries {
                let excess = count - self.maxEntries
                let idsToDelete = try SpeakHistoryRecord
                    .order(Column("timestamp").asc)
                    .limit(excess)
                    .fetchAll(db)
                    .map(\.id)
                _ = try SpeakHistoryRecord.deleteAll(db, keys: idsToDelete)
            }
        }
    }

    func recent(limit: Int = 50) async throws -> [SpeakHistoryEntry] {
        let records = try await db.dbQueue.read { db in
            try SpeakHistoryRecord
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
        return records.compactMap { try? Self.fromRecord($0) }
    }

    func remove(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            try SpeakHistoryRecord.deleteOne(db, key: id)
        }
    }

    func clearAll() async throws {
        _ = try await db.dbQueue.write { db in
            try SpeakHistoryRecord.deleteAll(db)
        }
    }

    // MARK: - Conversion

    private struct ModeStateSnapshot: Codable { let wasActive: Bool }

    private enum ConversionError: Error {
        case invalidUUID(String)
        case unknownEntityType(String)
        case unknownActionType(String)
        case missingBeforeState(String)
    }

    static func toRecord(_ entry: SpeakHistoryEntry) throws -> SpeakHistoryRecord {
        let encoder = JSONEncoder()
        let entityType: String
        let entityId: String
        let beforeJSON: String?

        switch entry.entityKind {
        case .directive(let id, let before):
            entityType = "directive"
            entityId = id.uuidString
            beforeJSON = try before.map { try Self.encodeToString($0, using: encoder) }
        case .note(let id, let before):
            entityType = "note"
            entityId = id.uuidString
            beforeJSON = try before.map { try Self.encodeToString($0, using: encoder) }
        case .journal(let date, let before):
            entityType = "journal"
            entityId = date
            beforeJSON = try before.map { try Self.encodeToString($0, using: encoder) }
        case .folder(let id, let before):
            entityType = "folder"
            entityId = id.uuidString
            beforeJSON = try Self.encodeToString(before, using: encoder)
        case .mode(let noteId, let wasActive):
            entityType = "mode"
            entityId = noteId.uuidString
            beforeJSON = try Self.encodeToString(ModeStateSnapshot(wasActive: wasActive), using: encoder)
        }

        return SpeakHistoryRecord(
            id: entry.id,
            timestamp: entry.timestamp,
            actionType: Self.actionTypeToString(entry.actionType),
            entityType: entityType,
            entityId: entityId,
            itemName: entry.itemName,
            beforeJSON: beforeJSON
        )
    }

    static func fromRecord(_ record: SpeakHistoryRecord) throws -> SpeakHistoryEntry {
        let actionType = try Self.actionType(fromString: record.actionType)
        let kind = try Self.entityKind(
            entityType: record.entityType,
            entityId: record.entityId,
            beforeJSON: record.beforeJSON
        )
        return SpeakHistoryEntry(
            id: record.id,
            timestamp: record.timestamp,
            actionType: actionType,
            itemName: record.itemName,
            entityKind: kind
        )
    }

    private static func entityKind(entityType: String, entityId: String, beforeJSON: String?) throws -> SpeakHistoryEntry.EntityKind {
        let decoder = JSONDecoder()
        switch entityType {
        case "directive":
            guard let id = UUID(uuidString: entityId) else { throw ConversionError.invalidUUID(entityId) }
            let before = try beforeJSON.map { try Self.decode(Directive.self, from: $0, using: decoder) }
            return .directive(id: id, before: before)
        case "note":
            guard let id = UUID(uuidString: entityId) else { throw ConversionError.invalidUUID(entityId) }
            let before = try beforeJSON.map { try Self.decode(NotePage.self, from: $0, using: decoder) }
            return .note(id: id, before: before)
        case "journal":
            let before = try beforeJSON.map { try Self.decode(DayEntry.self, from: $0, using: decoder) }
            return .journal(date: entityId, before: before)
        case "folder":
            guard let id = UUID(uuidString: entityId) else { throw ConversionError.invalidUUID(entityId) }
            guard let json = beforeJSON else { throw ConversionError.missingBeforeState("folder") }
            let before = try Self.decode(Folder.self, from: json, using: decoder)
            return .folder(id: id, before: before)
        case "mode":
            guard let id = UUID(uuidString: entityId) else { throw ConversionError.invalidUUID(entityId) }
            guard let json = beforeJSON else { throw ConversionError.missingBeforeState("mode") }
            let snapshot = try Self.decode(ModeStateSnapshot.self, from: json, using: decoder)
            return .mode(noteId: id, wasActive: snapshot.wasActive)
        default:
            throw ConversionError.unknownEntityType(entityType)
        }
    }

    // MARK: - Action Type String Mapping

    private static func actionTypeToString(_ type: SpeakPendingToolCall.ActionType) -> String {
        switch type {
        case .create: return "create"
        case .update: return "update"
        case .retire: return "retire"
        case .activate: return "activate"
        case .deactivate: return "deactivate"
        }
    }

    private static func actionType(fromString s: String) throws -> SpeakPendingToolCall.ActionType {
        switch s {
        case "create": return .create
        case "update": return .update
        case "retire": return .retire
        case "activate": return .activate
        case "deactivate": return .deactivate
        default: throw ConversionError.unknownActionType(s)
        }
    }

    // MARK: - JSON Helpers

    private static func encodeToString<T: Encodable>(_ value: T, using encoder: JSONEncoder) throws -> String {
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func decode<T: Decodable>(_ type: T.Type, from string: String, using decoder: JSONDecoder) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw ConversionError.missingBeforeState("invalid utf8")
        }
        return try decoder.decode(T.self, from: data)
    }
}
