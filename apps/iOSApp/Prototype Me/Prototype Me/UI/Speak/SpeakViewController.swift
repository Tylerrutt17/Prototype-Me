import UIKit
import GRDB

/// Full-screen conversational AI tab. Big mic button, chat-style history,
/// voice or text input, AI responds with actions.
class SpeakViewController: BaseViewController {

    var apiClient: APIClient?
    var directiveService: DirectiveService?
    var noteService: NoteService?
    var dayEntryService: DayEntryService?
    var modeService: ModeService?
    var onUpgradeTapped: (() -> Void)?

    // MARK: - UI

    private let chatTableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private let inlineMicButton = UIButton(type: .system)
    private let micButton = VoiceInputButton() // hidden, handles recording logic
    private let bigMicButton = UIButton(type: .system)
    private let micLabel = UILabel()
    private let quotaLabel = UILabel()
    private let transcribingBar = UIView()
    private let transcribingSpinner = UIActivityIndicatorView(style: .medium)
    private let transcribingLabel = UILabel()

    // MARK: - State

    private var messages: [ChatMessage] = []
    private var isTranscribing = false
    private var isRecording = false
    private var isProcessing = false
    private var recordingStartTime: Date?

    struct ChatMessage {
        let id = UUID()
        let role: Role
        let text: String
        let timestamp = Date()

        enum Role {
            case user
            case assistant
            case system
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Speak", animated: false)

        setupQuota()
        setupChat()
        setupInputBar()
        setupTranscribingBar()
        setupVoiceInput()
        setupEmptyState()
        // Bring input bar and transcribing bar above the empty state
        view.bringSubviewToFront(transcribingBar)
        view.bringSubviewToFront(inputBar)
        observeKeyboard()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep gradient frame in sync as the button resizes
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        recordingGradient.frame = inlineMicButton.bounds
        recordingGradient.cornerRadius = inlineMicButton.bounds.height / 2
        CATransaction.commit()
    }

    // MARK: - Header

    // MARK: - Empty State

    private let emptyStateView = UIView()

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        let titleLabel = UILabel()
        titleLabel.text = "What can I help with?"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Tap the mic or type below"
        subtitleLabel.font = DesignTokens.Typography.subheadline
        subtitleLabel.textColor = DesignTokens.Colors.textTertiary
        subtitleLabel.textAlignment = .center

        let suggestions: [(icon: String, text: String)] = [
            ("plus.circle.fill", "\"Add a directive to meditate daily\""),
            ("pencil.circle.fill", "\"Update my cold shower directive\""),
            ("book.fill", "\"Log my journal — today was a great day\""),
            ("bolt.fill", "\"Switch to my Deep Work mode\""),
            ("lightbulb.fill", "\"What should I focus on today?\""),
            ("arrow.triangle.2.circlepath", "\"What's not working in my routine?\""),
        ]

        let chipsStack = UIStackView()
        chipsStack.axis = .vertical
        chipsStack.spacing = DesignTokens.Spacing.sm
        chipsStack.alignment = .center

