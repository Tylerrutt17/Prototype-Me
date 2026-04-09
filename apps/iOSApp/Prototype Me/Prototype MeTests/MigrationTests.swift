import XCTest
import GRDB
@testable import Prototype_Me

/// Tests that each database migration runs safely on data created by previous migrations.
///
/// Pattern:
///   1. Build an in-memory DB up to the migration *before* the one under test
///   2. Seed it with representative data
///   3. Run the remaining migrations
///   4. Assert the data survived and transformed correctly
///
/// To add a test for a new migration:
///   1. Copy an existing test
///   2. Set `through:` to the migration *before* yours
///   3. Seed data that exercises the tables your migration touches
///   4. Run the full migrator and assert
final class MigrationTests: XCTestCase {

    // MARK: - Helpers

    /// Creates an in-memory DatabaseQueue with FK support.
    private func makeDB() throws -> DatabaseQueue {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return try DatabaseQueue(configuration: config)
    }

    // MARK: - Full migration chain

    func testAllMigrationsRunCleanly() throws {
        let db = try makeDB()
        let migrator = DatabaseManager.makeMigrator()
        // Should not throw — this catches syntax errors, FK issues, etc.
        try migrator.migrate(db)
    }

    // MARK: - v10: missedScheduledJSON added to periodicReview

    func testV10_missedScheduled_preservesOtherTables() throws {
        let db = try makeDB()

        // Run up through v1 only
        let partial = DatabaseManager.makeMigrator(through: "v1_initialSchema")
        try partial.migrate(db)

        // Seed a directive on the old schema
        let now = Date()
        try db.write { db in
            try db.execute(
                sql: """
                    INSERT INTO directive (id, title, status, balloonEnabled, balloonDurationSec, balloonSnapshotSec, version, createdAt, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["d1", "Test Directive", "active", false, 0, 0, 1, now, now]
            )
        }

        // Run all remaining migrations
        let full = DatabaseManager.makeMigrator()
        try full.migrate(db)

        // Directive should survive untouched
        let count = try db.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM directive") }
        XCTAssertEqual(count, 1)
    }

    // MARK: - v11: color column added to directive

    func testV11_directiveColor_existingDirectivesGetNilColor() throws {
        let db = try makeDB()

        // Run up through v10
        let partial = DatabaseManager.makeMigrator(through: "v10_missedScheduled")
        try partial.migrate(db)

        // Seed a directive (no color column yet)
        let now = Date()
        try db.write { db in
            try db.execute(
                sql: """
                    INSERT INTO directive (id, title, status, balloonEnabled, balloonDurationSec, balloonSnapshotSec, version, createdAt, updatedAt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["d1", "Old Directive", "active", false, 0, 0, 1, now, now]
            )
        }

        // Run remaining migrations (v11 adds color, v12 adds outbox backoff)
        let full = DatabaseManager.makeMigrator()
        try full.migrate(db)

        // color should be nil for pre-existing directives, data should be intact
        let row = try db.read { try Row.fetchOne($0, sql: "SELECT color, title FROM directive WHERE id = 'd1'") }
        XCTAssertNotNil(row)
        XCTAssertTrue(row!.hasNull(atIndex: 0), "color should be NULL for pre-existing directives")
        XCTAssertEqual(row!["title"] as String, "Old Directive")
    }

    // MARK: - v12: nextRetryAt column + outbox reset

    func testV12_outboxBackoff_resetsAttemptCount() throws {
        let db = try makeDB()

        // Run up through v11
        let partial = DatabaseManager.makeMigrator(through: "v11_directiveColor")
        try partial.migrate(db)

        // Seed a stuck outbox op (attemptCount = 5, has error)
        let now = Date()
        try db.write { db in
            try db.execute(
                sql: """
                    INSERT INTO outboxOp (id, entityType, entityId, op, patch, schemaVersion, createdAt, attemptCount, lastError)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["op1", "directive", "d1", "update", "{}", 1, now, 5, "timeout"]
            )
        }

        // Run v12 migration
        let full = DatabaseManager.makeMigrator()
        try full.migrate(db)

        // attemptCount should be reset to 0, lastError cleared
        let row = try db.read { try Row.fetchOne($0, sql: "SELECT attemptCount, lastError, nextRetryAt FROM outboxOp WHERE id = 'op1'") }
        XCTAssertNotNil(row)
        XCTAssertEqual(row!["attemptCount"] as Int, 0)
        XCTAssertNil(row!["lastError"] as String?)
        XCTAssertNil(row!["nextRetryAt"] as Date?)
    }

    // MARK: - Idempotency: running migrations twice doesn't break

    func testMigrationsAreIdempotent() throws {
        let db = try makeDB()
        let migrator = DatabaseManager.makeMigrator()

        // First run
        try migrator.migrate(db)

        // Second run — GRDB skips already-applied migrations, should be a no-op
        try migrator.migrate(db)
    }
}
