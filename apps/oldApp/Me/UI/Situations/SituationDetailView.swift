import SwiftUI
import SwiftData

struct SituationDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NotePage.title) private var pages: [NotePage]
    @Query(sort: \Intervention.title) private var interventions: [Intervention]

    @Bindable var situation: Situation
    @State private var showingPicker = false
    @State private var creatingNew = false
    @State private var pickingIcon = false
    @State private var linkSearch = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            metaSection
            pagesSection
            interventionsSection
        }
        .environment(\.editMode, $editMode)
        .navigationTitle(situation.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingPicker = true }) {
                    Label("Add", systemImage: "link.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingPicker) { linkPicker }
        .sheet(isPresented: $creatingNew) { newNoteSheet }
        .sheet(isPresented: $pickingIcon) { IconPickerView(selection: $situation.iconSystemName) }
    }

    // MARK: Sections
    private var metaSection: some View {
        Section("Details") {
            TextField("Title", text: $situation.title)

            // Icon picker row
            Button(action: { pickingIcon = true }) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.named(situation.colorName))
                            .frame(width: 34, height: 34)
                        Image(systemName: situation.iconSystemName)
                            .foregroundStyle(.white)
                    }
                    Text(situation.iconSystemName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }

            // Color picker row (simple textual list of allowed names)
            Picker("Color", selection: $situation.colorName) {
                ForEach(["red","orange","yellow","green","blue","indigo","violet","gray"], id: \ .self) { name in
                    HStack {
                        Circle().fill(Color.named(name)).frame(width: 14, height: 14)
                        Text(name.capitalized)
                    }.tag(name)
                }
            }
        }
    }

    private var pagesSection: some View {
        Section("Linked Pages") {
            if linkedPages.isEmpty {
                Text("No pages linked").foregroundStyle(.secondary)
            }
            ForEach(linkedPages, id: \.id) { p in
                NavigationLink {
                    NotePageDetailView(page: p)
                } label: {
                    HStack {
                        Text(p.title)
                        if let fname = folderName(for: p) {
                            Text("(\(fname))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { idx in removePages(at: idx) }
            .onMove(perform: movePages)
        }
    }

    private var interventionsSection: some View {
        Section("Linked Directives") { // visually rename
            if linkedInterventions.isEmpty {
                Text("No directives linked").foregroundStyle(.secondary) // visually rename
            }
            ForEach(linkedInterventions, id: \.id) { iv in
                NavigationLink {
                    InterventionEditorView(intervention: iv)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(iv.title)
                        if !iv.detailsMarkdown.isEmpty {
                            Text(iv.detailsMarkdown)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { idx in removeInterventions(at: idx) }
            .onMove(perform: moveInterventions)
        }
    }

    // MARK: Link sets
    private var linkedPages: [NotePage] {
        situation.pageIds.compactMap { id in pages.first(where: { $0.id == id }) }
    }

    private var linkedInterventions: [Intervention] {
        situation.interventionIds.compactMap { id in interventions.first(where: { $0.id == id }) }
    }

    // MARK: Actions
    private func removePages(at offsets: IndexSet) {
        for i in offsets {
            let id = linkedPages[i].id
            situation.pageIds.removeAll(where: { $0 == id })
        }
    }

    private func movePages(from offsets: IndexSet, to destination: Int) {
        var ids = situation.pageIds
        ids.move(fromOffsets: offsets, toOffset: destination)
        situation.pageIds = ids
    }

    private func removeInterventions(at offsets: IndexSet) {
        for i in offsets {
            let id = linkedInterventions[i].id
            situation.interventionIds.removeAll { $0 == id }
        }
    }

    private func moveInterventions(from offsets: IndexSet, to destination: Int) {
        var ids = situation.interventionIds
        ids.move(fromOffsets: offsets, toOffset: destination)
        situation.interventionIds = ids
    }

    // MARK: Picker sheet
    private var linkPicker: some View {
        NavigationStack {
            Form {
                TextField("Search…", text: $linkSearch)
                    .textFieldStyle(.roundedBorder)
                Section("Pages") {
                    ForEach(filteredPages, id: \.id) { p in
                        Toggle(p.title, isOn: Binding(
                            get: { situation.pageIds.contains(p.id) },
                            set: { newVal in
                                if newVal {
                                    if !situation.pageIds.contains(p.id) { situation.pageIds.append(p.id) }
                                } else {
                                    situation.pageIds.removeAll { $0 == p.id }
                                }
                            }))
                    }
                }
                Section("Directives") { // visually rename
                    ForEach(filteredInterventions, id: \.id) { iv in
                        Toggle(iv.title, isOn: Binding(
                            get: { situation.interventionIds.contains(iv.id) },
                            set: { newVal in
                                if newVal {
                                    if !situation.interventionIds.contains(iv.id) { situation.interventionIds.append(iv.id) }
                                } else {
                                    situation.interventionIds.removeAll { $0 == iv.id }
                                }
                            }))
                    }
                }
            }
            .navigationTitle("Add Links")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingPicker = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { creatingNew = true }) { Image(systemName: "plus") }
                        .help("Create new note and link")
                }
            }
        }
    }

    // New note sheet
    private var newNoteSheet: some View {
        NavigationStack {
            let newPage = NotePage(title: "New Note")
            NotePageDetailView(page: newPage)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { context.delete(newPage); creatingNew = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            context.insert(newPage)
                            situation.pageIds.append(newPage.id)
                            creatingNew = false
                        }
                    }
                }
        }
    }

    private func folderName(for page: NotePage) -> String? {
        guard let fid = page.folderId else { return nil }
        return try? context.fetch(FetchDescriptor<Folder>(predicate: #Predicate { $0.id == fid })).first?.name
    }

    private var filteredPages: [NotePage] {
        guard !linkSearch.isEmpty else { return pages }
        return pages.filter { $0.title.localizedCaseInsensitiveContains(linkSearch) }
    }

    private var filteredInterventions: [Intervention] {
        guard !linkSearch.isEmpty else { return interventions }
        return interventions.filter { $0.title.localizedCaseInsensitiveContains(linkSearch) }
    }
}
