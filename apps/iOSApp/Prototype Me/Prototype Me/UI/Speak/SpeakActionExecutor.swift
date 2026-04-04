import Foundation

/// Handles tool call description, enrichment with current state, and execution against local services.
final class SpeakActionExecutor {

    let directiveService: DirectiveService?
    let noteService: NoteService?
    let dayEntryService: DayEntryService?
    let modeService: ModeService?
    let folderService: FolderService?

    init(
        directiveService: DirectiveService?,
        noteService: NoteService?,
        dayEntryService: DayEntryService?,
        modeService: ModeService?,
        folderService: FolderService?
    ) {
        self.directiveService = directiveService
        self.noteService = noteService
        self.dayEntryService = dayEntryService
        self.modeService = modeService
        self.folderService = folderService
    }

    // MARK: - Describe

    func describe(_ toolCall: SpeakPendingToolCall) -> String {
        let args = toolCall.arguments
        switch toolCall.function {
        case "create_directive":
            return "Create directive: \(args["title"] as? String ?? "Untitled")"
        case "update_directive":
            return "Update directive: \(args["title"] as? String ?? args["id"] as? String ?? "unknown")"
        case "retire_directive":
            return "Retire directive"
        case "create_journal_entry":
            return "Log journal entry for \(args["date"] as? String ?? "today")"
        case "create_note":
            return "Create \(args["kind"] as? String ?? "regular") note: \(args["title"] as? String ?? "Untitled")"
        case "activate_mode":
            return "Activate mode"
        case "deactivate_mode":
            return "Deactivate mode"
        case "update_note":
            return "Update note: \(args["title"] as? String ?? args["id"] as? String ?? "unknown")"
        case "rename_folder":
            return "Rename folder to: \(args["name"] as? String ?? "unknown")"
        default:
            return toolCall.function
        }
    }

    // MARK: - Enrich

    func enrich(_ toolCalls: [SpeakPendingToolCall]) async -> [SpeakPendingToolCall] {
        var enriched: [SpeakPendingToolCall] = []
        for var tc in toolCalls {
            let args = tc.arguments
            switch tc.function {
            case "create_directive":
                tc.actionType = .create
                tc.itemType = "directive"
                tc.itemName = args["title"] as? String ?? "Untitled"
                tc.changes = [SpeakActionChange(field: "title", oldValue: nil, newValue: tc.itemName)]
                if let body = args["body"] as? String {
                    tc.changes.append(SpeakActionChange(field: "body", oldValue: nil, newValue: body))
                }

            case "update_directive":
                tc.actionType = .update
                tc.itemType = "directive"
                if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr),
                   let directive = try? await directiveService?.fetch(id: id) {
                    tc.itemName = directive.title
                    if let newTitle = args["title"] as? String, newTitle != directive.title {
                        tc.changes.append(SpeakActionChange(field: "title", oldValue: directive.title, newValue: newTitle))
                    }
                    if let newBody = args["body"] as? String, newBody != (directive.body ?? "") {
                        tc.changes.append(SpeakActionChange(field: "body", oldValue: directive.body, newValue: newBody))
                    }
                } else {
                    tc.itemName = args["title"] as? String ?? "Unknown"
                }

            case "retire_directive":
                tc.actionType = .retire
                tc.itemType = "directive"
                if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr),
                   let directive = try? await directiveService?.fetch(id: id) {
                    tc.itemName = directive.title
                }

            case "create_journal_entry":
                tc.actionType = .create
                tc.itemType = "journal"
                tc.itemName = args["date"] as? String ?? "today"
                if let diary = args["diary"] as? String {
                    tc.changes.append(SpeakActionChange(field: "diary", oldValue: nil, newValue: diary))
                }
                if let rating = args["rating"] as? Int {
                    tc.changes.append(SpeakActionChange(field: "rating", oldValue: nil, newValue: "\(rating)/10"))
                }

            case "create_note":
                tc.actionType = .create
                tc.itemType = args["kind"] as? String ?? "note"
                tc.itemName = args["title"] as? String ?? "Untitled"
                tc.changes = [SpeakActionChange(field: "title", oldValue: nil, newValue: tc.itemName)]

            case "update_note":
                tc.actionType = .update
                tc.itemType = "note"
                if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr),
                   let note = try? await noteService?.fetch(id: id) {
                    tc.itemName = note.title
                    if let newTitle = args["title"] as? String, newTitle != note.title {
                        tc.changes.append(SpeakActionChange(field: "title", oldValue: note.title, newValue: newTitle))
                    }
                    if let newBody = args["body"] as? String, newBody != note.body {
                        tc.changes.append(SpeakActionChange(field: "body", oldValue: String(note.body.prefix(80)), newValue: String(newBody.prefix(80))))
                    }
                } else {
                    tc.itemName = args["title"] as? String ?? "Unknown"
                }

