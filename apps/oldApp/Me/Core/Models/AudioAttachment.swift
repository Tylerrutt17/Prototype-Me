import Foundation
import SwiftData

public enum AudioAttachmentKind: String, Codable {
    case note
    case directive
}

@Model
public final class AudioAttachment {
    @Attribute public var id: String = UUID().uuidString
    public var fileName: String = ""
    public var displayName: String = ""
    public var durationSeconds: Double = 0
    public var fileSizeBytes: Int = 0
    @Attribute public var createdAt: Date = Date()
    @Attribute public var kindRaw: String = AudioAttachmentKind.note.rawValue
    /// Parent identifier of the owning note or directive.
    public var parentId: String = ""

    public init(fileName: String,
                displayName: String,
                durationSeconds: Double,
                fileSizeBytes: Int,
                kind: AudioAttachmentKind,
                parentId: String,
                createdAt: Date = Date()) {
        self.fileName = fileName
        self.displayName = displayName
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.kindRaw = kind.rawValue
        self.parentId = parentId
        self.createdAt = createdAt
    }

    public var kind: AudioAttachmentKind {
        get { AudioAttachmentKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}
