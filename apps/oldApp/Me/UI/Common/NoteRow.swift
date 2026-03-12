import SwiftUI
import SwiftData

/// Consistent visual representation of a NotePage.
struct NoteRow: View {
    let page: NotePage
    @Query private var trackables: [Trackable]

    var body: some View {
        let tint = noteColor()
        HStack(alignment: .center, spacing: 8) {
            Text(page.title)
                .font(.body)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .padding(6)
        .listRowInsets(EdgeInsets())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteColor() -> Color {
        if let cname = page.colorName { return Color.named(cname) }
        if let tid = page.interventions?.first?.trackableId,
           let t = trackables.first(where: { $0.id == tid }) {
            return Color.named(t.colorName)
        }
        return .primary
    }
}

#Preview {
    let mc = try! ModelContainer(for: NotePage.self, Trackable.self)
    let ctx = ModelContext(mc)
    let p = NotePage(title: "Sample note", colorName: "orange")
    ctx.insert(p)
    return List { NoteRow(page: p) }.modelContainer(mc)
}
