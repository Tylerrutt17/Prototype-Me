import Foundation
import SwiftUI

/// Parses custom color span markup `[[color:NAME]]text[[/color]]` and converts it into a `Text` view with colored segments.
/// Usage:
/// ```swift
/// ColorSpanParser.text(from: "Normal [[color:orange]]Orange[[/color]] again")
/// ```
/// If the markup is invalid (unknown color, missing close) the raw text is returned.
struct ColorSpanParser {
    /// Allowed color names mapped to SwiftUI `Color`
    private static let colorMap: [String: Color] = [
        "red": .red,
        "orange": .orange,
        "yellow": .yellow,
        "green": .green,
        "blue": .blue,
        "indigo": .indigo,
        "violet": .purple,
        "gray": .gray
    ]

    /// Returns a SwiftUI `Text` built from the input string, applying foreground styles where color spans are found.
    static func text(from source: String) -> Text {
        // Fast-path: no custom markup
        guard source.contains("[[color:") else { return Text(source) }

        var result = Text("")
        var searchStart = source.startIndex

        while let openRange = source.range(of: "[[color:", range: searchStart..<source.endIndex) {
            // Append text before the tag
            if openRange.lowerBound > searchStart {
                let prefix = String(source[searchStart..<openRange.lowerBound])
                result = result + Text(prefix)
            }

            // Locate end of opening tag (]]).
            let colorNameStart = openRange.upperBound
            guard let endOpen = source.range(of: "]]", range: colorNameStart..<source.endIndex) else {
                // malformed – append rest and exit
                let remainder = String(source[openRange.lowerBound...])
                result = result + Text(remainder)
                return result
            }
            let colorName = String(source[colorNameStart..<endOpen.lowerBound])
            let spanStart = endOpen.upperBound // text after opening tag

            // Locate closing tag
            guard let closeRange = source.range(of: "[[/color]]", range: spanStart..<source.endIndex) else {
                // malformed – append rest and exit
                let remainder = String(source[openRange.lowerBound...])
                result = result + Text(remainder)
                return result
            }

            let spanText = String(source[spanStart..<closeRange.lowerBound])
            if let color = colorMap[colorName.lowercased()] {
                result = result + Text(spanText).foregroundStyle(color)
            } else {
                // Unknown color → render plain
                result = result + Text(spanText)
            }

            // Move search start after closing tag
            searchStart = closeRange.upperBound
        }

        // Append remainder
        if searchStart < source.endIndex {
            let tail = String(source[searchStart...])
            result = result + Text(tail)
        }
        return result
    }
}
