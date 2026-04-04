import UIKit
import GRDB

/// Full-screen Jarvis-style AI tab. Shows only the latest response,
/// clears on each new interaction. Voice or text input, AI responds with actions.
class SpeakViewController: BaseViewController {

    var apiClient: APIClient?
    var directiveService: DirectiveService?
    var noteService: NoteService?
    var dayEntryService: DayEntryService?
    var modeService: ModeService?
    var folderService: FolderService?
    var onUpgradeTapped: (() -> Void)?
    var onNavigateToDirective: ((UUID) -> Void)?
    var onNavigateToNote: ((UUID) -> Void)?
    var onNavigateToJournal: ((String) -> Void)?

    lazy var actionExecutor = SpeakActionExecutor(
        directiveService: directiveService,
        noteService: noteService,
        dayEntryService: dayEntryService,
        modeService: modeService,
        folderService: folderService
    )

    // MARK: - Response UI

    let responseScrollView = UIScrollView()
    let responseContentStack = UIStackView()
    let responseLabel = UILabel()
    let thinkingDotsView = ThinkingDotsView()
    let actionConfirmView = ActionConfirmView()
    let upgradeButton = UIButton(type: .system)

    // MARK: - Input UI

    let inputBar = UIView()
    let textView = UITextView()
    let placeholderLabel = UILabel()
    let sendButton = UIButton(type: .system)
    let micButton = VoiceInputButton()
    let quotaLabel = UILabel()
    let transcribingBar = UIView()
    let transcribingSpinner = UIActivityIndicatorView(style: .medium)
    let transcribingLabel = UILabel()

    // Input bar state (used by InputBar extension)
    var inputBarBottom: NSLayoutConstraint!
    var fieldContainerHeight: NSLayoutConstraint!
    lazy var maxTextViewHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    let fieldContainer = UIView()
    let clearButton = UIButton(type: .system)
    let doneButton = UIButton(type: .system)
    var textViewLeadingDefault: NSLayoutConstraint!
    var textViewLeadingWithClear: NSLayoutConstraint!
    var isKeyboardVisible = false

    /// Top anchor of whatever input bar is active (free text bar or pro mic bar).
    /// Set by setupFreeInputBar() or setupProInput(). Used by empty state and transcribing bar.
    var inputAreaTopAnchor: NSLayoutYAxisAnchor!

    // MARK: - Pro Voice UI

    let proMicButton = UIButton(type: .system)
    let proStatusLabel = UILabel()
    let proRecordingGradient = CAGradientLayer()
    var proMicBottomConstraint: NSLayoutConstraint!
    var isPro: Bool { AuthService.isPro }

    // MARK: - State

    var messages: [SpeakChatMessage] = []
    var isTranscribing = false
    var isRecording = false
    var isProcessing = false
    var recordingStartTime: Date?
    var pendingToolCalls: [SpeakPendingToolCall]?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupQuota()
        setupVoiceInput()
        setupResponseArea()

        // Input must be set up before empty state / transcribing bar (they anchor to it)
        if isPro {
            setupProInput()
        } else {
            setupFreeInputBar()
            observeKeyboard()
        }

        setupTranscribingBar()
        setupEmptyState()
        view.bringSubviewToFront(transcribingBar)

        if isPro {
            view.bringSubviewToFront(proMicButton)
            view.bringSubviewToFront(proStatusLabel)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard isPro else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        proRecordingGradient.frame = proMicButton.bounds
        proRecordingGradient.cornerRadius = proMicButton.bounds.height / 2
        CATransaction.commit()
    }

    // MARK: - Response Area

    private func setupResponseArea() {
        responseScrollView.showsVerticalScrollIndicator = false
        responseScrollView.alwaysBounceVertical = false
        responseScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(responseScrollView)

        // Content stack pinned to top of scroll view
        responseContentStack.axis = .vertical
        responseContentStack.spacing = DesignTokens.Spacing.lg
        responseContentStack.alignment = .fill
        responseContentStack.translatesAutoresizingMaskIntoConstraints = false
        responseScrollView.addSubview(responseContentStack)

        // Response label
        responseLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .regular)
        responseLabel.textColor = DesignTokens.Colors.textPrimary
        responseLabel.numberOfLines = 0
        responseLabel.textAlignment = .natural
        responseLabel.isHidden = true
        responseContentStack.addArrangedSubview(responseLabel)

        // Action confirm view
        actionConfirmView.isHidden = true
        responseContentStack.addArrangedSubview(actionConfirmView)