        for suggestion in suggestions {
            let chip = makeSuggestionChip(icon: suggestion.icon, text: suggestion.text)
            chipsStack.addArrangedSubview(chip)
        }

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, chipsStack])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.lg
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: contentTopAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -DesignTokens.Spacing.lg),

            mainStack.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateView.leadingAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateView.trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    private func makeSuggestionChip(icon: String, text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
        pill.layer.cornerRadius = DesignTokens.Radii.md

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        label.textColor = DesignTokens.Colors.textSecondary
        label.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: inset),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -inset),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -inset),
        ])

        // Tap to use as prompt
        pill.isUserInteractionEnabled = true
        let tap = SuggestionTapGesture(target: self, action: #selector(suggestionChipTapped(_:)))
        tap.promptText = text.replacingOccurrences(of: "\"", with: "")
        pill.addGestureRecognizer(tap)

        return pill
    }

    @objc private func suggestionChipTapped(_ gesture: SuggestionTapGesture) {
        // Just informational — don't do anything on tap
    }

    private func hideEmptyState() {
        guard !emptyStateView.isHidden else { return }
        UIView.animate(withDuration: 0.2) {
            self.emptyStateView.alpha = 0
        } completion: { _ in
            self.emptyStateView.isHidden = true
        }
    }

    // MARK: - Header

    private func setupQuota() {
        quotaLabel.font = DesignTokens.Typography.caption1
        quotaLabel.textColor = DesignTokens.Colors.textSecondary
        navBar.setTitleView(quotaLabel)

        Task {
            if let apiClient, let quota: UsageQuota = try? await apiClient.get("/v1/usage") {
                await MainActor.run {
                    self.quotaLabel.text = "\(quota.remaining)/\(quota.dailyLimit) AI left"
                }
            }
        }
    }

    // MARK: - Chat

    private func setupChat() {
        chatTableView.backgroundColor = .clear
        chatTableView.separatorStyle = .none
        chatTableView.dataSource = self
        chatTableView.keyboardDismissMode = .interactive
        chatTableView.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.reuseID)
        chatTableView.translatesAutoresizingMaskIntoConstraints = false
        chatTableView.allowsSelection = false
        view.addSubview(chatTableView)

        NSLayoutConstraint.activate([
            chatTableView.topAnchor.constraint(equalTo: contentTopAnchor),
            chatTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Input Bar

    private var inputBarBottom: NSLayoutConstraint!

    private var fieldContainerHeight: NSLayoutConstraint!
    private lazy var maxTextViewHeight: CGFloat = UIScreen.main.bounds.height * 0.4

    private let fieldContainer = UIView()
    private let clearButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let recordingGradient = CAGradientLayer()
    private var isKeyboardVisible = false

    private func setupInputBar() {
        // Nearly transparent background
        inputBar.backgroundColor = DesignTokens.Colors.background.withAlphaComponent(0.4)
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)

        let separator = UIView()
        separator.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        separator.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(separator)

        // ── Toolbar row: [X clear] [voice] [done] ──
        let toolbarRow = UIStackView()
        toolbarRow.axis = .horizontal
        toolbarRow.spacing = DesignTokens.Spacing.sm
        toolbarRow.alignment = .center
        toolbarRow.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(toolbarRow)

        // Clear button (left of voice)
        var clearConfig = UIButton.Configuration.plain()
        clearConfig.image = UIImage(systemName: "xmark.circle.fill")
        clearConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        clearConfig.baseForegroundColor = DesignTokens.Colors.textTertiary
        clearConfig.contentInsets = .zero
        clearButton.configuration = clearConfig
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.isHidden = true
        clearButton.setContentHuggingPriority(.required, for: .horizontal)
        toolbarRow.addArrangedSubview(clearButton)

        // Voice button (fills available space, prominent)
        var micConfig = UIButton.Configuration.filled()
        micConfig.image = UIImage(systemName: "mic.fill")
        micConfig.title = "  Voice"
        micConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        micConfig.baseBackgroundColor = DesignTokens.Colors.accent
        micConfig.baseForegroundColor = .white
        micConfig.cornerStyle = .capsule
        micConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 18)
        micConfig.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            return c
        }
        inlineMicButton.configuration = micConfig
        inlineMicButton.addTarget(self, action: #selector(bigMicTapped), for: .touchUpInside)
        inlineMicButton.translatesAutoresizingMaskIntoConstraints = false
        inlineMicButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inlineMicButton.clipsToBounds = true

        // Recording gradient layer (white shimmer over solid red, hidden until recording)
        recordingGradient.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.25).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        recordingGradient.startPoint = CGPoint(x: 0, y: 0.5)
        recordingGradient.endPoint = CGPoint(x: 1, y: 0.5)
        recordingGradient.locations = [0, 0.5, 1]
        recordingGradient.opacity = 0
        inlineMicButton.layer.addSublayer(recordingGradient)

        toolbarRow.addArrangedSubview(inlineMicButton)

        // Done button (right, keyboard only)
        var doneConfig = UIButton.Configuration.plain()
        doneConfig.title = "Done"
        doneConfig.baseForegroundColor = DesignTokens.Colors.accent
        doneConfig.contentInsets = .zero
        doneConfig.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            return c
        }
        doneButton.configuration = doneConfig
        doneButton.addTarget(self, action: #selector(dismissKeyboard), for: .touchUpInside)
        doneButton.isHidden = true
        doneButton.setContentHuggingPriority(.required, for: .horizontal)
        toolbarRow.addArrangedSubview(doneButton)

        // ── Text field row: [text view] [send] ──
        fieldContainer.backgroundColor = DesignTokens.Colors.surfacePrimary
        fieldContainer.layer.cornerRadius = DesignTokens.Radii.xl
        fieldContainer.layer.borderWidth = 1.5
        fieldContainer.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.2).cgColor
        fieldContainer.clipsToBounds = true
        fieldContainer.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(fieldContainer)

        // Multi-line text view
        textView.font = DesignTokens.Typography.body
        textView.textColor = DesignTokens.Colors.textPrimary
        textView.tintColor = DesignTokens.Colors.accent
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.returnKeyType = .done
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(textView)

        // Placeholder
        placeholderLabel.text = "Type a message..."
        placeholderLabel.font = DesignTokens.Typography.body
        placeholderLabel.textColor = DesignTokens.Colors.textTertiary
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        fieldContainer.addSubview(placeholderLabel)

        // Send button
        var sendConfig = UIButton.Configuration.filled()
        sendConfig.image = UIImage(systemName: "arrow.up.circle.fill")
        sendConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28)
        sendConfig.baseBackgroundColor = .clear
        sendConfig.baseForegroundColor = DesignTokens.Colors.accent
        sendConfig.contentInsets = .zero
        sendButton.configuration = sendConfig
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.alpha = 0.3
        fieldContainer.addSubview(sendButton)

        inputBarBottom = inputBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        fieldContainerHeight = fieldContainer.heightAnchor.constraint(equalToConstant: 48)

        NSLayoutConstraint.activate([
            chatTableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarBottom,

            separator.topAnchor.constraint(equalTo: inputBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            // Toolbar row
            toolbarRow.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: DesignTokens.Spacing.sm),
            toolbarRow.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: DesignTokens.Spacing.md),
            toolbarRow.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -DesignTokens.Spacing.md),

            // Text field row
            fieldContainer.topAnchor.constraint(equalTo: toolbarRow.bottomAnchor, constant: DesignTokens.Spacing.sm),
            fieldContainer.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: DesignTokens.Spacing.md),
            fieldContainer.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -DesignTokens.Spacing.md),
            fieldContainer.bottomAnchor.constraint(equalTo: inputBar.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            fieldContainerHeight,

            textView.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: DesignTokens.Spacing.lg),
            textView.topAnchor.constraint(equalTo: fieldContainer.topAnchor),
            textView.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor),
            textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -DesignTokens.Spacing.sm),

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            sendButton.centerYAnchor.constraint(equalTo: fieldContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    // MARK: - Transcribing Bar

    private func setupTranscribingBar() {
        transcribingBar.backgroundColor = DesignTokens.Colors.surfacePrimary
        transcribingBar.isHidden = true
        transcribingBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(transcribingBar)

        transcribingSpinner.color = DesignTokens.Colors.accent
        transcribingSpinner.translatesAutoresizingMaskIntoConstraints = false
        transcribingBar.addSubview(transcribingSpinner)

        transcribingLabel.text = "Transcribing..."
        transcribingLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        transcribingLabel.textColor = DesignTokens.Colors.textSecondary
        transcribingLabel.translatesAutoresizingMaskIntoConstraints = false
        transcribingBar.addSubview(transcribingLabel)

        NSLayoutConstraint.activate([
            transcribingBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transcribingBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transcribingBar.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
            transcribingBar.heightAnchor.constraint(equalToConstant: 36),

            transcribingSpinner.leadingAnchor.constraint(equalTo: transcribingBar.leadingAnchor, constant: DesignTokens.Spacing.xl),
            transcribingSpinner.centerYAnchor.constraint(equalTo: transcribingBar.centerYAnchor),

            transcribingLabel.leadingAnchor.constraint(equalTo: transcribingSpinner.trailingAnchor, constant: DesignTokens.Spacing.sm),
            transcribingLabel.centerYAnchor.constraint(equalTo: transcribingBar.centerYAnchor),
        ])
    }

    private func showTranscribing() {
        isTranscribing = true
        transcribingBar.isHidden = false
        transcribingSpinner.startAnimating()
    }

    private func hideTranscribing() {
        isTranscribing = false
        transcribingBar.isHidden = true
        transcribingSpinner.stopAnimating()
    }

    // MARK: - Big Mic


    // MARK: - Voice Input

    private func setupVoiceInput() {
        micButton.isHidden = true
        view.addSubview(micButton)

        micButton.onTranscription = { [weak self] text in
            guard let self else { return }
            if !AuthService.isPro {
                self.finishVoiceInput(text: text)
            }
        }
        micButton.onPartialResult = { [weak self] text in
            guard !AuthService.isPro else { return }
            self?.textView.text = text
            self?.placeholderLabel.isHidden = !text.isEmpty
            self?.updateTextViewHeight()
        }
        micButton.onAudioRecorded = { [weak self] fileURL in
            guard let self, AuthService.isPro else { return }
            self.transcribeWithWhisper(fileURL: fileURL)
        }
        micButton.onError = { [weak self] message in
            self?.updateMicAppearance(recording: false)
            let alert = UIAlertController(title: "Voice Input", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func bigMicTapped() {
        guard !isProcessing else { return }

        if micButton.isRecording {
            // Check minimum recording duration
            if let start = recordingStartTime, Date().timeIntervalSince(start) < 1.0 {
                // Too short — ignore
                micButton.toggleStatus()
                isRecording = false
                updateMicAppearance(recording: false)
                updateControlsForProcessing()
                micButton.cleanupAudioFile()
                textView.text = ""
                placeholderLabel.isHidden = false
                return
            }
            micButton.toggleStatus()
            isRecording = false
            updateMicAppearance(recording: false)
            updateControlsForProcessing()
            placeholderLabel.isHidden = textView.text.isEmpty == false
        } else {
            recordingStartTime = Date()
            micButton.toggleStatus()
            isRecording = true
            updateMicAppearance(recording: true)
            updateControlsForProcessing()
            placeholderLabel.isHidden = true
        }
    }

    @objc private func sendTapped() {
        guard !isProcessing else { return }
        let text = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textView.text = ""
        placeholderLabel.isHidden = false
        updateTextViewHeight()
        textView.resignFirstResponder()
        sendMessage(text)
    }

    @objc private func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    @objc private func clearTapped() {
        textView.text = ""
        placeholderLabel.isHidden = false
        updateTextViewHeight()
        clearButton.isHidden = true
        sendButton.alpha = 0.3
    }

    private func finishVoiceInput(text: String) {
        updateMicAppearance(recording: false)
        guard !text.isEmpty else { return }
        sendMessage(text)
    }

    private func sendMessage(_ text: String) {
        isProcessing = true
        hideEmptyState()
        updateControlsForProcessing()

        // Add user message
        messages.append(ChatMessage(role: .user, text: text))
        chatTableView.reloadData()
        scrollToBottom()

        // Add thinking indicator
        messages.append(ChatMessage(role: .system, text: "Thinking..."))
        chatTableView.reloadData()
        scrollToBottom()

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "Speak", code: 0) }

                // Build conversation history for the API
                let conversationMessages = self.messages
                    .filter { $0.role != .system }
                    .map { ["role": $0.role == .user ? "user" : "assistant", "content": $0.text] }

                let response: ConverseResponse = try await apiClient.post(
                    "/v1/ai/converse",
                    body: ["messages": conversationMessages],
                    timeout: APIClient.Timeout.ai
                )

                // Execute tool calls locally
                var actionResults: [String] = []
                for toolCall in response.toolCalls {
                    let result = await self.executeToolCall(toolCall)
                    actionResults.append(result)
                }

                await MainActor.run {
                    // Remove thinking indicator
                    self.messages.removeLast()

                    // Show action results if any
                    if !actionResults.isEmpty {
                        let actionsText = actionResults.map { "✓ \($0)" }.joined(separator: "\n")
                        self.messages.append(ChatMessage(role: .system, text: actionsText))
                    }

                    // Show AI message
                    if !response.message.isEmpty {
                        self.messages.append(ChatMessage(role: .assistant, text: response.message))
                    } else if actionResults.isEmpty {
                        self.messages.append(ChatMessage(role: .assistant, text: "Done."))
                    }

                    self.chatTableView.reloadData()
                    self.scrollToBottom()
                    self.isProcessing = false
                    self.updateControlsForProcessing()
                    self.quotaLabel.text = "\(response.remainingQuota) AI left"
                }
            } catch {
                await MainActor.run {
                    self.messages.removeLast()
                    self.messages.append(ChatMessage(role: .assistant, text: "Something went wrong. Try again."))
                    self.chatTableView.reloadData()
                    self.scrollToBottom()
                    self.isProcessing = false
                    self.updateControlsForProcessing()
                }
            }
        }
    }

    // MARK: - Tool Call Execution

    private func executeToolCall(_ toolCall: ConverseResponse.ToolCall) async -> String {
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

            default:
                return "Unknown action: \(toolCall.function)"
            }
        } catch {
            return "Failed: \(toolCall.function) — \(error.localizedDescription)"
        }
    }

    private func updateControlsForProcessing() {
        let blocked = isProcessing || isTranscribing || isRecording
        sendButton.isEnabled = !blocked
        sendButton.alpha = blocked ? 0.4 : 1.0
        inlineMicButton.isEnabled = !(isProcessing || isTranscribing)
        inlineMicButton.alpha = (isProcessing || isTranscribing) ? 0.4 : 1.0
        textView.isEditable = !(isTranscribing || isRecording)
    }

    private func transcribeWithWhisper(fileURL: URL) {
        updateMicAppearance(recording: false)
        showTranscribing()
        updateControlsForProcessing()

        Task {
            do {
                guard let apiClient else { throw NSError(domain: "Speak", code: 0) }
                let audioData = try Data(contentsOf: fileURL)
                let fileSizeMB = Double(audioData.count) / (1024 * 1024)
                let base64Audio = audioData.base64EncodedString()
                let payloadSizeMB = Double(base64Audio.utf8.count) / (1024 * 1024)
                let ext = fileURL.pathExtension
                print("[Speak] Audio file (\(ext)): \(String(format: "%.2f", fileSizeMB))MB → base64 payload: \(String(format: "%.2f", payloadSizeMB))MB")

                let response: WhisperResponse = try await apiClient.post(
                    "/v1/ai/transcribe",
                    body: ["audio": base64Audio],
                    timeout: APIClient.Timeout.ai
                )

                await MainActor.run {
                    self.hideTranscribing()
                    self.micButton.cleanupAudioFile()
                    if !response.text.isEmpty {
                        self.textView.text = response.text
                        self.placeholderLabel.isHidden = true
                        self.updateTextViewHeight()
                        self.updateClearButton()
                        self.sendButton.alpha = 1.0
                        self.updateControlsForProcessing()
                    } else {
                        self.updateControlsForProcessing()
                    }
                }
            } catch {
                await MainActor.run {
                    self.hideTranscribing()
                    self.micButton.cleanupAudioFile()
                    // Keep whatever Apple transcription was in the text field
                    self.updateControlsForProcessing()
                }
            }
        }
    }

    private struct WhisperResponse: Decodable {
        let text: String
    }

    private struct ConverseResponse: Decodable {
        let message: String
        let toolCalls: [ToolCall]
        let remainingQuota: Int

        struct ToolCall: Decodable {
            let id: String
            let function: String
            private let _arguments: [String: AnyCodable]
            var arguments: [String: Any] { _arguments.mapValues(\.value) }

            enum CodingKeys: String, CodingKey {
                case id, function
                case _arguments = "arguments"
            }
        }
    }

    /// Lightweight type-erased Decodable for mixed JSON values in tool call arguments.
    private struct AnyCodable: Decodable {
        let value: Any

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) { value = s }
            else if let i = try? container.decode(Int.self) { value = i }
            else if let d = try? container.decode(Double.self) { value = d }
            else if let b = try? container.decode(Bool.self) { value = b }
            else if let arr = try? container.decode([AnyCodable].self) { value = arr.map(\.value) }
            else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues(\.value) }
            else { value = NSNull() }
        }
    }

    // MARK: - Mic Appearance

    private func updateMicAppearance(recording: Bool) {
        var config = inlineMicButton.configuration ?? .filled()

        if recording {
            config.baseBackgroundColor = DesignTokens.Colors.destructive
            config.baseForegroundColor = .white
            config.image = UIImage(systemName: "stop.fill")
            config.title = "  Recording..."
            inlineMicButton.configuration = config

            recordingGradient.opacity = 1

            // Collapse the text field, then start shimmer after layout settles
            fieldContainerHeight.constant = 0
            fieldContainer.alpha = 0
            fieldContainer.isHidden = true
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.startShimmerAnimation()
            }
            return
        } else {
            config.baseBackgroundColor = DesignTokens.Colors.accent
            config.baseForegroundColor = .white
            config.image = UIImage(systemName: "mic.fill")
            config.title = "  Voice"

            recordingGradient.removeAllAnimations()
            recordingGradient.opacity = 0
            inlineMicButton.layer.removeAllAnimations()
            inlineMicButton.alpha = 1.0

            // Restore the text field
            fieldContainer.isHidden = false
            fieldContainerHeight.constant = 48
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.fieldContainer.alpha = 1
                self.view.layoutIfNeeded()
            }
        }
        inlineMicButton.configuration = config
    }

    private func startShimmerAnimation() {
        recordingGradient.frame = inlineMicButton.bounds
        recordingGradient.cornerRadius = inlineMicButton.bounds.height / 2
        recordingGradient.removeAllAnimations()

        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-1.0, -0.5, 0.0]
        sweep.toValue = [1.0, 1.5, 2.0]
        sweep.duration = 2.0
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .linear)
        recordingGradient.add(sweep, forKey: "sweep")
    }

    // MARK: - Scroll

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        isKeyboardVisible = true
        inputBarBottom.constant = -frame.height
        doneButton.isHidden = false
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        scrollToBottom()
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        isKeyboardVisible = false
        inputBarBottom.constant = 0
        doneButton.isHidden = true
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - UITableViewDataSource

