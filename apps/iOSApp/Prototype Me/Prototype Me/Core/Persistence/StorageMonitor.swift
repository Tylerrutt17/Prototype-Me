import Foundation

/// Monitors available device storage and posts notifications when space is critically low.
/// Services check `canSafelyWrite` before DB writes to avoid silent data loss.
final class StorageMonitor: Sendable {

    /// Posted when storage drops below the warning threshold.
    /// `userInfo["availableMB"]` contains the remaining MB as `Int`.
    static let storageWarningNotification = Notification.Name("StorageMonitor.lowStorage")

    /// Posted when a DB write fails due to a storage-related error.
    /// `userInfo["message"]` contains a user-facing description.
    static let writeFailedNotification = Notification.Name("StorageMonitor.writeFailed")

    /// Minimum free space (in bytes) before we warn the user. 50 MB.
    private static let warningThreshold: Int64 = 50 * 1024 * 1024

    /// Minimum free space (in bytes) before we block writes. 10 MB.
    private static let criticalThreshold: Int64 = 10 * 1024 * 1024

    /// Returns the available disk space in bytes, or nil if it can't be determined.
    static func availableBytes() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let capacity = values.volumeAvailableCapacityForImportantUsage else {
            return nil
        }
        return capacity
    }

    /// Whether there's enough disk space for a write operation.
    /// Returns false when below the critical threshold (10 MB).
    static var canSafelyWrite: Bool {
        guard let available = availableBytes() else { return true } // Assume OK if unknown
        return available > criticalThreshold
    }

    /// Whether storage is low enough to warn the user (below 50 MB).
    static var isStorageLow: Bool {
        guard let available = availableBytes() else { return false }
        return available < warningThreshold
    }

    /// Available megabytes for display purposes.
    static var availableMB: Int {
        guard let bytes = availableBytes() else { return -1 }
        return Int(bytes / (1024 * 1024))
    }

    /// Posts a warning notification if storage is low. Call periodically (e.g. on app foreground).
    static func checkAndNotify() {
        if isStorageLow {
            NotificationCenter.default.post(
                name: storageWarningNotification,
                object: nil,
                userInfo: ["availableMB": availableMB]
            )
        }
    }

    /// Call this when a DB write fails. It checks if the error is storage-related
    /// and posts the appropriate notification.
    static func handleWriteError(_ error: Error) {
        let message: String
        let nsError = error as NSError

        // GRDB wraps SQLite errors — check for SQLITE_FULL (13)
        if nsError.domain == "GRDB.DatabaseError" && nsError.code == 13 {
            message = "Your device is out of storage. Free up space to continue saving."
        } else if nsError.domain == "GRDB.DatabaseError" && (nsError.code == 10 || nsError.code == 14) {
            // SQLITE_IOERR (10) or SQLITE_CANTOPEN (14)
            message = "Unable to save — disk may be full or unavailable."
        } else {
            message = "Save failed: \(error.localizedDescription)"
        }

        NotificationCenter.default.post(
            name: writeFailedNotification,
            object: nil,
            userInfo: ["message": message, "error": error]
        )
    }
}
