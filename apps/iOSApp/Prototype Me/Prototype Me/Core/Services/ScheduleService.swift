import Foundation
import GRDB

/// Owns all write operations for ScheduleRule and ScheduleInstance.
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
        let rule = ScheduleRule(
            id: UUID(),
            directiveId: directiveId,
            ruleType: ruleType,
            params: params,
            createdAt: Date()
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

    // MARK: - Instances

    func markInstance(id: UUID, status: InstanceStatus) async throws {
        try await db.dbQueue.write { db in
            guard var inst = try ScheduleInstance.fetchOne(db, key: id) else { return }
            inst.status = status
            try inst.update(db)
        }
    }

    /// Generates pending instances for a given date based on all schedule rules.
    func generateInstances(for dateString: String) async throws {
        try await db.dbQueue.write { db in
            let rules = try ScheduleRule.fetchAll(db)
            let weekday = Self.weekday(from: dateString)
            let dayOfMonth = Self.dayOfMonth(from: dateString)

            for rule in rules {
                let shouldCreate: Bool = switch rule.ruleType {
                case .weekly:
                    rule.params["days"]?.contains(weekday) ?? false
                case .monthly:
                    rule.params["days"]?.contains(dayOfMonth) ?? false
                case .oneOff:
                    // For one-off, params["dates"] not used — check if rule's date matches
                    false
                }

                guard shouldCreate else { continue }

                // Skip if instance already exists for this directive+date
                let exists = try ScheduleInstance
                    .filter(Column("directiveId") == rule.directiveId && Column("date") == dateString)
                    .fetchCount(db) > 0
                guard !exists else { continue }

                let instance = ScheduleInstance(
                    id: UUID(),
                    directiveId: rule.directiveId,
                    date: dateString,
                    status: .pending
                )
                try instance.insert(db)
            }
        }
    }

    // MARK: - Helpers

    private static func weekday(from dateString: String) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateString) else { return 1 }
        // Calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat → convert to 1=Mon...7=Sun
        let cal = Calendar.current
        let w = cal.component(.weekday, from: date)
        return w == 1 ? 7 : w - 1
    }

    private static func dayOfMonth(from dateString: String) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateString) else { return 1 }
        return Calendar.current.component(.day, from: date)
    }
}
