import Foundation
import UIKit

/// Utilities for normalizing the legacy markdown into plain text for the new editor.
enum RichNoteMarkdown {
    /// Produces editor-friendly plain text by stripping legacy tags and collapsing markdown.
    static func editorReadyText(from markdown: String) -> String {
        let stripped = stripLegacyTags(markdown)
        if let parsed = try? NSAttributedString(markdown: stripped) {
            return parsed.string
        }
        return stripped
    }

    /// Convert markdown (with legacy tags stripped) to HTML for seeding RichEditorSwiftUI.
    /// Falls back to the raw markdown if conversion fails.
    static func editorReadyHTML(from markdown: String) -> String {
        let htmlWithLegacy = convertLegacyTagsToHTML(markdown)
        let stripped = stripLegacyTags(markdown)
        guard let attr = try? NSAttributedString(markdown: htmlWithLegacy) ?? NSAttributedString(markdown: stripped) else {
            return htmlWithLegacy
        }
        return htmlBody(from: attr) ?? htmlWithLegacy
    }

    /// Convert an attributed string to a minimal HTML body (no head/meta).
    static func htmlBody(from attr: NSAttributedString) -> String? {
        let range = NSRange(location: 0, length: attr.length)
        guard let data = try? attr.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html]),
              let html = String(data: data, encoding: .utf8) else { return nil }
        // Extract body innerHTML if present to avoid meta/header noise.
        if let bodyStart = html.range(of: "<body>"),
           let bodyEnd = html.range(of: "</body>") {
            let inner = html[bodyStart.upperBound..<bodyEnd.lowerBound]
            return String(inner)
        }
        return html
    }

    /// Sanitizes outgoing text for storage (trim but otherwise preserve user input).
    static func normalizedForStorage(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Remove legacy [[u]] and [[color:...]] wrappers while preserving inner text.
    private static func stripLegacyTags(_ markdown: String) -> String {
        var output = markdown
        let underlinePattern = #"(?s)\[\[u\]\](.*?)\[\[/u\]\]"#
        let colorPattern = #"(?s)\[\[color:[^\]]+\]\](.*?)\[\[/color\]\]"#
        output = output.replacingOccurrences(of: underlinePattern, with: "$1", options: .regularExpression)
        output = output.replacingOccurrences(of: colorPattern, with: "$1", options: .regularExpression)
        return output
    }

    /// Convert legacy tags to inline HTML so colors/underline survive seeding.
    private static func convertLegacyTagsToHTML(_ markdown: String) -> String {
        var output = markdown
        // underline
        let underlinePattern = #"(?s)\[\[u\]\](.*?)\[\[/u\]\]"#
        output = output.replacingOccurrences(of: underlinePattern, with: "<u>$1</u>", options: .regularExpression)
        // color
        let colorPattern = #"(?s)\[\[color:([^\]]+)\]\](.*?)\[\[/color\]\]"#
        output = output.replacingOccurrences(of: colorPattern, with: "<span style=\"color:$1\">$2</span>", options: .regularExpression)
        return output
    }
}
