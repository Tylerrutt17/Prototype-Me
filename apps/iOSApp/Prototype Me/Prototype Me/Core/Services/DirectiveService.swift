import Foundation
import GRDB

/// Owns all write operations for Directive, including balloon mechanics and history tracking.
final class DirectiveService: Sendable {

    private let db: DatabaseManager

    init(db: DatabaseManager) {
        self.db = db
    }

    // MARK: - CRUD

    func create(
        title: String,
        body: String? = nil,
        balloonEnabled: Bool = false,
        balloonDurationSec: TimeInterval = 0
    ) async throws -> Directive {
        let now = Date()
        let directive = Directive(
            id: UUID(),
            title: title,
            body: body,
            status: .active,
            balloonEnabled: balloonEnabled,
            balloonDurationSec: balloonDurationSec,
            balloonSnapshotSec: balloonDurationSec,
            snoozedUntil: nil,
            version: 1,
            createdAt: now,
            updatedAt: now
        )
        try await db.dbQueue.write { db in
            try directive.insert(db)
            try DirectiveHistory(
                id: UUID(), directiveId: directive.id,
                action: .create, payload: "{}", createdAt: now
            ).insert(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: directive.id.uuidString, op: "create", patch: directive.syncPatch(), in: db)
        }
        return directive
    }

    func update(_ directive: Directive) async throws {
        var updated = directive
        updated.updatedAt = Date()
        updated.version += 1
        try await db.dbQueue.write { db in
            try updated.update(db)
            try DirectiveHistory(
                id: UUID(), directiveId: updated.id,
                action: .update, payload: "{}", createdAt: Date()
            ).insert(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: updated.id.uuidString, op: "update", patch: updated.syncPatch(), baseUpdatedAt: updated.updatedAt, in: db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await db.dbQueue.write { db in
            try Directive.deleteOne(db, key: id)
            try OutboxOp.enqueueDelete(entityType: "directive", entityId: id.uuidString, in: db)
        }
    }

    func fetch(id: UUID) async throws -> Directive? {
        try await db.dbQueue.read { db in
            try Directive.fetchOne(db, key: id)
        }
    }

    // MARK: - Status Changes

    func archive(id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard var dir = try Directive.fetchOne(db, key: id) else { return }
            let oldStatus = dir.status.rawValue
            dir.status = .archived
            dir.updatedAt = Date()
            dir.version += 1
            try dir.update(db)
            try DirectiveHistory(
                id: UUID(), directiveId: id,
                action: .graduate,
                payload: "{\"from\":\"\(oldStatus)\",\"to\":\"archived\"}",
                createdAt: Date()
            ).insert(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: id.uuidString, op: "update", patch: dir.syncPatch(), baseUpdatedAt: dir.updatedAt, in: db)
        }
    }

    func reactivate(id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard var dir = try Directive.fetchOne(db, key: id) else { return }
            dir.status = .active
            dir.snoozedUntil = nil
            dir.updatedAt = Date()
            dir.version += 1
            try dir.update(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: id.uuidString, op: "update", patch: dir.syncPatch(), baseUpdatedAt: dir.updatedAt, in: db)
        }
    }

    // MARK: - Balloon Mechanics

    func pumpBalloon(id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard var dir = try Directive.fetchOne(db, key: id), dir.balloonEnabled else { return }
            dir.balloonSnapshotSec = dir.balloonDurationSec
            dir.updatedAt = Date()
            dir.version += 1
            try dir.update(db)
            try DirectiveHistory(
                id: UUID(), directiveId: id,
                action: .balloonPump,
                payload: "{\"resetTo\":\(dir.balloonDurationSec)}",
                createdAt: Date()
            ).insert(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: id.uuidString, op: "update", patch: dir.syncPatch(), baseUpdatedAt: dir.updatedAt, in: db)
        }
    }

    func shrinkBalloon(id: UUID, newDurationSec: TimeInterval) async throws {
        try await db.dbQueue.write { db in
            guard var dir = try Directive.fetchOne(db, key: id), dir.balloonEnabled else { return }
            dir.balloonDurationSec = newDurationSec
            dir.balloonSnapshotSec = min(dir.balloonSnapshotSec, newDurationSec)
            dir.updatedAt = Date()
            dir.version += 1
            try dir.update(db)
            try DirectiveHistory(
                id: UUID(), directiveId: id,
                action: .shrink,
                payload: "{\"newDuration\":\(newDurationSec)}",
                createdAt: Date()
            ).insert(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: id.uuidString, op: "update", patch: dir.syncPatch(), baseUpdatedAt: dir.updatedAt, in: db)
        }
    }

    // MARK: - Snooze

    func snooze(id: UUID, until: Date) async throws {
        try await db.dbQueue.write { db in
            guard var dir = try Directive.fetchOne(db, key: id) else { return }
            dir.snoozedUntil = until
            dir.updatedAt = Date()
            dir.version += 1
            try dir.update(db)
            try DirectiveHistory(
                id: UUID(), directiveId: id,
                action: .snooze,
                payload: "{\"until\":\"\(until.ISO8601Format())\"}",
                createdAt: Date()
            ).insert(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: id.uuidString, op: "update", patch: dir.syncPatch(), baseUpdatedAt: dir.updatedAt, in: db)
        }
    }

    func unsnooze(id: UUID) async throws {
        try await db.dbQueue.write { db in
            guard var dir = try Directive.fetchOne(db, key: id) else { return }
            dir.snoozedUntil = nil
            dir.updatedAt = Date()
            dir.version += 1
            try dir.update(db)
            try OutboxOp.enqueue(entityType: "directive", entityId: id.uuidString, op: "update", patch: dir.syncPatch(), baseUpdatedAt: dir.updatedAt, in: db)
        }
    }
}
