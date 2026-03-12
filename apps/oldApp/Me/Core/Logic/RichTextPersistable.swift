import Foundation
import SwiftData
import UIKit
import RichEditorSwiftUI

/// Models that store rich text. `bodyMarkdown` is the single source of truth; `encodedText`
/// remains only for legacy reads and is no longer written.
protocol RichTextPersistable: AnyObject {
    var encodedText: Data?  { get set }
    var bodyMarkdown: String { get set }
}

extension RichTextPersistable {
    /// Returns plain text for the editor, preferring legacy encoded data if present.
    func loadEditorText() -> String {
        if let data = encodedText, let attr = RichTextArchiver.decode(data) {
            return attr.string
        }
        return RichNoteMarkdown.editorReadyText(from: bodyMarkdown)
    }

    /// Attempts to decode a stored RichText model from bodyMarkdown (JSON).
    func loadEditorRichText() -> RichText? {
        guard let data = bodyMarkdown.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(RichText.self, from: data)
    }

    /// Creates a RichEditorState seeded with stored rich text if available, otherwise HTML, otherwise plain text.
    func makeEditorState() -> RichEditorState {
        if let rt = loadEditorRichText() {
            return RichEditorState(richText: rt)
        }
        if bodyMarkdown.contains("<"),
           let rt = richTextFromHTML(bodyMarkdown) {
            return RichEditorState(richText: rt)
        }
        return RichEditorState(input: loadEditorText())
    }

    /// Persist the editor state as JSON RichText when possible; fall back to string.
    func persistRichText(from state: RichEditorState) {
        // Snapshot to avoid mutating while the editor is mid-update.
        let snapshot = NSAttributedString(attributedString: state.attributedString)

        // First preference: JSON built from the current attributed string to keep colors/styles.
        if let data = try? JSONEncoder().encode(richText(from: snapshot)),
           let json = String(data: data, encoding: .utf8) {
            bodyMarkdown = RichNoteMarkdown.normalizedForStorage(json)
            updatePlainCache(from: snapshot)
            encodedText = nil
            return
        }

        // Fallback: HTML from the attributed string to preserve styling.
        if let html = RichNoteMarkdown.htmlBody(from: snapshot) {
            bodyMarkdown = RichNoteMarkdown.normalizedForStorage(html)
            updatePlainCache(from: snapshot)
            encodedText = nil
            return
        }

        // Last resort: plain text.
        bodyMarkdown = RichNoteMarkdown.normalizedForStorage(snapshot.string)
        updatePlainCache(from: snapshot)
        encodedText = nil
    }
}

// MARK: - Helpers
private extension RichTextPersistable {
    func richText(from attr: NSAttributedString) -> RichText {
        guard attr.length > 0 else { return RichText() }
        let full = attr.string as NSString
        var spans: [RichTextSpan] = []

        attr.enumerateAttributes(in: NSRange(location: 0, length: attr.length)) { attributes, range, _ in
            let substring = full.substring(with: range)
            guard !substring.isEmpty else { return }

            var richAttr = RichAttributes()
            let defaultSize = CGFloat.standardRichTextFontSize
            let defaultFontNames: Set<String> = {
                let regular = UIFont.systemFont(ofSize: defaultSize).fontName
                let regularW = UIFont.systemFont(ofSize: defaultSize, weight: .regular).fontName
                return [regular, regularW]
            }()

            if let font = attributes[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { richAttr = richAttr.copy(bold: true) }
                if traits.contains(.traitItalic) { richAttr = richAttr.copy(italic: true) }
                if abs(font.pointSize - defaultSize) > .ulpOfOne {
                    richAttr = richAttr.copy(size: Int(font.pointSize))
                }
                let name = font.fontName
                let isSystemish = name.hasPrefix(".SFUI") || defaultFontNames.contains(name)
                if !isSystemish {
                    richAttr = richAttr.copy(font: name)
                }
            }

            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                richAttr = richAttr.copy(underline: true)
            }
            if let strike = attributes[.strikethroughStyle] as? Int, strike != 0 {
                richAttr = richAttr.copy(strike: true)
            }

            if let color = attributes[.foregroundColor] as? UIColor,
               let hex = color.hexString {
                richAttr = richAttr.copy(color: hex)
            }

            if let bg = attributes[.backgroundColor] as? UIColor,
               let hex = bg.hexString {
                richAttr = richAttr.copy(background: hex)
            }

            // Only attach attributes if any meaningful styling exists.
            let hasAttr = richAttr.bold == true
            || richAttr.italic == true
            || richAttr.underline == true
            || richAttr.strike == true
            || richAttr.size != nil
            || richAttr.font != nil
            || richAttr.color != nil
            || richAttr.background != nil

            spans.append(RichTextSpan(insert: substring, attributes: hasAttr ? richAttr : nil))
        }

        return RichText(spans: spans)
    }

    func richTextFromHTML(_ html: String) -> RichText? {
        guard let attr = attributedStringFromHTML(html) else { return nil }
        return richText(from: attr)
    }

    func attributedStringFromHTML(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    /// Stores a plain-text preview for models that need it (e.g., Intervention).
    func updatePlainCache(from snapshot: NSAttributedString) {
        let plain = RichNoteMarkdown.editorReadyText(from: snapshot.string)
        if let iv = self as? Intervention {
            iv.detailsPlain = plain
        }
    }
}

private extension UIColor {
    var hexString: String? {
        guard let components = cgColor.components else { return nil }
        let r = components[0]
        let g = components.count > 2 ? components[1] : r
        let b = components.count > 2 ? components[2] : r
        let a = components.count > 3 ? components[3] : 1.0

        if a < 1.0 {
            return String(
                format: "#%02lX%02lX%02lX%02lX",
                lround(Double(r * 255)),
                lround(Double(g * 255)),
                lround(Double(b * 255)),
                lround(Double(a * 255))
            )
        } else {
            return String(
                format: "#%02lX%02lX%02lX",
                lround(Double(r * 255)),
                lround(Double(g * 255)),
                lround(Double(b * 255))
            )
        }
    }
}

