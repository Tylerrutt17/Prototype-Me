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

// MARK: - API Response Models

struct SpeakWhisperResponse: Decodable {
    let text: String
}

struct SpeakConverseResponse: Decodable {
    let message: String
    let toolCalls: [ToolCall]
    let remainingQuota: Int

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
