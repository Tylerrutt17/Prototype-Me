import SwiftUI
import SwiftData

/// Temporary debug view that dumps all Folder and NotePage records
/// so we can verify persistence and queries.
struct NotesDebugView: View {
    @Query private var folders: [Folder]
    @Query private var pages: [NotePage]
    @Query private var trackables: [Trackable]
    
    private var dumpText: String {
        var lines: [String] = []
        lines.append("Folders (\(folders.count)):")
        for f in folders.sorted(by: { $0.order < $1.order }) {
            lines.append("  { id: \(f.id), name: \(f.name), parentId: \(f.parentId ?? "nil"), order: \(f.order) }")
        }
        lines.append("")
        lines.append("Trackables (\(trackables.count)):")
        for t in trackables.sorted(by: { $0.order < $1.order }) {
            lines.append("  { id: \(t.id), name: \(t.name) }")
        }
        lines.append("")
        lines.append("Pages (\(pages.count)):")
        for p in pages.sorted(by: { $0.title < $1.title }) {
            lines.append("  { id: \(p.id), title: \(p.title), folderId: \(p.folderId ?? "nil"), isSystem: \(p.isSystem) }")
        }
        return lines.joined(separator: "\n")
    }
    
    var body: some View {
        ScrollView {
            Text(dumpText)
                .font(.system(.footnote, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Debug Data Dump")
    }
}

#Preview {
    let mc = try! ModelContainer(for: Folder.self, NotePage.self)
    let ctx = ModelContext(mc)
    ctx.insert(Folder(name: "Root"))
    ctx.insert(NotePage(title: "Sample"))
    return NavigationStack { NotesDebugView().modelContainer(mc) }
}
