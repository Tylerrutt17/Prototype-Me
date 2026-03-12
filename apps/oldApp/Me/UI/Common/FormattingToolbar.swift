import SwiftUI

/// Simple toolbar with buttons that insert common Markdown snippets into a bound text field.
struct FormattingToolbar: View {
    @Binding var text: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button("**B**") { insert("**bold**", offset: 2) }
                    .accessibilityLabel("Bold")
                Button("*I*") { insert("*italic*", offset: 1) }
                    .accessibilityLabel("Italic")
                Button("• List") { insert("- item\n") }
                    .accessibilityLabel("List item")
                Menu {
                    ForEach(["red","orange","yellow","green","blue","indigo","violet","gray"], id: \..self) { name in
                        Button(name.capitalized) { insert("[[color:\(name)]]text[[/color]]", offset: 9 + name.count) }
                    }
                } label: {
                    Label("Color", systemImage: "paintbrush")
                }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func insert(_ snippet: String, offset: Int = 0) {
        // Append snippet and place cursor (offset chars) before ending if using UITextView selection later.
        text.append(snippet)
    }
}

#Preview {
    @State var sample = "Sample markdown"
    return FormattingToolbar(text: $sample)
}
