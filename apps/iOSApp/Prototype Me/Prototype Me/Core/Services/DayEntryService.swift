import Foundation
import GRDB

/// Owns all write operations for DayEntry (diary).
final class DayEntryService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - CRUD

    func createOrUpdate(date: String, rating: Int?, diary: String, tags: [String]) async throws -> DayEntry {
        try await db.dbQueue.write { db in
            // Upsert: if entry for this date already exists, update it
            if var existing = try DayEntry.filter(Column("date") == date).fetchOne(db) {
                existing.rating = rating
                existing.diary = diary
                existing.tags = tags
                existing.updatedAt = Date()
                try existing.update(db)
                return existing
            } else {
                let now = Date()
                let entry = DayEntry(
                    id: UUID(),
                    date: date,
                    rating: rating,
                    diary: diary,
                    tags: tags,
                    createdAt: now,
                    updatedAt: now
                )
                try entry.insert(db)
                return entry
            }
        }
    }

    func delete(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            try DayEntry.deleteOne(db, key: id)
        }
    }

    func fetch(id: UUID) async throws -> DayEntry? {
        try await db.dbQueue.read { db in
            try DayEntry.fetchOne(db, key: id)
        }
    }

    func fetch(date: String) async throws -> DayEntry? {
        try await db.dbQueue.read { db in
            try DayEntry.filter(Column("date") == date).fetchOne(db)
        }
    }
}
