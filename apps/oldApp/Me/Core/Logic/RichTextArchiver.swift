import Foundation
import UIKit

/// Utility to archive and unarchive `NSAttributedString` for persistence.
enum RichTextArchiver {
    static func encode(_ attributed: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: attributed, requiringSecureCoding: false)
    }

    static func decode(_ data: Data) -> NSAttributedString? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data)
    }
}
