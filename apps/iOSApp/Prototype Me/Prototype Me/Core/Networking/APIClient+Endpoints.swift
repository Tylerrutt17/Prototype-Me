import Foundation

// MARK: - Notes

extension APIClient {
    func listNotes(kind: NoteKind? = nil, folderId: UUID? = nil) async throws -> [NotePage] {
        var path = "/v1/notes"
        var params: [String] = []
        if let kind { params.append("kind=\(kind.rawValue)") }
        if let folderId { params.append("folderId=\(folderId.uuidString)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await get(path)
    }

    func getNote(id: UUID) async throws -> NotePage {
        try await get("/v1/notes/\(id.uuidString)")
    }

    func createNote(_ note: NotePage) async throws -> NotePage {
        try await post("/v1/notes", body: note)
    }

    func updateNote(id: UUID, updates: NotePageUpdate) async throws -> NotePage {
        try await patch("/v1/notes/\(id.uuidString)", body: updates)
    }

    func deleteNote(id: UUID) async throws {
        try await delete("/v1/notes/\(id.uuidString)")
    }
}

// MARK: - Directives

extension APIClient {
    func listDirectives(status: DirectiveStatus? = nil) async throws -> [Directive] {
        var path = "/v1/directives"
        if let status { path += "?status=\(status.rawValue)" }
        return try await get(path)
    }

    func getDirective(id: UUID) async throws -> Directive {
        try await get("/v1/directives/\(id.uuidString)")
    }

    func createDirective(_ directive: Directive) async throws -> Directive {
        try await post("/v1/directives", body: directive)
    }

    func updateDirective(id: UUID, updates: DirectiveUpdate) async throws -> Directive {
        try await patch("/v1/directives/\(id.uuidString)", body: updates)
    }

    func deleteDirective(id: UUID) async throws {
        try await delete("/v1/directives/\(id.uuidString)")
    }

    func pumpDirective(id: UUID) async throws -> Directive {
        try await post("/v1/directives/\(id.uuidString)/pump", body: EmptyBody())
    }

    func getDirectiveHistory(id: UUID) async throws -> [DirectiveHistory] {
        try await get("/v1/directives/\(id.uuidString)/history")
    }
}

// MARK: - Folders (Playbooks)

extension APIClient {
    func listFolders() async throws -> [Folder] {
        try await get("/v1/folders")
    }

    func getFolder(id: UUID) async throws -> Folder {
        try await get("/v1/folders/\(id.uuidString)")
    }

    func createFolder(_ folder: Folder) async throws -> Folder {
        try await post("/v1/folders", body: folder)
    }

    func updateFolder(id: UUID, updates: FolderUpdate) async throws -> Folder {
        try await patch("/v1/folders/\(id.uuidString)", body: updates)
    }

    func deleteFolder(id: UUID) async throws {
        try await delete("/v1/folders/\(id.uuidString)")
    }
}

// MARK: - Day Entries

extension APIClient {
    func listDayEntries(from: String? = nil, to: String? = nil) async throws -> [DayEntry] {
        var path = "/v1/day-entries"
        var params: [String] = []
        if let from { params.append("from=\(from)") }
        if let to { params.append("to=\(to)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await get(path)
    }

    func getDayEntry(id: UUID) async throws -> DayEntry {
        try await get("/v1/day-entries/\(id.uuidString)")
    }

    func createDayEntry(_ entry: DayEntry) async throws -> DayEntry {
        try await post("/v1/day-entries", body: entry)
    }

    func updateDayEntry(id: UUID, updates: DayEntryUpdate) async throws -> DayEntry {
        try await patch("/v1/day-entries/\(id.uuidString)", body: updates)
    }

    func deleteDayEntry(id: UUID) async throws {
        try await delete("/v1/day-entries/\(id.uuidString)")
    }
}

// MARK: - Tags

extension APIClient {
    func listTags() async throws -> [Tag] {
        try await get("/v1/tags")
    }

    func createTag(_ tag: Tag) async throws -> Tag {
        try await post("/v1/tags", body: tag)
    }

    func deleteTag(id: UUID) async throws {
        try await delete("/v1/tags/\(id.uuidString)")
    }
}

// MARK: - Schedule Rules

extension APIClient {
    func listScheduleRules(directiveId: UUID? = nil) async throws -> [ScheduleRule] {
        var path = "/v1/schedule/rules"
        if let directiveId { path += "?directiveId=\(directiveId.uuidString)" }
        return try await get(path)
    }

    func createScheduleRule(_ rule: ScheduleRule) async throws -> ScheduleRule {
        try await post("/v1/schedule/rules", body: rule)
    }

    func deleteScheduleRule(id: UUID) async throws {
        try await delete("/v1/schedule/rules/\(id.uuidString)")
    }
}

// MARK: - Active Modes

extension APIClient {
    func listActiveModes() async throws -> [ActiveMode] {
        try await get("/v1/active-modes")
    }

    func activateMode(noteId: UUID) async throws -> ActiveMode {
        try await post("/v1/active-modes", body: ["noteId": noteId.uuidString])
    }

    func deactivateMode(noteId: UUID) async throws {
        try await delete("/v1/active-modes/\(noteId.uuidString)")
    }
}

// MARK: - Links

extension APIClient {
    func linkNoteDirective(noteId: UUID, directiveId: UUID, sortIndex: Int = 0) async throws {
        try await post("/v1/links/note-directives", body: [
            "noteId": noteId.uuidString,
            "directiveId": directiveId.uuidString,
            "sortIndex": "\(sortIndex)",
        ])
    }

    func unlinkNoteDirective(noteId: UUID, directiveId: UUID) async throws {
        try await delete("/v1/links/note-directives?noteId=\(noteId.uuidString)&directiveId=\(directiveId.uuidString)")
    }

}

// MARK: - Sync

extension APIClient {
    func syncPush(operations: [OutboxOp]) async throws -> SyncPushResponse {
        try await post("/v1/sync/push", body: SyncPushRequest(deviceId: deviceId, operations: operations), timeout: Timeout.sync)
    }

    func syncPull(cursor: String? = nil) async throws -> SyncPullResponse {
        try await post("/v1/sync/pull", body: SyncPullRequest(deviceId: deviceId, cursor: cursor), timeout: Timeout.sync)
    }
}

// MARK: - Profile

extension APIClient {
    func getMyProfile() async throws -> UserProfile {
        try await get("/v1/profile")
    }

    func updateMyProfile(updates: UserProfileUpdate) async throws -> UserProfile {
        try await patch("/v1/profile", body: updates)
    }

    func getUserProfile(id: UUID) async throws -> UserProfile {
        try await get("/v1/users/\(id.uuidString)/profile")
    }
}

// MARK: - Friends

extension APIClient {
    func listFriends() async throws -> [FriendItem] {
        try await get("/v1/friends")
    }

    func sendFriendRequest(userId: UUID) async throws -> FriendItem {
        try await post("/v1/friends/request", body: ["userId": userId.uuidString])
    }

    func acceptFriendRequest(id: UUID) async throws -> FriendItem {
        try await post("/v1/friends/\(id.uuidString)/accept", body: EmptyBody())
    }

    func declineFriendRequest(id: UUID) async throws {
        try await post("/v1/friends/\(id.uuidString)/decline", body: EmptyBody())
    }

    func removeFriend(id: UUID) async throws {
        try await delete("/v1/friends/\(id.uuidString)")
    }
}

// MARK: - Subscription

extension APIClient {
    func getSubscription() async throws -> SubscriptionInfo {
        try await get("/v1/subscription")
    }

    func verifyReceipt(receiptData: String) async throws -> SubscriptionInfo {
        try await post("/v1/subscription/verify-receipt", body: ["receiptData": receiptData])
    }
}

// MARK: - Usage

extension APIClient {
    func getUsage() async throws -> UsageQuota {
        try await get("/v1/usage")
    }
}

// MARK: - AI

extension APIClient {
    func aiSuggest(context: String? = nil) async throws -> AiDraft {
        try await post("/v1/ai/suggest", body: AiSuggestRequest(context: context), timeout: Timeout.ai)
    }

    func aiOnboard(prompt: String) async throws -> AiOnboardResponse {
        try await post("/v1/ai/onboard", body: ["prompt": prompt], timeout: Timeout.ai)
    }
}

// MARK: - Devices

extension APIClient {
    func listDevices() async throws -> [Device] {
        try await get("/v1/devices")
    }

    func registerDevice(name: String, platform: String) async throws -> Device {
        try await post("/v1/devices", body: ["name": name, "platform": platform])
    }
}
