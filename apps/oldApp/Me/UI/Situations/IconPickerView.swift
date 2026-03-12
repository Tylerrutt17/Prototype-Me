import SwiftUI

struct IconPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    // A curated list of commonly used SF Symbols; adjust as desired
    private let icons: [String] = [
        "figure.walk", "figure.run", "figure.stand", "heart", "heart.fill", "star", "star.fill",
        "book", "pencil", "graduationcap", "cart", "briefcase", "bolt", "paperplane",
        "phone", "envelope", "bell", "music.note", "mic", "gamecontroller", "globe",
        "leaf", "sun.max", "moon", "sparkles", "flame", "cloud", "snowflake", "drop",
        "camera", "video", "play", "pause", "stop", "record.circle", "flag", "location",
        "map", "calendar", "clock", "alarm", "timer", "banknote", "creditcard", "gift",
        "lightbulb", "brain", "hare", "tortoise", "car", "bicycle", "tram", "airplane",
        "house", "building.2", "person", "person.2", "person.3", "person.crop.circle",
        "bag", "bed.double", "cup.and.saucer", "fork.knife", "wineglass", "scissors",
        "wand.and.stars", "paintbrush", "hammer", "wrench", "paperclip", "link", "shield",
        "lock", "key", "trash", "folder", "doc", "chart.bar", "waveform", "cpu", "gear"
    ]

    // Grid layout
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selection = icon
                        }) {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(selection == icon ? .white : .primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(selection == icon ? Color.accentColor : Color(.systemGray5))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Icon")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

#Preview {
    IconPickerView(selection: .constant("heart.fill"))
}
