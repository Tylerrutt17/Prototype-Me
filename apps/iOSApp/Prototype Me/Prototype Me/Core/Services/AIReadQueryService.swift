import Foundation
import GRDB

/// Executes AI read tool calls locally against the GRDB database.
/// Returns JSON strings matching the format the server's converse endpoint previously returned,
/// so the AI's system prompt and tool definitions remain compatible.
final class AIReadQueryService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    /// Execute a read tool call locally. Returns a JSON string.
    func execute(function: String, arguments: [String: Any]) async throws -> String {
        switch function {
        case "search":
            return try await search(query: arguments["query"] as? String ?? "")
        case "list_directives":
            return try await listDirectives(status: arguments["status"] as? String ?? "active")
        case "list_notes":
            return try await listNotes(kind: arguments["kind"] as? String)
        case "list_modes":
            return try await listModes()
        case "list_folders":
            return try await listFolders()
        case "get_directive":
            return try await getDirective(id: arguments["id"] as? String ?? "")
        case "get_note":
            return try await getNote(id: arguments["id"] as? String ?? "")
        case "get_journal_entry":
            return try await getJournalEntry(date: arguments["date"] as? String ?? "")
        default:
            return "{}"
        }
    }

    // MARK: - Search

    private func search(query: String) async throws -> String {
        let results = try await db.dbQueue.read { db in
            try FuzzySearch.search(query: query, in: db, limit: 10)
        }
        let mapped: [[String: Any?]] = results.map { r in
            [
                "id": r.id,
                "type": r.type,
                "title": r.title,
                "body": truncate(r.body),
                "kind": r.kind,
                "status": r.status,
                "similarity": "\(Int(r.similarity * 100))%",
            ]
        }
        return jsonEncode(mapped)
    }

    // MARK: - List Operations

    private func listDirectives(status: String) async throws -> String {
        let results = try await db.dbQueue.read { db in
            try Directive
                .filter(Column("status") == status)
                .fetchAll(db)
        }
        let mapped: [[String: Any?]] = results.map { d in
            [
                "id": d.id.uuidString,
                "title": d.title,
                "body": truncate(d.body),
                "status": d.status.rawValue,
            ]
        }
        return jsonEncode(mapped)
    }

    private func listNotes(kind: String?) async throws -> String {
        let results = try await db.dbQueue.read { db in
            var request = NotePage.all()
            if let kind { request = request.filter(Column("kind") == kind) }
            return try request.fetchAll(db)
        }
        let mapped: [[String: Any?]] = results.map { n in
            [
                "id": n.id.uuidString,
                "title": n.title,
                "body": truncate(n.body),
                "kind": n.kind.rawValue,
            ]
        }
        return jsonEncode(mapped)
    }

    private func listModes() async throws -> String {
        let (modes, activeModes) = try await db.dbQueue.read { db -> ([NotePage], [ActiveMode]) in
            let modes = try NotePage.filter(Column("kind") == NoteKind.mode.rawValue).fetchAll(db)
            let active = try ActiveMode.fetchAll(db)
            return (modes, active)
        }
        let activeIds = Set(activeModes.map(\.noteId))
        let mapped: [[String: Any]] = modes.map { n in
            [
                "id": n.id.uuidString,
                "title": n.title,
                "active": activeIds.contains(n.id),
            ]
        }
        return jsonEncode(mapped)
    }

    private func listFolders() async throws -> String {
        let results = try await db.dbQueue.read { db in
            try Folder.fetchAll(db)
        }
        let mapped: [[String: Any]] = results.map { f in
            ["id": f.id.uuidString, "name": f.name]
        }
        return jsonEncode(mapped)
    }

    // MARK: - Get Operations (full body, no truncation)

    private func getDirective(id: String) async throws -> String {
        guard let uuid = UUID(uuidString: id) else { return "{\"exists\":false}" }
        let directive = try await db.dbQueue.read { db in
            try Directive.fetchOne(db, key: uuid)
        }
        guard let d = directive else { return "{\"exists\":false}" }
        var result: [String: Any] = [
            "exists": true,
            "id": d.id.uuidString,
            "title": d.title,
            "status": d.status.rawValue,
        ]
        if let body = d.body { result["body"] = body }
        return jsonEncode(result)
    }

    private func getNote(id: String) async throws -> String {
        guard let uuid = UUID(uuidString: id) else { return "{\"exists\":false}" }
        let note = try await db.dbQueue.read { db in
            try NotePage.fetchOne(db, key: uuid)
        }
        guard let n = note else { return "{\"exists\":false}" }
        return jsonEncode([
            "exists": true,
            "id": n.id.uuidString,
            "title": n.title,
            "body": n.body,
            "kind": n.kind.rawValue,
        ] as [String: Any])
    }

    private func getJournalEntry(date: String) async throws -> String {
        let entry = try await db.dbQueue.read { db in
            try DayEntry.filter(Column("date") == date).fetchOne(db)
        }
        guard let e = entry else { return "{\"exists\":false}" }
        var result: [String: Any] = [
            "exists": true,
            "id": e.id.uuidString,
            "date": e.date,
            "diary": e.diary,
            "tags": e.tags,
        ]
        if let rating = e.rating { result["rating"] = rating }
        return jsonEncode(result)
    }

    // MARK: - Helpers

    private func truncate(_ text: String?, maxLen: Int = 150) -> Any {
        guard let text, !text.isEmpty else { return NSNull() }
        return text.count <= maxLen ? text : String(text.prefix(maxLen)) + "…"
    }

    private func jsonEncode(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }
}
