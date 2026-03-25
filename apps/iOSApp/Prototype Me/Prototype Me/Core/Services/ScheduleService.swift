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
        try await db.dbQueue.write { db in
            try rule.insert(db)
        }
        return rule
    }

    func deleteRule(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            try ScheduleRule.deleteOne(db, key: id)
        }
    }

    // MARK: - Completion

    func markRuleCompleted(id: UUID, date: String) async throws {
        try await db.dbQueue.write { db in
            guard var rule = try ScheduleRule.fetchOne(db, key: id) else { return }
            rule.lastCompletedDate = date
            rule.version += 1
            rule.updatedAt = Date()
            try rule.update(db)
        }
    }

    func markRulePending(id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard var rule = try ScheduleRule.fetchOne(db, key: id) else { return }
            rule.lastCompletedDate = nil
            rule.version += 1
            rule.updatedAt = Date()
            try rule.update(db)
        }
    }

    // MARK: - Update (for editor)

    func updateRule(id: UUID, ruleType: ScheduleType, params: [String: [Int]]) async throws {
        try await db.dbQueue.write { db in
            guard var rule = try ScheduleRule.fetchOne(db, key: id) else { return }
            rule.ruleType = ruleType
            rule.params = params
            rule.version += 1
            rule.updatedAt = Date()
            try rule.update(db)
        }
    }
}
