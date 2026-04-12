import UIKit

// MARK: - Conversation Flow, Transcription, Action Confirmation

extension SpeakViewController {

    func updateControlsForProcessing() {
        let blocked = isProcessing || isTranscribing
        sendButton.isEnabled = !blocked
        sendButton.alpha = blocked ? 0.4 : 1.0
        textView.isEditable = !isTranscribing
        if isPro {
            proMicButton.isEnabled = !blocked
        }
    }

    func finishVoiceInput(text: String) {
        guard !text.isEmpty else { return }
        hideThinkingContext(animated: false)
        sendMessage(text)
    }

    // MARK: - Send Message

    func sendMessage(_ rawText: String) {
        let text = rawText.count > FieldLimits.AI.speakMessage
            ? String(rawText.prefix(FieldLimits.AI.speakMessage))
            : rawText

        print("[Speak] sendMessage called — text length: \(text.count)")

        isProcessing = true
        hideEmptyState()
        updateControlsForProcessing()
        messages.append(SpeakChatMessage(role: .user, text: text))
        hideActions(animated: false)
        showThinking()

        let localDateFormatter = DateFormatter()
        localDateFormatter.dateFormat = "yyyy-MM-dd"
        let localDate = localDateFormatter.string(from: Date())

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "Speak", code: 0) }
                let postedAt = Date()

                // Build conversation history (last 10 messages)
                let historyLimit = 10
                let allHistory = self.messages.compactMap { msg -> SpeakConverseRequest.Message? in
                    switch msg.role {
                    case .user:    return .init(role: "user", content: msg.text)
                    case .assistant: return .init(role: "assistant", content: msg.text)
                    case .system, .pendingActions: return nil
                    }
                }
                let conversationMessages = Array(allHistory.suffix(historyLimit))

                // Initial request
                var response: SpeakConverseResponse = try await apiClient.post(
                    "/v1/ai/converse",
                    body: SpeakConverseRequest(
                        messages: conversationMessages,
                        localDate: localDate,
                        previousResponseId: nil,
                        toolOutputs: nil
                    ),
                    timeout: APIClient.Timeout.ai
                )

                // Client-driven read loop: if the AI needs data, execute reads locally
                // and send results back. Max 3 rounds (same as the old server-side limit).
                var readRounds = 0
                while let readRequests = response.readToolRequests, !readRequests.isEmpty, readRounds < 3 {
                    readRounds += 1
                    print("[Speak] Read round \(readRounds): \(readRequests.count) tool(s) to execute locally")

                    // Execute each read tool against local GRDB
                    let outputs = await executeReadToolsLocally(readRequests)

                    // Send results back for the AI to continue
                    response = try await apiClient.post(
                        "/v1/ai/converse",
                        body: SpeakConverseRequest(
                            messages: [],  // Not needed for continuation
                            localDate: localDate,
                            previousResponseId: response.responseId,
                            toolOutputs: outputs
                        ),
                        timeout: APIClient.Timeout.ai
                    )
                }

                let elapsed = Date().timeIntervalSince(postedAt)
                print("[Speak] Response in \(String(format: "%.2f", elapsed))s (\(readRounds) read round(s)) — message: \(response.message.count) chars, tools: \(response.toolCalls.count), quota: \(response.remainingQuota)")

                await MainActor.run {
                    self.handleResponse(response)
                }
            } catch {
                print("[Speak] Request failed: \(Self.describeError(error))")
                await MainActor.run {
                    if Self.isQuotaExceeded(error) {
                        let msg = self.isPro
                            ? "You've hit today's Prototype limit. Resets at midnight UTC."
                            : "You've hit today's Prototype limit. Upgrade to Pro for more daily messages."
                        self.showError(msg, showUpgrade: !self.isPro)
                    } else {
                        self.showError("Something went wrong. Try again.")
                    }
                    self.isProcessing = false
                    self.updateControlsForProcessing()
                }
            }
        }
    }

    /// Execute read tool requests locally against GRDB and return results for the server.
    private func executeReadToolsLocally(
        _ requests: [SpeakConverseResponse.ReadToolRequest]
    ) async -> [SpeakConverseRequest.ToolOutput] {
        guard let aiReadQueryService else { return [] }
        var outputs: [SpeakConverseRequest.ToolOutput] = []
        for req in requests {
            let result = (try? await aiReadQueryService.execute(
                function: req.function,
                arguments: req.parsedArguments
            )) ?? "{}"
            print("[Speak] Local read: \(req.function) → \(result.prefix(100))...")
            outputs.append(SpeakConverseRequest.ToolOutput(
                callId: req.callId,
                output: result
            ))
        }
        return outputs
    }

    // MARK: - Response Handling (shared between flow and converse)

    private func handleResponse(_ response: SpeakConverseResponse) {
        hideSuggestions()
        hideActions()

        // Binary confirmation?
        if let confirmCall = response.toolCalls.first(where: { $0.function == "ask_confirmation" }) {
            let question = (confirmCall.arguments["question"] as? String) ?? response.message
            messages.append(SpeakChatMessage(role: .assistant, text: question))
            showConfirmation(question: question)
            isProcessing = false
            updateControlsForProcessing()
            quotaLabel.text = "\(response.remainingQuota) Prototype left"
            return
        }

        // Multiple-choice options?
        if let optionsCall = response.toolCalls.first(where: { $0.function == "present_options" }) {
            let question = (optionsCall.arguments["question"] as? String) ?? response.message
            let options = (optionsCall.arguments["options"] as? [String]) ?? []
            let icons = optionsCall.arguments["icons"] as? [String]
            let followUp = optionsCall.arguments["followUp"] as? [String: Any]
            if !options.isEmpty {
                accumulatedChoices = [] // reset for new option sequence
                messages.append(SpeakChatMessage(role: .assistant, text: question))
                showOptions(question: question, options: options, icons: icons, followUp: followUp)
                isProcessing = false
                updateControlsForProcessing()
                quotaLabel.text = "\(response.remainingQuota) Prototype left"
                return
            }
        }

        // Action tool calls
        if !response.toolCalls.isEmpty {
            let pending = response.toolCalls.map {
                SpeakPendingToolCall(id: $0.id, function: $0.function, arguments: $0.arguments)
            }

            let editorFunctions = Set([
                "create_directive", "create_note", "create_journal_entry",
                "update_directive", "update_note", "update_journal_entry",
            ])
            let allEditorActions = pending.allSatisfy { editorFunctions.contains($0.function) }

            if allEditorActions {
                let updateFunctions = Set(["update_directive", "update_note", "update_journal_entry"])
                let suggestions: [SpeakViewController.AISuggestion] = pending.map { tc in
                    let (title, subtitle, icon) = Self.suggestionMeta(for: tc)
                    return SpeakViewController.AISuggestion(
                        title: title, subtitle: subtitle, icon: icon,
                        isUpdate: updateFunctions.contains(tc.function),
                        toolCall: tc
                    )
                }
                showSuggestions(suggestions)
            } else if autoApprove {
                Task {
                    var results: [String] = []
                    var newHistory: [SpeakHistoryEntry] = []
                    for tc in pending {
                        let r = await actionExecutor.execute(tc)
                        results.append(r.message)
                        if let h = r.history { newHistory.append(h) }
                    }
                    await MainActor.run {
                        self.recordHistory(newHistory)
                        self.showActionSuccess(results: results)
                    }
                }
            } else {
                Task {
                    let enriched = await actionExecutor.enrich(pending)
                    await MainActor.run {
                        self.showActions(enriched)
                    }
                }
            }
        }

        // Response text
        if !response.message.isEmpty {
            messages.append(SpeakChatMessage(role: .assistant, text: response.message))
            showResponse(text: response.message)
        } else if response.toolCalls.isEmpty {
            messages.append(SpeakChatMessage(role: .assistant, text: "Done."))
            showResponse(text: "Done.")
        } else {
            let hasCreates = response.toolCalls.contains { $0.function.hasPrefix("create_") }
            let hasUpdates = response.toolCalls.contains { $0.function.hasPrefix("update_") }
            let defaultMessage: String
            if hasCreates && hasUpdates {
                defaultMessage = "Here's what I came up with:"
            } else if hasCreates {
                defaultMessage = "Here are some options:"
            } else if hasUpdates {
                defaultMessage = "Here are the changes:"
            } else {
                defaultMessage = "Ready when you are:"
            }
            messages.append(SpeakChatMessage(role: .assistant, text: defaultMessage))
            showResponse(text: defaultMessage)
        }

        isProcessing = false
        updateControlsForProcessing()
        quotaLabel.text = "\(response.remainingQuota) Prototype left"
    }

    static func isQuotaExceeded(_ error: Error) -> Bool {
        guard let apiError = error as? APIClient.APIError else { return false }
        if case .clientError(let code, _, _) = apiError, code == 429 {
            return true
        }
        return false
    }

    /// Verbose description of an error for logging. Unwraps APIError envelopes and
    /// shows status codes + server response bodies when available.
    static func describeError(_ error: Error) -> String {
        if let apiError = error as? APIClient.APIError {
            switch apiError {
            case .unauthorized:
                return "APIError.unauthorized"
            case .clientError(let code, let msg, let data):
                let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
                return "APIError.clientError(\(code)) msg=\(msg ?? "nil") body=\(bodyStr.prefix(500))"
            case .serverError(let code, let data):
                let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
                return "APIError.serverError(\(code)) body=\(bodyStr.prefix(500))"
            case .networkError(let underlying):
                let ns = underlying as NSError
                return "APIError.networkError — \(ns.domain) code=\(ns.code) \(underlying.localizedDescription)"
            case .decodingError(let underlying):
                return "APIError.decodingError — \(underlying)"
            case .noData:
                return "APIError.noData"
            }
        }
        let ns = error as NSError
        return "\(type(of: error)) \(ns.domain) code=\(ns.code) — \(error.localizedDescription)"
    }

    // MARK: - Transcription

    func transcribeWithWhisper(fileURL: URL) {
        if !isPro {
            showTranscribing()
            updateControlsForProcessing()
        }

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "Speak", code: 0) }
                let audioData = try Data(contentsOf: fileURL)
                let fileSizeMB = Double(audioData.count) / (1024 * 1024)
                let base64Audio = audioData.base64EncodedString()
                let payloadSizeMB = Double(base64Audio.utf8.count) / (1024 * 1024)
                let ext = fileURL.pathExtension
                print("[Speak] Audio file (\(ext)): \(String(format: "%.2f", fileSizeMB))MB \u{2192} base64 payload: \(String(format: "%.2f", payloadSizeMB))MB")

                let postedAt = Date()
                let response = try await self.transcribeWithRetry(
                    apiClient: apiClient, base64Audio: base64Audio, maxRetries: 2
                )
                let elapsed = Date().timeIntervalSince(postedAt)
                print("[Speak] Transcribe succeeded in \(String(format: "%.2f", elapsed))s — text chars: \(response.text.count)")

                await MainActor.run {
                    self.micButton.cleanupAudioFile()
                    if self.isPro {
                        self.proHandleTranscription(response.text)
                    } else {
                        self.hideTranscribing()
                        if !response.text.isEmpty {
                            self.textView.text = response.text
                            self.placeholderLabel.isHidden = true
                            self.updateTextViewHeight()
                            self.updateClearButton()
                            self.sendButton.alpha = 1.0
                        }
                        self.updateControlsForProcessing()
                    }
                }
            } catch {
                print("[Speak] Transcribe failed: \(Self.describeError(error))")
                let quotaHit = Self.isQuotaExceeded(error)
                await MainActor.run {
                    self.micButton.cleanupAudioFile()
                    if self.isPro {
                        self.proSetState(.idle)
                    } else {
                        self.hideTranscribing()
                        self.updateControlsForProcessing()
                    }
                    if quotaHit {
                        let msg = self.isPro
                            ? "You've hit today's Prototype limit. Resets at midnight UTC."
                            : "You've hit today's Prototype limit. Upgrade to Pro for more daily messages."
                        self.showError(msg)
                    }
                }
            }
        }
    }

    func transcribeWithRetry(
        apiClient: APIClient, base64Audio: String, maxRetries: Int
    ) async throws -> SpeakWhisperResponse {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                return try await apiClient.post(
                    "/v1/ai/transcribe",
                    body: ["audio": base64Audio],
                    timeout: APIClient.Timeout.ai
                )
            } catch {
                lastError = error
                let isRetryable = Self.isRetryableError(error)
                if !isRetryable || attempt == maxRetries { break }
                print("[Speak] Transcribe attempt \(attempt + 1) failed, retrying...")
                try await Task.sleep(nanoseconds: UInt64(500_000_000 * (attempt + 1)))
            }
        }
        throw lastError!
    }

    private static func isRetryableError(_ error: Error) -> Bool {
        if let apiError = error as? APIClient.APIError {
            switch apiError {
            case .networkError(let underlying):
                return isRetryableError(underlying)
            case .serverError:
                return true
            default:
                return false
            }
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return [
            NSURLErrorNetworkConnectionLost,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNotConnectedToInternet,
        ].contains(nsError.code)
    }

    // MARK: - Action Confirmation

    func approveActions() {
        guard let toolCalls = pendingToolCalls else { return }

        Task {
            var results: [String] = []
            var newHistory: [SpeakHistoryEntry] = []
            for toolCall in toolCalls {
                let r = await actionExecutor.execute(toolCall)
                results.append(r.message)
                if let h = r.history { newHistory.append(h) }
            }
            await MainActor.run {
                self.recordHistory(newHistory)
                self.showActionSuccess(results: results)
            }
        }
    }

    func approveIndividualAction(_ toolCall: SpeakPendingToolCall) {
        Task {
            let r = await actionExecutor.execute(toolCall)
            if let h = r.history { recordHistory([h]) }
            await MainActor.run {
                Haptics.success()
                let msg = "\u{2713} \(r.message)"
                self.messages.append(SpeakChatMessage(role: .assistant, text: msg))
            }
        }
    }

    func dismissActions() {
        hideActions()
    }

    // MARK: - Suggestion Metadata

    static func suggestionMeta(for tc: SpeakPendingToolCall) -> (title: String, subtitle: String?, icon: String) {
        let args = tc.arguments
        switch tc.function {
        case "create_directive":
            return (
                args["title"] as? String ?? "New Directive",
                args["body"] as? String,
                "target"
            )
        case "update_directive":
            return (
                "Edit: \(args["title"] as? String ?? "Directive")",
                args["body"] as? String,
                "pencil.circle"
            )
        case "create_note":
            return (
                args["title"] as? String ?? "New Note",
                args["body"].flatMap { ($0 as? String)?.prefix(80).description },
                "doc.text"
            )
        case "update_note":
            return (
                "Edit: \(args["title"] as? String ?? "Note")",
                args["body"].flatMap { ($0 as? String)?.prefix(80).description },
                "pencil.circle"
            )
        case "create_journal_entry":
            let date = args["date"] as? String ?? "Today"
            let rating = args["rating"] as? Int
            let subtitle = rating.map { "Rating: \($0)/10" }
            return ("Journal — \(date)", subtitle, "book")
        case "update_journal_entry":
            let date = args["date"] as? String ?? "Today"
            return ("Edit Journal — \(date)", nil, "pencil.circle")
        default:
            return (tc.function, nil, "questionmark.circle")
        }
    }
}