extension SpeakViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.reuseID, for: indexPath) as! ChatBubbleCell
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

// MARK: - UITextViewDelegate

extension SpeakViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateTextViewHeight()
        updateClearButton()

        let hasText = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        UIView.animate(withDuration: 0.15) {
            self.sendButton.alpha = hasText ? 1.0 : 0.3
        }
    }

    private func updateClearButton() {
        let hasText = !textView.text.isEmpty
        let shouldShow = hasText && !clearButton.isHidden == false
        UIView.animate(withDuration: 0.15) {
            self.clearButton.isHidden = !hasText
        }
    }

    private func updateTextViewHeight() {
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
        let newHeight = min(max(44, size.height), maxTextViewHeight)
        if fieldContainerHeight.constant != newHeight {
            fieldContainerHeight.constant = newHeight
            textView.isScrollEnabled = size.height > maxTextViewHeight
            UIView.animate(withDuration: 0.15) {
                self.view.layoutIfNeeded()
            }
        }
    }
}

// MARK: - Suggestion Tap Gesture

private final class SuggestionTapGesture: UITapGestureRecognizer {
    var promptText: String?
}

// MARK: - Chat Bubble Cell

private final class ChatBubbleCell: UITableViewCell {

    static let reuseID = "ChatBubbleCell"

    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubbleView.layer.cornerRadius = DesignTokens.Radii.lg
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        messageLabel.font = DesignTokens.Typography.body
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.xs),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.xs),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.8),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: pad),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -pad),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: pad),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -pad),
        ])
    }

    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    func configure(with message: SpeakViewController.ChatMessage) {
        leadingConstraint?.isActive = false
        trailingConstraint?.isActive = false

        switch message.role {
        case .user:
            bubbleView.backgroundColor = DesignTokens.Colors.accent
            messageLabel.textColor = .white
            trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg)
            trailingConstraint?.isActive = true

        case .assistant:
            bubbleView.backgroundColor = DesignTokens.Colors.surfaceSecondary
            messageLabel.textColor = DesignTokens.Colors.textPrimary
            leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg)
            leadingConstraint?.isActive = true

        case .system:
            let isAction = message.text.contains("✓")
            bubbleView.backgroundColor = isAction ? DesignTokens.Colors.accent.withAlphaComponent(0.1) : .clear
            messageLabel.textColor = isAction ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary
            messageLabel.font = isAction
                ? DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
                : DesignTokens.Typography.footnote
            leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg)
            leadingConstraint?.isActive = true
        }

        messageLabel.text = message.text
    }
}
