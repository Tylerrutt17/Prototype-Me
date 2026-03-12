import SwiftUI
import SwiftData

struct SituationsCarousel: View {
    @Query(sort: \Situation.title) private var allSituations: [Situation]
    @State private var searchText = ""
    var onSelect: (Situation) -> Void

    private var filtered: [Situation] {
        guard !searchText.isEmpty else { return allSituations }
        return allSituations.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    searchField
                    ForEach(filtered, id: \.id) { sit in
                        Button(action: { onSelect(sit) }) {
                            VStack {
                                Image(systemName: sit.iconSystemName)
                                    .font(.title2)
                                    .padding(16)
                                    .background(Circle().fill(Color.named(sit.colorName)))
                                    .foregroundStyle(.white)
                                Text(sit.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var searchField: some View {
        TextField("Search", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .frame(width: 140)
    }
}

#Preview {
    let container = try! ModelContainer(for: Situation.self)
    let ctx = ModelContext(container)
    let s = Situation(title: "Presentation")
    ctx.insert(s)
    return SituationsCarousel { _ in }.modelContainer(container)
        .previewLayout(.sizeThatFits)
}
