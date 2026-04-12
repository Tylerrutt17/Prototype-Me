import Foundation
import GRDB

/// Trigram-based fuzzy search across directives, notes, and folders.
/// Matches PostgreSQL pg_trgm behavior so AI system prompt thresholds remain valid.
enum FuzzySearch {

    struct Result {
        let id: String
        let type: String      // "directive", "note", "folder"
        let title: String
        let body: String?
        let kind: String?
        let status: String?
        let similarity: Double
    }

    /// Search across active directives, notes, and folders in a single GRDB read.
    static func search(query: String, in db: Database, limit: Int = 10, threshold: Double = 0.15) throws -> [Result] {
        let normalizedQuery = query.lowercased()
        guard !normalizedQuery.isEmpty else { return [] }

        var candidates: [Result] = []

        // Directives (active only)
        let directives = try Directive
            .filter(Column("status") == DirectiveStatus.active.rawValue)
            .fetchAll(db)
        for d in directives {
            let sim = trigrams(normalizedQuery, d.title.lowercased())
            if sim >= threshold {
                candidates.append(Result(
                    id: d.id.uuidString, type: "directive",
                    title: d.title, body: d.body,
                    kind: nil, status: d.status.rawValue,
                    similarity: sim
                ))
            }
        }

        // Notes (all kinds)
        let notes = try NotePage.fetchAll(db)
        for n in notes {
            let sim = trigrams(normalizedQuery, n.title.lowercased())
            if sim >= threshold {
                candidates.append(Result(
                    id: n.id.uuidString, type: "note",
                    title: n.title, body: n.body,
                    kind: n.kind.rawValue, status: nil,
                    similarity: sim
                ))
            }
        }

        // Folders
        let folders = try Folder.fetchAll(db)
        for f in folders {
            let sim = trigrams(normalizedQuery, f.name.lowercased())
            if sim >= threshold {
                candidates.append(Result(
                    id: f.id.uuidString, type: "folder",
                    title: f.name, body: nil,
                    kind: nil, status: nil,
                    similarity: sim
                ))
            }
        }

        candidates.sort { $0.similarity > $1.similarity }
        return Array(candidates.prefix(limit))
    }

    // MARK: - Trigram Similarity (pg_trgm compatible)

    /// Compute trigram similarity between two strings using Jaccard coefficient.
    /// Matches PostgreSQL pg_trgm `similarity()` behavior:
    /// pad with 2 leading spaces + 1 trailing space, extract 3-char windows,
    /// return |intersection| / |union|.
    static func trigrams(_ a: String, _ b: String) -> Double {
        let setA = trigramSet(a)
        let setB = trigramSet(b)

        guard !setA.isEmpty || !setB.isEmpty else { return 0 }

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count

        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }

    private static func trigramSet(_ s: String) -> Set<String> {
        let padded = "  " + s + " "
        let chars = Array(padded)
        guard chars.count >= 3 else { return [] }
        var set = Set<String>()
        for i in 0...(chars.count - 3) {
            set.insert(String(chars[i..<(i + 3)]))
        }
        return set
    }
}
