import SwiftUI

extension Color {
    static func named(_ name: String) -> Color {
        switch name.lowercased() {
        case "red":        return .red
        case "orange":     return .orange
        case "yellow":     return .yellow
        case "green":      return .green
        case "blue":       return .blue
        case "indigo":     return .indigo
        case "violet", "purple": return .purple
        case "gray", "grey":     return .gray
        default:            return .accentColor
        }
    }
    /// Returns a lightly-tinted list-row background. Alpha can be customised per colour
    /// via the `rowAlpha` dictionary below.
    static var rowAlphas: [String: Double] = [
        // Light hues
        "red":     0.15,
        "orange":  0.12,
        "yellow":  0.12,
        // Deeper hues (slightly higher alpha)
        "green":   0.20,
        "blue":    0.25,
        "indigo":  0.15,
        "purple":  0.25,
        "violet":  0.25,
    ]

    static func rowBackground(named name: String?) -> Color? {
        guard let name else { return nil }
        let alpha = rowAlphas[name.lowercased()] ?? 0.15
        return Color.named(name).opacity(alpha)
    }
}
