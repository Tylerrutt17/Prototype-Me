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
    /// Opens editors pre-filled with AI suggestion data.
    var onAddDirectiveSuggestion: ((String, String?) -> Void)?
    var onAddNoteSuggestion: ((String, String?) -> Void)?
    var onAddJournalSuggestion: ((String, Int?, String?, [String]?) -> Void)?   // date, rating, diary, tags
    /// Opens editors pre-filled for updates (entity already exists).
    var onEditDirective: ((UUID, String?, String?) -> Void)?    // id, title, body
    var onEditNote: ((UUID, String?, String?) -> Void)?         // id, title, body
    var onEditJournal: ((String, Int?, String?, [String]?) -> Void)?  // date, rating, diary, tags

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
    let thinkingContextPill = UIView()
    let thinkingContextLabel = UILabel()
    let actionConfirmView = ActionConfirmView()
    let suggestionsStack = UIStackView()
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
    var speakHistoryService: SpeakHistoryService?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackgroundGlows()
        startBackgroundGlowAnimations()
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // CAAnimations get removed when the view leaves the hierarchy; re-add on return.
        startBackgroundGlowAnimations()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutBackgroundGlows()
        guard isPro else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        proRecordingGradient.frame = proMicButton.bounds
        proRecordingGradient.cornerRadius = proMicButton.bounds.height / 2
        CATransaction.commit()
    }

    private func layoutBackgroundGlows() {
        guard backgroundGlows.count == 4, view.bounds.width > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let w = view.bounds.width
        let h = view.bounds.height
        let glowSize = w * 1.2

        // Half the glow extends beyond each corner so you only see the inner fade-in
        backgroundGlows[0].frame = CGRect(x: -glowSize * 0.5, y: -glowSize * 0.3, width: glowSize, height: glowSize)          // top-left
        backgroundGlows[1].frame = CGRect(x: w - glowSize * 0.5, y: -glowSize * 0.3, width: glowSize, height: glowSize)      // top-right
        backgroundGlows[2].frame = CGRect(x: -glowSize * 0.5, y: h - glowSize * 0.7, width: glowSize, height: glowSize)      // bottom-left
        backgroundGlows[3].frame = CGRect(x: w - glowSize * 0.5, y: h - glowSize * 0.7, width: glowSize, height: glowSize)   // bottom-right
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

        // Suggestion cards (shown when AI suggests directives to pick from)
        suggestionsStack.axis = .vertical
        suggestionsStack.spacing = DesignTokens.Spacing.sm
        suggestionsStack.isHidden = true
        responseContentStack.addArrangedSubview(suggestionsStack)

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

        // Confirm (Yes/No) buttons — shown when the AI asks a binary question
        let yesButton = Self.makeConfirmButton(title: "Yes", filled: true)
        yesButton.addTarget(self, action: #selector(confirmYesTapped), for: .touchUpInside)
        let noButton = Self.makeConfirmButton(title: "No", filled: false)
        noButton.addTarget(self, action: #selector(confirmNoTapped), for: .touchUpInside)
        let confirmRow = UIStackView(arrangedSubviews: [UIView(), yesButton, noButton, UIView()])
        confirmRow.axis = .horizontal
        confirmRow.alignment = .center
        confirmRow.spacing = DesignTokens.Spacing.sm
        confirmRow.isHidden = true
        confirmRow.tag = 9002
        responseContentStack.addArrangedSubview(confirmRow)

        // Thinking dots
        thinkingDotsView.isHidden = true
        thinkingDotsView.translatesAutoresizingMaskIntoConstraints = false

        // Thinking context pill (shown above thinking dots for externally-triggered prompts)
        thinkingContextPill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        thinkingContextPill.layer.cornerRadius = DesignTokens.Radii.lg
        thinkingContextPill.clipsToBounds = true
        thinkingContextPill.isHidden = true
        thinkingContextPill.translatesAutoresizingMaskIntoConstraints = false

        let contextIcon = UIImageView(image: UIImage(systemName: "sparkles"))
        contextIcon.tintColor = DesignTokens.Colors.accent
        contextIcon.contentMode = .scaleAspectFit
        contextIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        contextIcon.translatesAutoresizingMaskIntoConstraints = false

        thinkingContextLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        thinkingContextLabel.textColor = DesignTokens.Colors.accent
        thinkingContextLabel.numberOfLines = 2
        thinkingContextLabel.textAlignment = .center
        thinkingContextLabel.translatesAutoresizingMaskIntoConstraints = false

        let contextStack = UIStackView(arrangedSubviews: [contextIcon, thinkingContextLabel])
        contextStack.axis = .horizontal
        contextStack.spacing = DesignTokens.Spacing.xs
        contextStack.alignment = .center
        contextStack.translatesAutoresizingMaskIntoConstraints = false
        thinkingContextPill.addSubview(contextStack)

        // Vertical stack: pill (optional) above dots. Stack collapses pill when hidden.
        let thinkingAreaStack = UIStackView(arrangedSubviews: [thinkingContextPill, thinkingDotsView])
        thinkingAreaStack.axis = .vertical
        thinkingAreaStack.alignment = .center
        thinkingAreaStack.spacing = DesignTokens.Spacing.md
        thinkingAreaStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingAreaStack)

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

            thinkingDotsView.widthAnchor.constraint(equalToConstant: 80),
            thinkingDotsView.heightAnchor.constraint(equalToConstant: 40),

            contextIcon.widthAnchor.constraint(equalToConstant: 14),
            contextIcon.heightAnchor.constraint(equalToConstant: 14),

            contextStack.topAnchor.constraint(equalTo: thinkingContextPill.topAnchor, constant: DesignTokens.Spacing.sm),
            contextStack.bottomAnchor.constraint(equalTo: thinkingContextPill.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            contextStack.leadingAnchor.constraint(equalTo: thinkingContextPill.leadingAnchor, constant: DesignTokens.Spacing.md),
            contextStack.trailingAnchor.constraint(equalTo: thinkingContextPill.trailingAnchor, constant: -DesignTokens.Spacing.md),

            thinkingAreaStack.centerXAnchor.constraint(equalTo: responseScrollView.centerXAnchor),
            thinkingAreaStack.topAnchor.constraint(equalTo: responseScrollView.topAnchor, constant: pad * 2),
            thinkingAreaStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: pad),
            thinkingAreaStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -pad),
        ])
    }

    // MARK: - Thinking Context Pill

    /// Show a context pill above the thinking dots to explain what the AI is working on.
    /// Call this BEFORE sendMessage() when triggering from an external action like "Not Working?".
    func showThinkingContext(_ text: String) {
        thinkingContextLabel.text = text
        thinkingContextPill.isHidden = false
        thinkingContextPill.alpha = 0
        thinkingContextPill.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            self.thinkingContextPill.alpha = 1
            self.thinkingContextPill.transform = .identity
        }
    }

    func hideThinkingContext(animated: Bool = true) {
        guard !thinkingContextPill.isHidden else { return }
        guard animated else {
            thinkingContextPill.isHidden = true
            thinkingContextPill.alpha = 1
            thinkingContextPill.transform = .identity
            return
        }
        UIView.animate(withDuration: 0.2) {
            self.thinkingContextPill.alpha = 0
            self.thinkingContextPill.transform = CGAffineTransform(translationX: 0, y: -4)
        } completion: { _ in
            self.thinkingContextPill.isHidden = true
            self.thinkingContextPill.alpha = 1
            self.thinkingContextPill.transform = .identity
        }
    }

    // MARK: - Response State Transitions

    func showThinking() {
        emptyStateView.isHidden = true
        emptyStateView.alpha = 0

        // Hide upgrade + confirm rows if they were showing
        responseContentStack.arrangedSubviews.first { $0.tag == 9001 }?.isHidden = true
        responseContentStack.arrangedSubviews.first { $0.tag == 9002 }?.isHidden = true
        hideSuggestions()

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
        hideThinkingContext()
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

    // MARK: - Suggestion Cards (simple pick-to-open-editor cards)

    struct AISuggestion {
        let title: String
        let subtitle: String?
        let icon: String          // SF Symbol
        let isUpdate: Bool        // true = edit, false = create
        let toolCall: SpeakPendingToolCall
    }

    private var currentSuggestions: [AISuggestion] = []
    private var appliedSuggestionIndices: Set<Int> = []
    private(set) var lastOpenedSuggestionIndex: Int?

    func showSuggestions(_ suggestions: [AISuggestion]) {
        currentSuggestions = suggestions
        suggestionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, suggestion) in suggestions.enumerated() {
            let card = UIView()
            card.backgroundColor = DesignTokens.Colors.surfacePrimary
            card.layer.cornerRadius = DesignTokens.Radii.md
            card.layer.borderWidth = suggestion.isUpdate ? 1.5 : 1
            card.layer.borderColor = suggestion.isUpdate
                ? DesignTokens.Colors.warning.withAlphaComponent(0.4).cgColor
                : DesignTokens.Colors.separator.cgColor
            card.tag = index
            card.isUserInteractionEnabled = true
            card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(suggestionCardTapped(_:))))

            let iconView = UIImageView(image: UIImage(systemName: suggestion.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)))
            iconView.tintColor = DesignTokens.Colors.accent
            iconView.setContentHuggingPriority(.required, for: .horizontal)

            let titleLabel = UILabel()
            titleLabel.text = suggestion.title
            titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            titleLabel.textColor = DesignTokens.Colors.textPrimary
            titleLabel.numberOfLines = 2

            let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
            chevron.tintColor = DesignTokens.Colors.textTertiary
            chevron.setContentHuggingPriority(.required, for: .horizontal)

            let topRow = UIStackView(arrangedSubviews: [iconView, titleLabel, chevron])
            topRow.axis = .horizontal
            topRow.spacing = DesignTokens.Spacing.sm
            topRow.alignment = .center

            let stack = UIStackView(arrangedSubviews: [topRow])
            stack.axis = .vertical
            stack.spacing = DesignTokens.Spacing.xs

            // Badge: tells the user this isn't saved yet
            let badgeLabel = UILabel()
            badgeLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
            if suggestion.isUpdate {
                badgeLabel.text = "Unapplied changes \u{2014} tap to review"
                badgeLabel.textColor = DesignTokens.Colors.warning
            } else {
                badgeLabel.text = "Tap to review and add"
                badgeLabel.textColor = DesignTokens.Colors.textTertiary
            }
            stack.addArrangedSubview(badgeLabel)

            if let subtitle = suggestion.subtitle, !subtitle.isEmpty {
                let bodyLabel = UILabel()
                bodyLabel.text = subtitle
                bodyLabel.font = DesignTokens.Typography.caption1
                bodyLabel.textColor = DesignTokens.Colors.textSecondary
                bodyLabel.numberOfLines = 2
                stack.addArrangedSubview(bodyLabel)
            }

            stack.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(stack)
            let pad = DesignTokens.Spacing.md
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
                stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
                stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
                stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            ])

            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 10)
            suggestionsStack.addArrangedSubview(card)

            UIView.animate(
                withDuration: 0.35,
                delay: 0.1 + Double(index) * 0.08,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0,
                options: []
            ) {
                card.alpha = 1
                card.transform = .identity
            }
        }

        suggestionsStack.isHidden = false
    }

    func hideSuggestions() {
        suggestionsStack.isHidden = true
        suggestionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentSuggestions = []
        appliedSuggestionIndices = []
        lastOpenedSuggestionIndex = nil
    }

    /// Called by the coordinator when the user saves from an editor opened via suggestion card.
    func markSuggestionApplied() {
        guard let index = lastOpenedSuggestionIndex,
              index < suggestionsStack.arrangedSubviews.count else { return }

        appliedSuggestionIndices.insert(index)
        let card = suggestionsStack.arrangedSubviews[index]

        UIView.animate(withDuration: 0.3) {
            card.backgroundColor = DesignTokens.Colors.accentSecondary.withAlphaComponent(0.1)
            card.layer.borderColor = DesignTokens.Colors.accentSecondary.withAlphaComponent(0.4).cgColor
        }

        // Replace card content with applied state
        for sub in card.subviews { sub.removeFromSuperview() }

        let checkIcon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        checkIcon.tintColor = DesignTokens.Colors.accentSecondary

        let titleLabel = UILabel()
        titleLabel.text = currentSuggestions[index].title
        titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        let appliedLabel = UILabel()
        appliedLabel.text = currentSuggestions[index].isUpdate ? "Changes applied" : "Added"
        appliedLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        appliedLabel.textColor = DesignTokens.Colors.accentSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, appliedLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [checkIcon, textStack])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        Haptics.success()
    }

    @objc private func suggestionCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < currentSuggestions.count else { return }
        // Don't reopen already-applied suggestions
        guard !appliedSuggestionIndices.contains(view.tag) else { return }
        let suggestion = currentSuggestions[view.tag]
        let args = suggestion.toolCall.arguments
        lastOpenedSuggestionIndex = view.tag
        Haptics.light()

        switch suggestion.toolCall.function {
        case "create_directive":
            onAddDirectiveSuggestion?(
                args["title"] as? String ?? "",
                args["body"] as? String
            )
        case "create_note":
            onAddNoteSuggestion?(
                args["title"] as? String ?? "",
                args["body"] as? String
            )
        case "create_journal_entry", "update_journal_entry":
            onAddJournalSuggestion?(
                args["date"] as? String ?? "",
                args["rating"] as? Int,
                args["diary"] as? String,
                args["tags"] as? [String]
            )
        case "update_directive":
            if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr) {
                onEditDirective?(id, args["title"] as? String, args["body"] as? String)
            }
        case "update_note":
            if let idStr = args["id"] as? String, let id = UUID(uuidString: idStr) {
                onEditNote?(id, args["title"] as? String, args["body"] as? String)
            }
        default:
            break
        }
    }

    // MARK: - Action Confirm

    func showActions(_ toolCalls: [SpeakPendingToolCall]) {
        pendingToolCalls = toolCalls
        actionConfirmView.configure(with: toolCalls)
        actionConfirmView.onApprove = { [weak self] in self?.approveActions() }
        actionConfirmView.onDismiss = { [weak self] in self?.dismissActions() }
        actionConfirmView.onActionTapped = { [weak self] tc in self?.navigateToItem(tc) }
        actionConfirmView.onIndividualApprove = { [weak self] tc in self?.approveIndividualAction(tc) }

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
        // Fall back to text-based success display if any action failed
        let anyFailed = results.contains {
            let lower = $0.lowercased()
            return lower.hasPrefix("failed:") || lower.contains("could not")
        }
        if anyFailed {
            actionConfirmView.showSuccess(results: results)
        } else {
            actionConfirmView.animateToApplied()
        }

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
        hideThinkingContext()

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

    // MARK: - Confirmation Buttons

    static func makeConfirmButton(title: String, filled: Bool) -> UIButton {
        let button = UIButton(type: .system)
        var config: UIButton.Configuration = filled ? .filled() : .tinted()
        config.title = title
        config.baseBackgroundColor = filled ? DesignTokens.Colors.accent : DesignTokens.Colors.surfaceSecondary
        config.baseForegroundColor = filled ? .white : DesignTokens.Colors.textPrimary
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28)
        config.titleTextAttributesTransformer = .init { c in
            var c = c; c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold); return c
        }
        button.configuration = config
        return button
    }

    /// Displays the question in the response area and shows Yes/No buttons.
    func showConfirmation(question: String) {
        showResponse(text: question)
        // Show the confirm row (tag 9002) with a fade
        guard let confirmRow = responseContentStack.arrangedSubviews.first(where: { $0.tag == 9002 }) else { return }
        confirmRow.isHidden = false
        confirmRow.alpha = 0
        confirmRow.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(
            withDuration: 0.35,
            delay: 0.15,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0,
            options: []
        ) {
            confirmRow.alpha = 1
            confirmRow.transform = .identity
        }
    }

    private func hideConfirmationRow() {
        responseContentStack.arrangedSubviews.first { $0.tag == 9002 }?.isHidden = true
    }

    @objc private func confirmYesTapped() {
        hideConfirmationRow()
        sendMessage("yes")
    }

    @objc private func confirmNoTapped() {
        hideConfirmationRow()
        sendMessage("no")
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

        // Log the runs so we can see what intents markdown produced
        var runCount = 0
        var boldCount = 0
        var italicCount = 0
        for run in attributed.runs {
            runCount += 1
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.stronglyEmphasized) { boldCount += 1 }
                if intent.contains(.emphasized) { italicCount += 1 }
            }
        }
        print("[Speak] Markdown parsed: \(runCount) runs, \(boldCount) bold, \(italicCount) italic")

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
        titleLabel.text = "Ask"
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        quotaLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        quotaLabel.textColor = DesignTokens.Colors.textTertiary

        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(quotaLabel)

        navBar.setTitle(nil, animated: false)
        navBar.setTitleView(titleStack)

        navBar.setRightButtons([
            NavBarButton(systemImage: "clock.arrow.circlepath") { [weak self] in
                self?.showHistory()
            },
            NavBarButton(systemImage: "gearshape") { [weak self] in
                self?.showSpeakSettings()
            }
        ])

        Task {
            if let apiClient, let quota: UsageQuota = try? await apiClient.get("/v1/usage") {
                await MainActor.run {
                    self.quotaLabel.text = "\(quota.remaining)/\(quota.dailyLimit) Prototype left"
                }
            }
        }
    }

    private func showHistory() {
        let vc = SpeakHistoryViewController()
        vc.onUndo = { [weak self] entry in
            guard let self else { return "" }
            let result = await self.actionExecutor.undo(entry)
            await MainActor.run {
                self.removeHistory(entryId: entry.id)
            }
            return result
        }
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DesignTokens.Radii.xl
        }
        // Load entries before presenting
        Task {
            let entries = (try? await speakHistoryService?.recent()) ?? []
            await MainActor.run {
                vc.entries = entries
                self.present(vc, animated: true)
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
    private var backgroundGlows: [CAGradientLayer] = []

    /// Soft radial gradient for corner glows — transparent at edges, tinted at center.
    /// `intensity` scales the alpha; 1.0 = strong, 0.5 = ambient background wash.
    static func makeCornerGlow(color: UIColor, intensity: CGFloat = 1.0) -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.type = .radial
        layer.colors = [
            color.withAlphaComponent(0.28 * intensity).cgColor,
            color.withAlphaComponent(0.14 * intensity).cgColor,
            UIColor.clear.cgColor,
        ]
        layer.locations = [0.0, 0.4, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1.0, y: 1.0)
        return layer
    }

    /// Four persistent radial glows in each corner, behind all content.
    private func setupBackgroundGlows() {
        let colors: [UIColor] = [
            DesignTokens.Colors.accent,  // top-left
            .systemPink,                 // top-right
            .systemTeal,                 // bottom-left
            .systemPurple,               // bottom-right
        ]
        for color in colors {
            let glow = Self.makeCornerGlow(color: color, intensity: 0.8)
            view.layer.insertSublayer(glow, at: 0)
            backgroundGlows.append(glow)
        }

        // Restart animations on app-foreground (backgrounding removes them)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleAppDidBecomeActive() {
        startBackgroundGlowAnimations()
    }

    /// Adds drift animations to each glow. Safe to call multiple times —
    /// layer.add(_:forKey:) replaces any existing animation under that key.
    /// Called from viewDidLoad, viewWillAppear, and didBecomeActive notification.
    func startBackgroundGlowAnimations() {
        guard backgroundGlows.count == 4 else { return }

        // Per-glow drift distances + durations for uncorrelated motion
        let xDistances: [CGFloat] = [220, -200, 230, -210]
        let yDistances: [CGFloat] = [-180, 210, -170, 220]
        let xDurations: [CFTimeInterval] = [5.5, 6.5, 6.0, 7.0]
        let yDurations: [CFTimeInterval] = [7.5, 6.0, 7.0, 6.5]

        // Phase-shift each animation into the middle of its cycle (set beginTime
        // in the past) so motion is immediately visible — no slow ramp from rest.
        let now = CACurrentMediaTime()
        for (index, glow) in backgroundGlows.enumerated() {
            let xPhaseShift = 2.0 + Double(index) * 1.5  // seconds into the cycle
            let yPhaseShift = 3.0 + Double(index) * 1.2

            let xAnim = CABasicAnimation(keyPath: "transform.translation.x")
            xAnim.fromValue = 0
            xAnim.toValue = xDistances[index]
            xAnim.duration = xDurations[index]
            xAnim.autoreverses = true
            xAnim.repeatCount = .infinity
            xAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            xAnim.beginTime = now - xPhaseShift
            glow.add(xAnim, forKey: "driftX")

            let yAnim = CABasicAnimation(keyPath: "transform.translation.y")
            yAnim.fromValue = 0
            yAnim.toValue = yDistances[index]
            yAnim.duration = yDurations[index]
            yAnim.autoreverses = true
            yAnim.repeatCount = .infinity
            yAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            yAnim.beginTime = now - yPhaseShift
            glow.add(yAnim, forKey: "driftY")
        }
    }

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        // Background glows live on the main view (see setupBackgroundGlows)
        // so they remain visible throughout the whole Speak tab.

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

        let suggestions: [(icon: String, text: String, color: UIColor)] = [
            ("plus.circle.fill", "\"Add a directive to meditate daily\"", DesignTokens.Colors.accent),
            ("pencil.circle.fill", "\"Update my cold shower directive\"", .systemOrange),
            ("book.fill", "\"Log my journal \u{2014} today was a great day\"", .systemPurple),
            ("bolt.fill", "\"Switch to my Deep Work mode\"", .systemYellow),
            ("lightbulb.fill", "\"What should I focus on today?\"", .systemPink),
            ("arrow.triangle.2.circlepath", "\"What's not working in my routine?\"", .systemTeal),
        ]

        // Horizontal offsets create a zigzag layout; animation gives a subtle float.
        let horizontalOffsets: [CGFloat] = [-18, 20, -14, 16, -20, 14]

        let chipsStack = UIStackView()
        chipsStack.axis = .vertical
        chipsStack.spacing = DesignTokens.Spacing.sm
        chipsStack.alignment = .center

        for (index, suggestion) in suggestions.enumerated() {
            let chip = makeSuggestionChip(icon: suggestion.icon, text: suggestion.text, color: suggestion.color)
            chip.transform = CGAffineTransform(translationX: horizontalOffsets[index], y: 0)
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

    private func makeSuggestionChip(icon: String, text: String, color: UIColor) -> UIView {
        let pill = UIView()
        pill.backgroundColor = color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = DesignTokens.Radii.md
        pill.layer.borderWidth = 1
        pill.layer.borderColor = color.withAlphaComponent(0.22).cgColor

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = color
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
        case "create_journal_entry", "update_journal_entry":
            if let date = args["date"] as? String {
                onNavigateToJournal?(date)
            }
        default:
            break
        }
    }

    // MARK: - History

    /// Persists new entries via the history service. Pruning to max size
    /// happens inside the service.
    func recordHistory(_ entries: [SpeakHistoryEntry]) {
        guard !entries.isEmpty, let speakHistoryService else { return }
        Task {
            for entry in entries {
                do {
                    try await speakHistoryService.record(entry)
                } catch {
                    print("[Speak] Failed to record history: \(error)")
                }
            }
        }
    }

    /// Removes an entry from the history DB (called after undo completes).
    func removeHistory(entryId: UUID) {
        guard let speakHistoryService else { return }
        Task {
            try? await speakHistoryService.remove(id: entryId)
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
