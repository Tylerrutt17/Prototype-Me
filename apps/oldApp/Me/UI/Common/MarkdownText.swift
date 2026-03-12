import SwiftUI
#if canImport(MarkdownUI)
import MarkdownUI
#endif

/// A view that renders Markdown with support for custom `[[color:NAME]]` spans.
/// It falls back to plain Text if MarkdownUI is unavailable or disabled via `AppConfig`.
struct MarkdownText: View {
    var markdown: String
    @Environment(\.markdownRendererEnabled) private var rendererEnabled // custom env value via AppConfig

    var body: some View {
        Group {
#if canImport(MarkdownUI)
            if rendererEnabled {
                Markdown(ColorSpanParser.text(from: markdown).string) // render converted plain markdown, color spans become Text parts
            } else {
                ColorSpanParser.text(from: markdown)
            }
#else
            ColorSpanParser.text(from: markdown)
#endif
        }
    }
}

private extension Text {
    /// Extracts raw string (lossy) – MarkdownUI only accepts String.
    var string: String {
        let mirror = Mirror(reflecting: self)
        if let storage = mirror.descendant("storage", "anyTextStorage", "storage") as? String {
            return storage
        }
        return ""
    }
}

// MARK: - Environment key for toggling renderer
private struct MarkdownRendererEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var markdownRendererEnabled: Bool {
        get { self[MarkdownRendererEnabledKey.self] }
        set { self[MarkdownRendererEnabledKey.self] = newValue }
    }
}
