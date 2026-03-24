import Foundation
import GRDB

/// Writes DirectiveHistory entries silently for AI consumption.
/// Not displayed to users — used for AI context and analytics.
enum DirectiveLogger {

    static func log(
        _ action: DirectiveHistoryAction,
        directiveId: UUID,
        payload: String = "",
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
        }
    }

    // MARK: - Convenience

    static func logCreate(directiveId: UUID, title: String, dbQueue: DatabaseQueue) {
        log(.create, directiveId: directiveId, payload: title, dbQueue: dbQueue)
    }

    static func logUpdate(directiveId: UUID, dbQueue: DatabaseQueue) {
        log(.update, directiveId: directiveId, dbQueue: dbQueue)
    }

    static func logPump(directiveId: UUID, dbQueue: DatabaseQueue) {
        log(.balloonPump, directiveId: directiveId, dbQueue: dbQueue)
    }

    static func logArchive(directiveId: UUID, dbQueue: DatabaseQueue) {
        log(.graduate, directiveId: directiveId, payload: "archived", dbQueue: dbQueue)
    }

    static func logChecklistComplete(directiveId: UUID, date: String, dbQueue: DatabaseQueue) {
        log(.update, directiveId: directiveId, payload: "checklist_done:\(date)", dbQueue: dbQueue)
    }
}
