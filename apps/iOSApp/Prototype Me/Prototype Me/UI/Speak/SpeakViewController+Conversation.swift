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
        // Safety cap for voice transcriptions that might exceed the typed-input cap
        let text = rawText.count > FieldLimits.AI.speakMessage
            ? String(rawText.prefix(FieldLimits.AI.speakMessage))
            : rawText

        print("[Speak] sendMessage called — text length: \(text.count) (raw: \(rawText.count))")

        isProcessing = true
        hideEmptyState()
        updateControlsForProcessing()

        // Store user message for conversation context
        messages.append(SpeakChatMessage(role: .user, text: text))

        // Clear previous response, show thinking
        hideActions(animated: false)
        showThinking()

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "Speak", code: 0) }

                // Only send the most recent N messages to keep context focused
                // and API costs predictable (each turn re-sends all history).
                // 10 ≈ 5 user/assistant exchanges.
                let historyLimit = 10
                let allHistory: [[String: String]] = self.messages.compactMap { msg in
                    switch msg.role {
                    case .user:
                        return ["role": "user", "content": msg.text]
                    case .assistant:
                        return ["role": "assistant", "content": msg.text]
                    case .system, .pendingActions:
                        return nil
                    }
                }
                let conversationMessages = Array(allHistory.suffix(historyLimit))

                print("[Speak] POST /v1/ai/converse — \(conversationMessages.count) messages in payload")
                let postedAt = Date()

                let response: SpeakConverseResponse = try await apiClient.post(
                    "/v1/ai/converse",
                    body: ["messages": conversationMessages],
                    timeout: APIClient.Timeout.ai
                )

                let elapsed = Date().timeIntervalSince(postedAt)
                print("[Speak] Converse response received in \(String(format: "%.2f", elapsed))s — message chars: \(response.message.count), tool calls: \(response.toolCalls.count), quota: \(response.remainingQuota)")
                print("[Speak] Response text: \(response.message)")

                await MainActor.run {
                    // Branch: is this a binary confirmation request? If so, show
                    // Yes/No buttons instead of treating it as an executable action.
                    if let confirmCall = response.toolCalls.first(where: { $0.function == "ask_confirmation" }) {
                        let question = (confirmCall.arguments["question"] as? String) ?? response.message
                        self.messages.append(SpeakChatMessage(role: .assistant, text: question))
                        self.showConfirmation(question: question)
                        self.isProcessing = false
                        self.updateControlsForProcessing()
                        self.quotaLabel.text = "\(response.remainingQuota) AI left"
                        return
                    }

                    // Handle tool calls
                    if !response.toolCalls.isEmpty {
                        let pending = response.toolCalls.map {
                            SpeakPendingToolCall(id: $0.id, function: $0.function, arguments: $0.arguments)
                        }

                        if self.autoApprove {
                            // Auto-execute actions
                            Task {
                                var results: [String] = []
                                var newHistory: [SpeakHistoryEntry] = []
                                for tc in pending {
                                    let r = await self.actionExecutor.execute(tc)
                                    results.append(r.message)
                                    if let h = r.history { newHistory.append(h) }
                                }
                                await MainActor.run {
                                    self.recordHistory(newHistory)
                                    self.showActionSuccess(results: results)
                                }
                            }
                        } else {
                            // Show action card for manual approval
                            Task {
                                let enriched = await self.actionExecutor.enrich(pending)
                                await MainActor.run {
                                    self.showActions(enriched)
                                }
                            }
                        }
                    }

                    // Show response text
                    if !response.message.isEmpty {
                        self.messages.append(SpeakChatMessage(role: .assistant, text: response.message))
                        self.showResponse(text: response.message)
                    } else if response.toolCalls.isEmpty {
                        self.messages.append(SpeakChatMessage(role: .assistant, text: "Done."))
                        self.showResponse(text: "Done.")
                    } else {
                        // Tool calls only, no text — hide thinking
                        self.thinkingDotsView.stopAnimating()
                        UIView.animate(withDuration: 0.15) {
                            self.thinkingDotsView.alpha = 0
                        } completion: { _ in
                            self.thinkingDotsView.isHidden = true
                        }
                    }

                    self.isProcessing = false
                    self.updateControlsForProcessing()
                    self.quotaLabel.text = "\(response.remainingQuota) AI left"
                }
            } catch {
                print("[Speak] Converse failed: \(Self.describeError(error))")
                await MainActor.run {
                    if Self.isQuotaExceeded(error) {
                        let msg = self.isPro
                            ? "You've hit today's AI limit. Resets at midnight UTC."
                            : "You've hit today's AI limit. Upgrade to Pro for more daily messages."
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
                            ? "You've hit today's AI limit. Resets at midnight UTC."
                            : "You've hit today's AI limit. Upgrade to Pro for more daily messages."
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

    func dismissActions() {
        hideActions()
    }
}
