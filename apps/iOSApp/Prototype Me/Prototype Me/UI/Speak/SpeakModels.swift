import UIKit

// MARK: - Chat Message

struct SpeakChatMessage {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()
    var pendingToolCalls: [SpeakPendingToolCall]?

    enum Role {
        case user
        case assistant
        case system
        case pendingActions
    }
}

// MARK: - Action Change

struct SpeakActionChange {
    let field: String       // "title", "body", "rating", etc.
    let oldValue: String?   // nil for creates
    let newValue: String
}

// MARK: - Pending Tool Call

struct SpeakPendingToolCall {
    let id: String
    let function: String
    let arguments: [String: Any]
    var actionType: ActionType = .create
    var itemType: String = ""
    var itemName: String = ""
    var changes: [SpeakActionChange] = []

    enum ActionType {
        case create, update, retire, activate, deactivate

        var icon: String {
            switch self {
            case .create: return "plus.circle.fill"
            case .update: return "pencil.circle.fill"
            case .retire: return "archivebox.fill"
            case .activate: return "bolt.circle.fill"
            case .deactivate: return "bolt.slash.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .create: return "Create"
            case .update: return "Update"
            case .retire: return "Retire"
            case .activate: return "Activate"
            case .deactivate: return "Deactivate"
            }
        }

        var appliedLabel: String {
            switch self {
            case .create: return "Created"
            case .update: return "Updated"
            case .retire: return "Retired"
            case .activate: return "Activated"
            case .deactivate: return "Deactivated"
            }
        }

        var color: UIColor {
            switch self {
            case .create: return DesignTokens.Colors.accent
            case .update: return .systemOrange
            case .retire: return DesignTokens.Colors.destructive
            case .activate: return DesignTokens.Colors.accent
            case .deactivate: return DesignTokens.Colors.textTertiary
            }
        }
    }
}

// MARK: - Speak History (in-memory, for undo)

/// A record of a single AI-driven change. Captures the BEFORE state so we can
/// reverse it. Stored only in memory on SpeakViewController — dies when the
/// app is killed, which is fine for "oops just did that" undo semantics.
struct SpeakHistoryEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let actionType: SpeakPendingToolCall.ActionType
    let itemName: String
    let entityKind: EntityKind

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        actionType: SpeakPendingToolCall.ActionType,
        itemName: String,
        entityKind: EntityKind
    ) {
        self.id = id
        self.timestamp = timestamp
        self.actionType = actionType
        self.itemName = itemName
        self.entityKind = entityKind
    }

    enum EntityKind {
        case directive(id: UUID, before: Directive?)   // nil before = this was a create
        case note(id: UUID, before: NotePage?)         // nil before = this was a create
        case journal(date: String, before: DayEntry?)  // nil before = this was a create
        case folder(id: UUID, before: Folder)          // rename only — always an update
        case mode(noteId: UUID, wasActive: Bool)       // activate/deactivate flip
    }
}

// MARK: - API Response Models

struct SpeakWhisperResponse: Decodable {
    let text: String
}

struct SpeakConverseRequest: Encodable {
    let messages: [Message]
    let localDate: String
    /// For continuation after client-side read tool execution
    let previousResponseId: String?
    let toolOutputs: [ToolOutput]?

    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ToolOutput: Encodable {
        let callId: String
        let output: String
    }
}

struct SpeakConverseResponse: Decodable {
    let message: String
    let toolCalls: [ToolCall]
    let remainingQuota: Int
    /// Read tool requests the client should execute locally, then call back with results
    let readToolRequests: [ReadToolRequest]?
    /// OpenAI response ID for continuation
    let responseId: String?

    struct ToolCall: Decodable {
        let id: String
        let function: String
        private let _arguments: [String: SpeakAnyCodable]
        var arguments: [String: Any] { _arguments.mapValues(\.value) }

        enum CodingKeys: String, CodingKey {
            case id, function
            case _arguments = "arguments"
        }
    }

    struct ReadToolRequest: Decodable {
        let callId: String
        let function: String
        private let _arguments: [String: SpeakAnyCodable]
        var parsedArguments: [String: Any] { _arguments.mapValues(\.value) }

        enum CodingKeys: String, CodingKey {
            case callId, function
            case _arguments = "arguments"
        }
    }
}

/// Lightweight type-erased Decodable for mixed JSON values in tool call arguments.
struct SpeakAnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if let arr = try? container.decode([SpeakAnyCodable].self) { value = arr.map(\.value) }
        else if let dict = try? container.decode([String: SpeakAnyCodable].self) { value = dict.mapValues(\.value) }
        else { value = NSNull() }
    }
}
