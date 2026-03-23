import Foundation
import GRDB

/// Seeds the database with sample data on first launch.
/// Checks if the `notePage` table is empty before inserting.
enum DatabaseSeeder {

    static func seedIfNeeded(db: DatabaseManager) throws {
        try db.dbQueue.write { db in
            let count = try NotePage.fetchCount(db)
            guard count == 0 else { return }

            // Insert in dependency order: folders first, then notes, directives, joins, etc.

            // ── Folders ──
            for folder in SampleData.folders {
                try folder.insert(db)
            }

            // ── Notes ──
            for note in SampleData.notes {
                try note.insert(db)
            }

            // ── Directives ──
            for directive in SampleData.directives {
                try directive.insert(db)
            }

            // ── NoteDirective joins ──
            for nd in SampleData.noteDirectives {
                try nd.insert(db)
            }

            // ── Tags ──
            for tag in SampleData.tags {
                try tag.insert(db)
            }

            // ── Day entries ──
            for entry in SampleData.dayEntries {
                try entry.insert(db)
            }

            // ── Schedule rules ──
            for rule in SampleData.scheduleRules {
                try rule.insert(db)
            }

            // ── Schedule instances ──
            for instance in SampleData.scheduleInstances {
                try instance.insert(db)
            }

            // ── Directive history ──
            for history in SampleData.directiveHistory {
                try history.insert(db)
            }

            // ── Active modes ──
            for mode in SampleData.activeModes {
                try mode.insert(db)
            }
        }
    }
}
