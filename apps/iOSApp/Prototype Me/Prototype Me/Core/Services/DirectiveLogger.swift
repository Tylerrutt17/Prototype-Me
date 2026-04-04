import Foundation
import GRDB

/// Writes DirectiveHistory entries for AI consumption + analytics.
///
/// Payloads are versioned JSON objects per action. Backend validates the shape
/// via Zod schemas. To change a payload shape, bump the version there AND here.
enum DirectiveLogger {

    // MARK: - Core log

    static func log(
        _ action: DirectiveHistoryAction,
        directiveId: UUID,
        payload: String = "{\"v\":1}",
        dbQueue: DatabaseQueue
    ) {
        try? dbQueue.write { db in
            let entry = DirectiveHistory(
                id: UUID(),
                directiveId: directiveId,
                action: action,
                payload: payload,
                createdAt: Date()
            )
            try entry.insert(db)
            // Push to backend (append-only, create-only sync)
            try OutboxOp.enqueue(
                entityType: "directiveHistory",
                entityId: entry.id.uuidString,
                op: "create",
                patch: entry.syncPatch(),
                in: db
            )
        }
    }

    // MARK: - Convenience (each emits versioned JSON payload)

    static func logCreate(directiveId: UUID, title: String, dbQueue: DatabaseQueue) {
        log(.create, directiveId: directiveId, payload: jsonPayload(["v": 1, "title": title]), dbQueue: dbQueue)
    }

    static func logUpdate(directiveId: UUID, dbQueue: DatabaseQueue) {
        log(.update, directiveId: directiveId, payload: jsonPayload(["v": 1]), dbQueue: dbQueue)
    }

    static func logPump(directiveId: UUID, dbQueue: DatabaseQueue) {
        log(.balloonPump, directiveId: directiveId, payload: jsonPayload(["v": 1]), dbQueue: dbQueue)
    }

    static func logArchive(directiveId: UUID, dbQueue: DatabaseQueue) {
        log(.graduate, directiveId: directiveId, payload: jsonPayload(["v": 1, "reason": "archived"]), dbQueue: dbQueue)
    }

    static func logChecklistComplete(directiveId: UUID, date: String, dbQueue: DatabaseQueue) {
        log(.checklistComplete, directiveId: directiveId, payload: jsonPayload(["v": 1, "date": date]), dbQueue: dbQueue)
    }

    /// Undo a checklist completion for a specific directive + date.
    /// Deletes the local log entry and enqueues a delete sync op so the
    /// backend drops the matching row from its history too.
    static func undoChecklistComplete(directiveId: UUID, date: String, dbQueue: DatabaseQueue) {
        try? dbQueue.write { db in
            // Find the matching history row. Payload format: {"v":1,"date":"yyyy-MM-dd"}
            let matching = try DirectiveHistory
                .filter(Column("directiveId") == directiveId)
                .filter(Column("action") == DirectiveHistoryAction.checklistComplete.rawValue)
                .fetchAll(db)
                .filter { $0.payload.contains("\"date\":\"\(date)\"") }

            for entry in matching {
                try entry.delete(db)
                try OutboxOp.enqueue(
                    entityType: "directiveHistory",
                    entityId: entry.id.uuidString,
                    op: "delete",
                    in: db
                )
            }
        }
    }

    // MARK: - JSON helper

    private static func jsonPayload(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{\"v\":1}" }
        return json
    }
}