        // Upgrade button (shown when free tier hits quota)
        var upgradeConfig = UIButton.Configuration.filled()
        upgradeConfig.title = "Upgrade to Pro"
        upgradeConfig.image = UIImage(systemName: "sparkles")
        upgradeConfig.imagePadding = DesignTokens.Spacing.xs
        upgradeConfig.baseBackgroundColor = DesignTokens.Colors.accent
        upgradeConfig.baseForegroundColor = .white
        upgradeConfig.cornerStyle = .capsule
        upgradeConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        upgradeConfig.titleTextAttributesTransformer = .init { c in
            var c = c; c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold); return c
        }
        upgradeButton.configuration = upgradeConfig
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        upgradeButton.isHidden = true

        // Centered container so the pill button doesn't stretch full width
        let upgradeRow = UIStackView(arrangedSubviews: [UIView(), upgradeButton, UIView()])
        upgradeRow.axis = .horizontal
        upgradeRow.alignment = .center
        upgradeRow.distribution = .equalCentering
        upgradeRow.isHidden = true
        upgradeRow.tag = 9001 // identify later for show/hide
        responseContentStack.addArrangedSubview(upgradeRow)

        // Thinking dots (near top of response area)
        thinkingDotsView.isHidden = true
        thinkingDotsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingDotsView)

        let pad = DesignTokens.Spacing.xl

        NSLayoutConstraint.activate([
            responseScrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            responseScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            responseScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Stack pinned to top, determines scroll content size
            responseContentStack.topAnchor.constraint(equalTo: responseScrollView.contentLayoutGuide.topAnchor, constant: pad),
            responseContentStack.bottomAnchor.constraint(equalTo: responseScrollView.contentLayoutGuide.bottomAnchor, constant: -pad),
            responseContentStack.leadingAnchor.constraint(equalTo: responseScrollView.frameLayoutGuide.leadingAnchor, constant: pad),
            responseContentStack.trailingAnchor.constraint(equalTo: responseScrollView.frameLayoutGuide.trailingAnchor, constant: -pad),

            thinkingDotsView.centerXAnchor.constraint(equalTo: responseScrollView.centerXAnchor),
            thinkingDotsView.topAnchor.constraint(equalTo: responseScrollView.topAnchor, constant: pad * 2),
            thinkingDotsView.widthAnchor.constraint(equalToConstant: 80),
            thinkingDotsView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    // MARK: - Response State Transitions

    func showThinking() {
        emptyStateView.isHidden = true
        emptyStateView.alpha = 0

        // Hide upgrade row if it was showing
        responseContentStack.arrangedSubviews.first { $0.tag == 9001 }?.isHidden = true

        // Fade out current response
        UIView.animate(withDuration: 0.2) {
            self.responseLabel.alpha = 0
            self.actionConfirmView.alpha = 0
        } completion: { _ in
            self.responseLabel.isHidden = true
            self.actionConfirmView.isHidden = true
            self.responseLabel.alpha = 1
            self.actionConfirmView.alpha = 1
        }

        // Show thinking dots
        thinkingDotsView.isHidden = false
        thinkingDotsView.alpha = 0
        thinkingDotsView.startAnimating()
        UIView.animate(withDuration: 0.3, delay: 0.1) {
            self.thinkingDotsView.alpha = 1
        }
    }

    func showResponse(text: String) {
        thinkingDotsView.stopAnimating()
        responseLabel.attributedText = Self.renderSpeakMarkdown(text)

        responseLabel.isHidden = false
        responseLabel.alpha = 0
        responseLabel.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)

        UIView.animate(withDuration: 0.15) {
            self.thinkingDotsView.alpha = 0
        } completion: { _ in
            self.thinkingDotsView.isHidden = true
        }

        UIView.animate(
            withDuration: 0.4,
            delay: 0.1,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: []
        ) {
            self.responseLabel.alpha = 1
            self.responseLabel.transform = .identity
        }
    }

    func showActions(_ toolCalls: [SpeakPendingToolCall]) {
        pendingToolCalls = toolCalls
        actionConfirmView.configure(with: toolCalls)
        actionConfirmView.onApprove = { [weak self] in self?.approveActions() }
        actionConfirmView.onDismiss = { [weak self] in self?.dismissActions() }
        actionConfirmView.onActionTapped = { [weak self] tc in self?.navigateToItem(tc) }

        actionConfirmView.isHidden = false
        actionConfirmView.alpha = 0
        actionConfirmView.transform = CGAffineTransform(translationX: 0, y: 16)

        UIView.animate(
            withDuration: 0.4,
            delay: 0.15,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: []
        ) {
            self.actionConfirmView.alpha = 1
            self.actionConfirmView.transform = .identity
        }
    }

    func showActionSuccess(results: [String]) {
        actionConfirmView.showSuccess(results: results)

        // Also add to messages for conversation context
        let actionsText = results.map { "\u{2713} \($0)" }.joined(separator: "\n")
        messages.append(SpeakChatMessage(role: .assistant, text: actionsText))
    }

    func hideActions(animated: Bool = true) {
        pendingToolCalls = nil
        guard animated else {
            actionConfirmView.isHidden = true
            return
        }
        UIView.animate(withDuration: 0.25) {
            self.actionConfirmView.alpha = 0
        } completion: { _ in
            self.actionConfirmView.isHidden = true
            self.actionConfirmView.alpha = 1
        }
    }

    func showError(_ text: String, showUpgrade: Bool = false) {
        thinkingDotsView.stopAnimating()

        UIView.animate(withDuration: 0.15) {
            self.thinkingDotsView.alpha = 0
        } completion: { _ in
            self.thinkingDotsView.isHidden = true
        }

        responseLabel.text = text
        responseLabel.isHidden = false
        responseLabel.alpha = 0

        // Show/hide upgrade row (tag 9001 set during setup)
        let upgradeRow = responseContentStack.arrangedSubviews.first { $0.tag == 9001 }
        upgradeRow?.isHidden = !showUpgrade
        upgradeRow?.alpha = showUpgrade ? 0 : 1

        UIView.animate(withDuration: 0.3, delay: 0.1) {
            self.responseLabel.alpha = 1
            if showUpgrade { upgradeRow?.alpha = 1 }
        }
    }

    @objc private func upgradeTapped() {
        onUpgradeTapped?()
    }

    // MARK: - Markdown Rendering

    /// Renders inline formatting:
    ///   - `**bold**` → bold + accent color
    ///   - `*italic*` → italic
    ///   - `<u>text</u>` → underline (custom extension, since markdown has no underline)
    static func renderSpeakMarkdown(_ text: String) -> NSAttributedString {
        let baseFont = DesignTokens.Typography.rounded(style: .body, weight: .regular)
        let boldFont = DesignTokens.Typography.rounded(style: .body, weight: .bold)
        let italicFont: UIFont = {
            if let desc = baseFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                return UIFont(descriptor: desc, size: baseFont.pointSize)
            }
            return baseFont
        }()

        // Replace <u>/</u> with Unicode Private Use Area sentinels so the markdown
        // parser ignores them. We find these in the final string to apply underline,
        // then strip them out.
        let openMarker = "\u{E000}"
        let closeMarker = "\u{E001}"
        let preprocessed = text
            .replacingOccurrences(of: "<u>", with: openMarker)
            .replacingOccurrences(of: "</u>", with: closeMarker)

        guard var attributed = try? AttributedString(
            markdown: preprocessed,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return NSAttributedString(
                string: text,
                attributes: [.font: baseFont, .foregroundColor: DesignTokens.Colors.textPrimary]
            )
        }

        // Apply base font + color everywhere as defaults
        attributed.foregroundColor = DesignTokens.Colors.textPrimary
        attributed.font = baseFont

        // Override per-run for bold/italic based on inline intent
        for run in attributed.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            if intent.contains(.stronglyEmphasized) {
                attributed[run.range].font = boldFont
                attributed[run.range].foregroundColor = DesignTokens.Colors.accent
            } else if intent.contains(.emphasized) {
                attributed[run.range].font = italicFont
            }
        }

        // Convert to NSMutableAttributedString to handle underline sentinels
        let mutable = NSMutableAttributedString(attributedString: NSAttributedString(attributed))

        // Apply underline between sentinel pairs, then strip the sentinels.
        var searchStart = mutable.string.startIndex
        while let openRange = mutable.string.range(of: openMarker, range: searchStart..<mutable.string.endIndex),
              let closeRange = mutable.string.range(of: closeMarker, range: openRange.upperBound..<mutable.string.endIndex) {
            let underlineNSRange = NSRange(openRange.upperBound..<closeRange.lowerBound, in: mutable.string)
            mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: underlineNSRange)
            searchStart = closeRange.upperBound
        }
        // Strip sentinels (attribute ranges shift automatically with NSMutableAttributedString)
        while let range = mutable.string.range(of: openMarker) {
            mutable.deleteCharacters(in: NSRange(range, in: mutable.string))
        }
        while let range = mutable.string.range(of: closeMarker) {
            mutable.deleteCharacters(in: NSRange(range, in: mutable.string))
        }

        return mutable
    }

    // MARK: - Header

    private func setupQuota() {
        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 1

        let titleLabel = UILabel()
        titleLabel.text = "Speak"
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        quotaLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        quotaLabel.textColor = DesignTokens.Colors.textTertiary

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(quotaLabel)

        navBar.setTitle(nil, animated: false)
        navBar.setTitleView(titleStack)

        navBar.setRightButtons([
            NavBarButton(systemImage: "gearshape") { [weak self] in
                self?.showSpeakSettings()
            }
        ])

        Task {
            if let apiClient, let quota: UsageQuota = try? await apiClient.get("/v1/usage") {
                await MainActor.run {
                    self.quotaLabel.text = "\(quota.remaining)/\(quota.dailyLimit) AI left"
                }
            }
        }
    }

    private func showSpeakSettings() {
        let alert = UIAlertController(title: "Speak Settings", message: nil, preferredStyle: .actionSheet)

        let autoTitle = autoApprove ? "\u{2713} Auto-Approve Actions" : "Auto-Approve Actions"
        alert.addAction(UIAlertAction(title: autoTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            self.autoApprove.toggle()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Empty State

    let emptyStateView = UIView()

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
            ("book.fill", "\"Log my journal \u{2014} today was a great day\""),
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
            emptyStateView.bottomAnchor.constraint(equalTo: inputAreaTopAnchor, constant: -DesignTokens.Spacing.lg),

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

        pill.isUserInteractionEnabled = true
        let tap = SuggestionTapGesture(target: self, action: #selector(suggestionChipTapped(_:)))
        tap.promptText = text.replacingOccurrences(of: "\"", with: "")
        pill.addGestureRecognizer(tap)

        return pill
    }

    @objc private func suggestionChipTapped(_ gesture: SuggestionTapGesture) {
        // Just informational
    }

    func hideEmptyState() {
        guard !emptyStateView.isHidden else { return }
        UIView.animate(withDuration: 0.2) {
            self.emptyStateView.alpha = 0
        } completion: { _ in
            self.emptyStateView.isHidden = true
        }
    }

    // MARK: - Auto-Approve

    static let autoApproveKey = "speak_auto_approve"
    var autoApprove: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoApproveKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoApproveKey) }
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
            transcribingBar.bottomAnchor.constraint(equalTo: inputAreaTopAnchor),
            transcribingBar.heightAnchor.constraint(equalToConstant: 36),

            transcribingSpinner.leadingAnchor.constraint(equalTo: transcribingBar.leadingAnchor, constant: DesignTokens.Spacing.xl),
            transcribingSpinner.centerYAnchor.constraint(equalTo: transcribingBar.centerYAnchor),

            transcribingLabel.leadingAnchor.constraint(equalTo: transcribingSpinner.trailingAnchor, constant: DesignTokens.Spacing.sm),
            transcribingLabel.centerYAnchor.constraint(equalTo: transcribingBar.centerYAnchor),
        ])
    }

    func showTranscribing() {
        isTranscribing = true
        transcribingBar.isHidden = false
        transcribingSpinner.startAnimating()
    }

    func hideTranscribing() {
        isTranscribing = false
        transcribingBar.isHidden = true
        transcribingSpinner.stopAnimating()
    }

    // MARK: - Voice Input

    private func setupVoiceInput() {
        micButton.isHidden = true
        view.addSubview(micButton)

        micButton.onTranscription = { [weak self] text in
            guard let self else { return }
            if !self.isPro {
                self.finishVoiceInput(text: text)
            }
        }
        micButton.onPartialResult = { [weak self] text in
            guard let self, !self.isPro else { return }
            self.textView.text = text
            self.placeholderLabel.isHidden = !text.isEmpty
            self.updateTextViewHeight()
        }
        micButton.onAudioRecorded = { [weak self] fileURL in
            guard let self, self.isPro else { return }
            self.transcribeWithWhisper(fileURL: fileURL)
        }
        micButton.onError = { [weak self] message in
            guard let self else { return }
            if self.isPro { self.proSetState(.idle) }
            let alert = UIAlertController(title: "Voice Input", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Action Navigation

    func navigateToItem(_ toolCall: SpeakPendingToolCall) {
        let args = toolCall.arguments
        switch toolCall.function {
        case "update_directive", "retire_directive":
            if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr) {
                onNavigateToDirective?(id)
            }
        case "update_note":
            if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr) {
                onNavigateToNote?(id)
            }
        case "activate_mode", "deactivate_mode":
            if let idStr = args["noteId"] as? String, let id = UUID(uuidString: idStr) {
                onNavigateToNote?(id)
            }
        case "rename_folder":
            break // No detail view for folders
        case "create_journal_entry":
            if let date = args["date"] as? String {
                onNavigateToJournal?(date)
            }
        default:
            break
        }
    }
}

// MARK: - Constraint Priority Helper

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
