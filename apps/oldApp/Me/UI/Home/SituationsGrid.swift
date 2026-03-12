import SwiftUI
import SwiftData

struct SituationsGrid: View {
    // Display situations respecting user-defined order in the list
    @Query(sort: \Situation.order) private var allSituations: [Situation]
    @State private var searchText: String = ""
    var onSelect: (Situation) -> Void

    private var filtered: [Situation] {
        guard !searchText.isEmpty else { return allSituations }
        // Keep the sort order consistent while filtering
        return allSituations
            .filter { $0.title.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.order < $1.order }
    }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 16)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search situations…", text: $searchText)
                .textFieldStyle(.roundedBorder)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(filtered, id: \.id) { sit in
                    Button(action: { onSelect(sit) }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.named(sit.colorName))
                                    .frame(width: 48, height: 48)
                                Image(systemName: sit.iconSystemName)
                                    .foregroundStyle(.white)
                            }
                            Text(sit.title)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: 80)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
