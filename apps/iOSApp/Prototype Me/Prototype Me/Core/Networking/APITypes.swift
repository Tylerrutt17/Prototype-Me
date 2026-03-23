import Foundation

// MARK: - Empty Body (for POST with no payload)

struct EmptyBody: Encodable {}

// MARK: - Update DTOs (PATCH payloads)

struct NotePageUpdate: Encodable {
    var title: String?
    var body: String?
    var kind: NoteKind?
    var folderId: UUID?
    var sortIndex: Int?
    var version: Int
}

struct DirectiveUpdate: Encodable {
    var title: String?
    var body: String?
    var status: DirectiveStatus?
    var balloonEnabled: Bool?
    var balloonDurationSec: TimeInterval?
    var balloonSnapshotSec: TimeInterval?
    var snoozedUntil: Date?
    var version: Int
}

struct FolderUpdate: Encodable {
    var name: String?
    var parentFolderId: UUID?
}

struct DayEntryUpdate: Encodable {
    var rating: Int?
    var diary: String?
    var tags: [String]?
}

struct UserProfileUpdate: Encodable {
    var displayName: String?
    var bio: String?
    var avatarSystemImage: String?
    var moodChips: [String]?
}

// MARK: - Sync Types

struct SyncPushRequest: Encodable {
    let deviceId: String
    let operations: [OutboxOp]
}

struct SyncPushResponse: Decodable {
    let results: [SyncOpResult]
}

struct SyncOpResult: Decodable {
    let operationId: UUID
    let status: String // "ok" | "conflict" | "error"
    let error: String?
    let serverVersion: Int?
}

struct SyncPullRequest: Encodable {
    let deviceId: String
    let cursor: String?
}

struct SyncPullResponse: Decodable {
    let changes: [SyncChange]
    let cursor: String
    let hasMore: Bool
}

struct SyncChange: Decodable {
    let entityType: String
    let entityId: UUID
    let op: String // "create" | "update" | "delete"
    let data: AnyCodable?
    let updatedAt: Date
}

// MARK: - AI Types

struct AiSuggestRequest: Encodable {
    let context: String?
}

struct AiOnboardResponse: Decodable {
    let cards: [SeedPlanCard]
}

// MARK: - AnyCodable (for untyped JSON in sync changes)

struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            value = NSNull()
        }
    }

    /// Attempt to decode as a specific Codable type from the underlying dictionary.
    func decode<T: Decodable>(as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: value)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
