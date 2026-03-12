import SwiftUI
import SwiftData

struct TagSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var tagName: String = ""
    @State private var tagWeight: Int = 1
    
    // Binding to the DayLog being edited
    @Bindable var dayLog: DayLog
    
    init(dayLog: DayLog) {
        self.dayLog = dayLog
    }
    
    var body: some View {
        NavigationStack {
            List {
                existingTagsSection
                newTagSection
            }
            .navigationTitle("Attach Factors")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var existingTagsSection: some View {
        Section("Your Tags") {
            ForEach(sortedTags(), id: \.id) { tag in
                HStack {
                    Toggle(isOn: binding(for: tag)) {
                        Text(tag.name)
                        Spacer()
                        Text(weightText(for: tag))
                            .foregroundStyle(weightColor(for: tag))
                    }
                }
            }
        }
    }
    
    private var newTagSection: some View {
        Section("Create New") {
            TextField("Tag name", text: $tagName)
            Stepper(value: $tagWeight, in: -5...5) {
                Text("Weight: \(tagWeight)")
                    .foregroundStyle(weightColor(tagWeight))
            }
            Button("Add Tag") {
                addTag()
            }
            .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: Helpers
    private func sortedTags() -> [Tag] {
        let predicate = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        let all = (try? context.fetch(predicate)) ?? []
        return all
    }
    
    private func binding(for tag: Tag) -> Binding<Bool> {
        Binding {
            (dayLog.tags ?? []).contains { $0.tag == tag }
        } set: { on in
            if on {
                let join = DayLogTag(dayLog: dayLog, tag: tag)
                if dayLog.tags == nil { dayLog.tags = [] }
                dayLog.tags?.append(join)
            } else {
                dayLog.tags?.removeAll { $0.tag == tag }
            }
        }
    }
    
    private func addTag() {
        let name = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let tag = TagService.tag(named: name, defaultWeight: tagWeight, in: context)
        let join = DayLogTag(dayLog: dayLog, tag: tag, customWeight: tagWeight)
        if dayLog.tags == nil { dayLog.tags = [] }
        dayLog.tags?.append(join)
        tagName = ""
        tagWeight = 1
    }
    
    private func weightText(for tag: Tag) -> String {
        let w = tag.defaultWeight
        return w > 0 ? "+\(w)" : "\(w)"
    }
    
    private func weightColor(_ weight: Int) -> Color {
        if weight > 0 { return .green }
        if weight < 0 { return .red }
        return .secondary
    }
    private func weightColor(for tag: Tag) -> Color { weightColor(tag.defaultWeight) }
}
