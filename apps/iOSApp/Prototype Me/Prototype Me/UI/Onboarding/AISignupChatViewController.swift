import UIKit

/// Single-input AI signup screen: text input → thinking animation → seed plan cards stack in.
/// No chat bubbles — just a clean input-to-results flow.
final class AISignupChatViewController: UIViewController {

    var onSeedPlanReady: (([SeedPlanCard]) -> Void)?
    var onSkipped: (() -> Void)?

    // MARK: - UI

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,
        ]
        layer.locations = [0.0, 0.5, 1.0]
        return layer
    }()

    private let promptLabel = UILabel()
    private let hintLabel = UILabel()
    private let inputPanel = GlassPanelView(cornerRadius: DesignTokens.Radii.lg)
    private let textView = UITextView()
    private let micButton = VoiceInputButton()
    private let submitButton = AppButton(title: "Generate My Plan")
    private let skipButton = UIButton(type: .system)
    private let thinkingView = ThinkingAnimationView()
    private let cardStack = UIStackView()
    private let confirmButton = AppButton(title: "Looks Good!")
    private let editButton = UIButton(type: .system)

    private var inputPanelBottom: NSLayoutConstraint!
    private var cardStackCenterY: NSLayoutConstraint!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(gradientLayer)
        setupUI()
        observeKeyboard()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Prompt
        promptLabel.text = "What are you working on\nimproving right now?"
        promptLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .semibold)
        promptLabel.textColor = DesignTokens.Colors.textPrimary
        promptLabel.textAlignment = .center
        promptLabel.numberOfLines = 0
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(promptLabel)

        // Hint
        hintLabel.text = "Goals, habits, areas of your life..."
        hintLabel.font = DesignTokens.Typography.subheadline
        hintLabel.textColor = DesignTokens.Colors.textTertiary
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        // Input panel
        inputPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputPanel)

        textView.backgroundColor = .clear
        textView.font = DesignTokens.Typography.body
        textView.textColor = DesignTokens.Colors.textPrimary
        textView.tintColor = DesignTokens.Colors.accent
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false
        inputPanel.addSubview(textView)

        // Mic button
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.onTranscription = { [weak self] text in
            self?.textView.text = text
        }
        micButton.onPartialResult = { [weak self] text in
            self?.textView.text = text
        }
        micButton.onError = { [weak self] message in
            let alert = UIAlertController(title: "Voice Input", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
        inputPanel.addSubview(micButton)

        // Submit
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(submitButton)

        // Skip
        skipButton.setTitle("Skip for now", for: .normal)
        skipButton.titleLabel?.font = DesignTokens.Typography.subheadline
        skipButton.setTitleColor(DesignTokens.Colors.textSecondary, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        // Thinking (hidden initially)
        thinkingView.alpha = 0
        thinkingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(thinkingView)

        // Card stack (hidden initially)
        cardStack.axis = .vertical
        cardStack.spacing = DesignTokens.Spacing.sm
        cardStack.alpha = 0
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardStack)

        // Confirm button (hidden initially)
        confirmButton.alpha = 0
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confirmButton)

        // Edit button (hidden initially)
        editButton.setTitle("Edit plan", for: .normal)
        editButton.titleLabel?.font = DesignTokens.Typography.subheadline
        editButton.setTitleColor(DesignTokens.Colors.textSecondary, for: .normal)
        editButton.alpha = 0
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editButton)

        inputPanelBottom = inputPanel.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: 20)

        NSLayoutConstraint.activate([
            promptLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xxxl * 2),
            promptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            promptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),

            hintLabel.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            inputPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            inputPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),
            inputPanelBottom,
            inputPanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            inputPanel.heightAnchor.constraint(lessThanOrEqualToConstant: 160),

            textView.topAnchor.constraint(equalTo: inputPanel.topAnchor),
            textView.bottomAnchor.constraint(equalTo: inputPanel.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: inputPanel.leadingAnchor, constant: DesignTokens.Spacing.sm),
            textView.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -DesignTokens.Spacing.xs),

            micButton.trailingAnchor.constraint(equalTo: inputPanel.trailingAnchor, constant: -DesignTokens.Spacing.md),
            micButton.centerYAnchor.constraint(equalTo: inputPanel.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 36),
            micButton.heightAnchor.constraint(equalToConstant: 36),

            submitButton.topAnchor.constraint(equalTo: inputPanel.bottomAnchor, constant: DesignTokens.Spacing.lg),
            submitButton.leadingAnchor.constraint(equalTo: inputPanel.leadingAnchor),
            submitButton.trailingAnchor.constraint(equalTo: inputPanel.trailingAnchor),

            skipButton.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: DesignTokens.Spacing.md),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            thinkingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            thinkingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            cardStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            cardStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),
            cardStack.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: DesignTokens.Spacing.xxl),

            confirmButton.topAnchor.constraint(equalTo: cardStack.bottomAnchor, constant: DesignTokens.Spacing.xxl),
            confirmButton.leadingAnchor.constraint(equalTo: cardStack.leadingAnchor),
            confirmButton.trailingAnchor.constraint(equalTo: cardStack.trailingAnchor),

            editButton.topAnchor.constraint(equalTo: confirmButton.bottomAnchor, constant: DesignTokens.Spacing.md),
            editButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func submitTapped() {
        textView.resignFirstResponder()
        Haptics.light()
        startThinking()
    }

    @objc private func skipTapped() {
        onSkipped?()
    }

    @objc private func confirmTapped() {
        Haptics.success()
        onSeedPlanReady?(SampleData.seedPlanCards)
    }

    @objc private func editTapped() {
        // For now, same as confirm — will route to SeedPlanReview for editing
        Haptics.light()
        onSeedPlanReady?(SampleData.seedPlanCards)
    }

    // MARK: - Thinking Flow

    private func startThinking() {
        // Hide input area
        UIView.animate(withDuration: 0.3, animations: {
            self.inputPanel.alpha = 0
            self.inputPanel.transform = CGAffineTransform(translationX: 0, y: 20)
            self.submitButton.alpha = 0
            self.skipButton.alpha = 0
            self.hintLabel.alpha = 0
        })

        // Show thinking dots
        UIView.animate(withDuration: 0.3, delay: 0.3) {
            self.thinkingView.alpha = 1
        }
        thinkingView.startAnimating()

        // Crossfade prompt text
        crossfadePrompt(to: "Analyzing your goals...", delay: 0.3)
        crossfadePrompt(to: "Building your plan...", delay: 1.8)

        // After 3s, show results
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.showResults()
        }
    }

    private func crossfadePrompt(to text: String, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            UIView.transition(with: self?.promptLabel ?? UIView(), duration: 0.4, options: .transitionCrossDissolve) {
                self?.promptLabel.text = text
            }
        }
    }

    private func showResults() {
        Haptics.success()

        // Hide thinking
        thinkingView.stopAnimating()
        UIView.animate(withDuration: 0.2) { self.thinkingView.alpha = 0 }

        // Update prompt
        UIView.transition(with: promptLabel, duration: 0.4, options: .transitionCrossDissolve) {
            self.promptLabel.text = "Here's your starter plan"
        }

        // Build card views
        let cards = SampleData.seedPlanCards
        for card in cards {
            let cardView = SeedPlanCardView()
            cardView.configure(with: card)
            cardView.alpha = 0
            cardView.transform = CGAffineTransform(translationX: 0, y: 40)
            cardStack.addArrangedSubview(cardView)
        }

        // Stack cards in with stagger
        cardStack.alpha = 1
        for (index, cardView) in cardStack.arrangedSubviews.enumerated() {
            let delay = 0.2 * Double(index)
            UIView.animate(
                withDuration: 0.5,
                delay: delay,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.2
            ) {
                cardView.alpha = 1
                cardView.transform = .identity
            } completion: { _ in
                if index == 0 { Haptics.light() }
            }
        }

        // Show confirm/edit after cards land
        let totalDelay = 0.2 * Double(cards.count) + 0.5
        UIView.animate(withDuration: 0.3, delay: totalDelay) {
            self.confirmButton.alpha = 1
            self.editButton.alpha = 1
        }
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let offset = -(frame.height / 2 - 40)
        inputPanelBottom.constant = offset
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        inputPanelBottom.constant = 20
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }
}

// MARK: - UITextViewDelegate

extension AISignupChatViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: text).count <= FieldLimits.AI.prompt
    }
}
