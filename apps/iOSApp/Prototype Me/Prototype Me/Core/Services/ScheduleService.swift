import Foundation
import GRDB

/// Owns all write operations for ScheduleRule.
final class ScheduleService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - Rules

    func createRule(
        directiveId: UUID,
        ruleType: ScheduleType,
        params: [String: [Int]]
    ) async throws -> ScheduleRule {
        let now = Date()
        let rule = ScheduleRule(
            id: UUID(),
            directiveId: directiveId,
            ruleType: ruleType,
            params: params,
            version: 1,
            createdAt: now,
            updatedAt: now
        )
        try await db.safeWrite { db in
            try rule.insert(db)
            try OutboxOp.enqueue(entityType: "scheduleRule", entityId: rule.id.uuidString, op: "create", patch: rule.syncPatch(), in: db)
        }
        return rule
    }

    func deleteRule(id: UUID) async throws {
        _ = try await db.safeWrite { db in
            try ScheduleRule.deleteOne(db, key: id)
            try OutboxOp.enqueueDelete(entityType: "scheduleRule", entityId: id.uuidString, in: db)
        }
    }

    // MARK: - Completion

    func markRuleCompleted(id: UUID, date: String) async throws {
        try await db.safeWrite { db in
            guard var rule = try ScheduleRule.fetchOne(db, key: id) else { return }
            rule.lastCompletedDate = date
            rule.version += 1
            rule.updatedAt = Date()
            try rule.update(db)
            try OutboxOp.enqueue(entityType: "scheduleRule", entityId: id.uuidString, op: "update", patch: rule.syncPatch(), baseUpdatedAt: rule.updatedAt, in: db)
        }
    }

    func markRulePending(id: UUID) async throws {
        try await db.safeWrite { db in
            guard var rule = try ScheduleRule.fetchOne(db, key: id) else { return }
            rule.lastCompletedDate = nil
            rule.version += 1
            rule.updatedAt = Date()
            try rule.update(db)
            try OutboxOp.enqueue(entityType: "scheduleRule", entityId: id.uuidString, op: "update", patch: rule.syncPatch(), baseUpdatedAt: rule.updatedAt, in: db)
        }
    }

    // MARK: - Update (for editor)

    func updateRule(id: UUID, ruleType: ScheduleType, params: [String: [Int]]) async throws {
        try await db.safeWrite { db in
            guard var rule = try ScheduleRule.fetchOne(db, key: id) else { return }
            rule.ruleType = ruleType
            rule.params = params
            rule.version += 1
            rule.updatedAt = Date()
            try rule.update(db)
            try OutboxOp.enqueue(entityType: "scheduleRule", entityId: id.uuidString, op: "update", patch: rule.syncPatch(), baseUpdatedAt: rule.updatedAt, in: db)
        }
    }
}