            case "rename_folder":
                tc.actionType = .update
                tc.itemType = "folder"
                if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr),
                   let folder = try? await folderService?.fetch(id: id) {
                    tc.itemName = folder.name
                    if let newName = args["name"] as? String {
                        tc.changes.append(SpeakActionChange(field: "name", oldValue: folder.name, newValue: newName))
                    }
                }

            case "activate_mode":
                tc.actionType = .activate
                tc.itemType = "mode"
                tc.itemName = "Mode"

            case "deactivate_mode":
                tc.actionType = .deactivate
                tc.itemType = "mode"
                tc.itemName = "Mode"

            default:
                tc.itemName = tc.function
            }
            enriched.append(tc)
        }
        return enriched
    }

    // MARK: - Execute

    func execute(_ toolCall: SpeakPendingToolCall) async -> String {
        do {
            switch toolCall.function {
            case "create_directive":
                let title = toolCall.arguments["title"] as? String ?? "Untitled"
                let body = toolCall.arguments["body"] as? String
                let directive = try await directiveService?.create(title: title, body: body)
                return "Created directive: \(directive?.title ?? title)"

            case "update_directive":
                guard let idString = toolCall.arguments["id"] as? String,
                      let id = UUID(uuidString: idString),
                      var directive = try await directiveService?.fetch(id: id) else {
                    return "Could not find directive to update"
                }
                if let title = toolCall.arguments["title"] as? String { directive.title = title }
                if let body = toolCall.arguments["body"] as? String { directive.body = body }
                try await directiveService?.update(directive)
                return "Updated directive: \(directive.title)"

            case "retire_directive":
                guard let idString = toolCall.arguments["id"] as? String,
                      let id = UUID(uuidString: idString) else {
                    return "Could not find directive to retire"
                }
                try await directiveService?.archive(id: id)
                return "Retired directive"

            case "create_journal_entry":
                let date = toolCall.arguments["date"] as? String ?? {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    return f.string(from: Date())
                }()
                let diary = toolCall.arguments["diary"] as? String ?? ""
                let rating = toolCall.arguments["rating"] as? Int
                let tags = toolCall.arguments["tags"] as? [String] ?? []
                _ = try await dayEntryService?.createOrUpdate(date: date, rating: rating, diary: diary, tags: tags)
                return "Saved journal entry for \(date)"

            case "create_note":
                let title = toolCall.arguments["title"] as? String ?? "Untitled"
                let body = toolCall.arguments["body"] as? String ?? ""
                let kindStr = toolCall.arguments["kind"] as? String ?? "regular"
                let kind = NoteKind(rawValue: kindStr) ?? .regular
                _ = try await noteService?.create(title: title, body: body, kind: kind)
                return "Created \(kindStr) note: \(title)"

            case "activate_mode":
                guard let idString = toolCall.arguments["noteId"] as? String,
                      let noteId = UUID(uuidString: idString) else {
                    return "Could not find mode to activate"
                }
                try await modeService?.activate(noteId: noteId)
                return "Activated mode"

            case "deactivate_mode":
                guard let idString = toolCall.arguments["noteId"] as? String,
                      let noteId = UUID(uuidString: idString) else {
                    return "Could not find mode to deactivate"
                }
                try await modeService?.deactivate(noteId: noteId)
                return "Deactivated mode"

            case "update_note":
                guard let idString = toolCall.arguments["id"] as? String,
                      let id = UUID(uuidString: idString),
                      var note = try await noteService?.fetch(id: id) else {
                    return "Could not find note to update"
                }
                if let title = toolCall.arguments["title"] as? String { note.title = title }
                if let body = toolCall.arguments["body"] as? String { note.body = body }
                try await noteService?.update(note)
                return "Updated note: \(note.title)"

            case "rename_folder":
                guard let idString = toolCall.arguments["id"] as? String,
                      let id = UUID(uuidString: idString),
                      var folder = try await folderService?.fetch(id: id) else {
                    return "Could not find folder to rename"
                }
                let newName = toolCall.arguments["name"] as? String ?? folder.name
                folder.name = newName
                try await folderService?.update(folder)
                return "Renamed folder to: \(newName)"

            default:
                return "Unknown action: \(toolCall.function)"
            }
        } catch {
            return "Failed: \(toolCall.function) — \(error.localizedDescription)"
        }
    }
}
