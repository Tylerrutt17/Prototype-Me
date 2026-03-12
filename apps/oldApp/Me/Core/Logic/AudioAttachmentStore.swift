import AVFoundation
import Foundation

enum AudioAttachmentStoreError: Error {
    case fileTooLarge
    case copyFailed
    case recordingUnavailable
}

struct AudioAttachmentStore {
    static let shared = AudioAttachmentStore()
    private let folderName = "AudioAttachments"
    private let maxBytes: Int64 = 30 * 1_024 * 1_024 // 30 MB safety cap

    private var baseURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(folderName, isDirectory: true)
    }

    func ensureFolder() throws {
        let url = baseURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutable = url
            try mutable.setResourceValues(resourceValues)
        }
    }

    func url(for fileName: String) throws -> URL {
        try ensureFolder()
        return baseURL.appendingPathComponent(fileName)
    }

    @discardableResult
    func copyIn(from source: URL, suggestedName: String?) throws -> (fileName: String, size: Int64) {
        try ensureFolder()
        let size = try fileSize(at: source)
        guard size <= maxBytes else { throw AudioAttachmentStoreError.fileTooLarge }

        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let base = (suggestedName ?? source.deletingPathExtension().lastPathComponent).isEmpty ? "Audio" : suggestedName ?? source.deletingPathExtension().lastPathComponent
        let uniqueName = makeUniqueFileName(base: base, ext: ext)
        let dest = baseURL.appendingPathComponent(uniqueName)

        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            throw AudioAttachmentStoreError.copyFailed
        }
        return (uniqueName, size)
    }

    func remove(fileName: String) {
        let url = baseURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func newRecordingURL() throws -> URL {
        try ensureFolder()
        let name = makeUniqueFileName(base: "Recording", ext: "m4a")
        return baseURL.appendingPathComponent(name)
    }

    func fileSize(at url: URL) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func makeUniqueFileName(base: String, ext: String) -> String {
        let sanitizedBase = base.replacingOccurrences(of: "[^A-Za-z0-9-_ ]", with: "-", options: .regularExpression)
        let uuid = UUID().uuidString.prefix(8)
        return "\(sanitizedBase)-\(uuid).\(ext)"
    }
}
