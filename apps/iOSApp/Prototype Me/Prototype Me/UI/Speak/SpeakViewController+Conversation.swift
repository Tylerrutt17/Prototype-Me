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
        sendMessage(text)
    }

    // MARK: - Send Message

    func sendMessage(_ rawText: String) {
        // Safety cap for voice transcriptions that might exceed the typed-input cap
        let text = rawText.count > FieldLimits.AI.speakMessage
            ? String(rawText.prefix(FieldLimits.AI.speakMessage))
            : rawText

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

                let conversationMessages: [[String: String]] = self.messages.compactMap { msg in
                    switch msg.role {
                    case .user:
                        return ["role": "user", "content": msg.text]
                    case .assistant:
                        return ["role": "assistant", "content": msg.text]
                    case .system, .pendingActions:
                        return nil
                    }
                }

                let response: SpeakConverseResponse = try await apiClient.post(
                    "/v1/ai/converse",
                    body: ["messages": conversationMessages],
                    timeout: APIClient.Timeout.ai
                )

                await MainActor.run {
                    // Handle tool calls
                    if !response.toolCalls.isEmpty {
                        let pending = response.toolCalls.map {
                            SpeakPendingToolCall(id: $0.id, function: $0.function, arguments: $0.arguments)
                        }

                        if self.autoApprove {
                            // Auto-execute actions
                            Task {
                                var results: [String] = []
                                for tc in pending {
                                    let result = await self.actionExecutor.execute(tc)
                                    results.append(result)
                                }
                                await MainActor.run {
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
                await MainActor.run {
                    self.showError("Something went wrong. Try again.")
                    self.isProcessing = false
                    self.updateControlsForProcessing()
                }
            }
        }
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

                let response = try await self.transcribeWithRetry(
                    apiClient: apiClient, base64Audio: base64Audio, maxRetries: 2
                )

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
                print("[Speak] Transcribe failed: \(error.localizedDescription)")
                await MainActor.run {
                    self.micButton.cleanupAudioFile()
                    if self.isPro {
                        self.proSetState(.idle)
                    } else {
                        self.hideTranscribing()
                        self.updateControlsForProcessing()
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
            for toolCall in toolCalls {
                let result = await actionExecutor.execute(toolCall)
                results.append(result)
            }
            await MainActor.run {
                self.showActionSuccess(results: results)
            }
        }
    }

    func dismissActions() {
        hideActions()
    }
}
