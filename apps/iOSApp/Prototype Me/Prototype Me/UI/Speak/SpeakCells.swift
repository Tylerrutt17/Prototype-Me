import UIKit

// MARK: - Suggestion Tap Gesture

final class SuggestionTapGesture: UITapGestureRecognizer {
    var promptText: String?
}

// MARK: - Thinking Dots View

final class ThinkingDotsView: UIView {

    private let dotSize: CGFloat = 10
    private let dotSpacing: CGFloat = 14
    private var dots: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        dots = (0..<3).map { _ in
            let dot = UIView()
            dot.backgroundColor = DesignTokens.Colors.accent
            dot.layer.cornerRadius = dotSize / 2
            return dot
        }

        let stack = UIStackView(arrangedSubviews: dots)
        stack.axis = .horizontal
        stack.spacing = dotSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for dot in dots {
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize),
            ])
        }

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func startAnimating() {
        for (i, dot) in dots.enumerated() {
            dot.alpha = 1
            dot.transform = .identity

            let delay = TimeInterval(i) * 0.16
            UIView.animate(
                withDuration: 0.45,
                delay: delay,
                options: [.repeat, .autoreverse, .curveEaseInOut]
            ) {
                dot.transform = CGAffineTransform(translationX: 0, y: -10)
                dot.alpha = 0.3
            }
        }
    }

    func stopAnimating() {
        for dot in dots {
            dot.layer.removeAllAnimations()
            dot.alpha = 1
            dot.transform = .identity
        }
    }
}

// MARK: - Action Confirm View

final class ActionConfirmView: UIView {

    var onApprove: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onActionTapped: ((SpeakPendingToolCall) -> Void)?

    private var toolCalls: [SpeakPendingToolCall] = []
    private let cardView = UIView()
    private let contentStack = UIStackView()
    private let actionsStack = UIStackView()
    private let buttonStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        cardView.backgroundColor = DesignTokens.Colors.surfacePrimary
        cardView.layer.cornerRadius = DesignTokens.Radii.lg
        cardView.layer.borderWidth = 1.5
        cardView.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        actionsStack.axis = .vertical
        actionsStack.spacing = DesignTokens.Spacing.sm

        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.md
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(actionsStack)
        cardView.addSubview(contentStack)

        let approveButton = UIButton(type: .system)
        var approveConfig = UIButton.Configuration.filled()
        approveConfig.title = "Approve"
        approveConfig.baseBackgroundColor = DesignTokens.Colors.accent
        approveConfig.baseForegroundColor = .white
        approveConfig.cornerStyle = .capsule
        approveConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        approveConfig.titleTextAttributesTransformer = .init { c in
            var c = c; c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold); return c
        }
        approveButton.configuration = approveConfig
        approveButton.addTarget(self, action: #selector(approveTapped), for: .touchUpInside)

        let dismissButton = UIButton(type: .system)
        var dismissConfig = UIButton.Configuration.plain()
        dismissConfig.title = "Dismiss"
        dismissConfig.baseForegroundColor = DesignTokens.Colors.textTertiary
        dismissConfig.titleTextAttributesTransformer = .init { c in
            var c = c; c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium); return c
        }
        dismissButton.configuration = dismissConfig
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        // Wrapper row so the horizontal button group isn't forced to fill the full width
        let buttonRow = UIStackView(arrangedSubviews: [approveButton, dismissButton, UIView()])
        buttonRow.axis = .horizontal
        buttonRow.spacing = DesignTokens.Spacing.sm

        buttonStack.axis = .vertical
        buttonStack.addArrangedSubview(buttonRow)
        contentStack.addArrangedSubview(buttonStack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: pad),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -pad),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
        ])
    }

    func configure(with toolCalls: [SpeakPendingToolCall]) {
        self.toolCalls = toolCalls
        actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttonStack.isHidden = false
        for (index, tc) in toolCalls.enumerated() {
            let card = buildActionCard(for: tc)
            // Only make tappable if there's an existing item to navigate to (not creates)
            if tc.actionType != .create {
                card.isUserInteractionEnabled = true
                card.tag = index
                let tap = UITapGestureRecognizer(target: self, action: #selector(actionCardTapped(_:)))
                card.addGestureRecognizer(tap)
            }
            actionsStack.addArrangedSubview(card)
        }
    }

    @objc private func actionCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < toolCalls.count else { return }
        onActionTapped?(toolCalls[view.tag])
    }

    func showSuccess(results: [String]) {
        actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttonStack.isHidden = true
        for result in results {
            let label = UILabel()
            label.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
            label.textColor = DesignTokens.Colors.accent
            label.numberOfLines = 0
            label.text = "\u{2713} \(result)"
            actionsStack.addArrangedSubview(label)
        }
    }

    /// Morphs the pending action cards into their applied state with a staggered
    /// slide+fade: buttons drop out, card pulses, and the action cards flip to the
    /// applied version (icon → checkmark, badge → past tense, diffs collapse to
    /// final values only). The contentStack auto-collapses the freed button space.
    func animateToApplied() {
        // Phase 1 — buttons slide down and fade out, card pulses
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.buttonStack.alpha = 0
                self.buttonStack.transform = CGAffineTransform(translationX: 0, y: 12)
            }
        )

        // Brief "seal" pulse on the whole card
        UIView.animate(
            withDuration: 0.18,
            delay: 0.1,
            options: [.curveEaseInOut],
            animations: {
                self.cardView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            }
        ) { _ in
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, options: [], animations: {
                self.cardView.transform = .identity
            })
        }

        // Phase 2 — swap in applied cards, then collapse the button space
        UIView.animate(
            withDuration: 0.2,
            delay: 0.1,
            options: [.curveEaseOut],
            animations: {
                self.actionsStack.alpha = 0
                self.actionsStack.transform = CGAffineTransform(translationX: 0, y: -4)
            }
        ) { _ in
            // Build applied cards
            self.actionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for tc in self.toolCalls {
                self.actionsStack.addArrangedSubview(self.buildActionCard(for: tc, applied: true))
            }
            self.actionsStack.transform = CGAffineTransform(translationX: 0, y: 4)

            // Fade in + spring down into place, simultaneously collapse buttons
            UIView.animate(
                withDuration: 0.38,
                delay: 0,
                usingSpringWithDamping: 0.78,
                initialSpringVelocity: 0.1,
                options: [],
                animations: {
                    self.actionsStack.alpha = 1
                    self.actionsStack.transform = .identity
                    self.buttonStack.isHidden = true
                    self.layoutIfNeeded()
                }
            )
        }
    }

    private static func iconName(for itemType: String) -> String {
        switch itemType.lowercased() {
        case "directive":   return "target"
        case "journal":     return "book.fill"
        case "note":        return "doc.text.fill"
        case "mode":        return "bolt.fill"
        case "folder":      return "folder.fill"
        case "framework":   return "square.grid.2x2.fill"
        case "situation":   return "exclamationmark.triangle.fill"
        case "goal":        return "flag.fill"
        default:            return "doc.fill"
        }
    }

    private func buildActionCard(for tc: SpeakPendingToolCall, applied: Bool = false) -> UIView {
        let container = UIView()
        container.backgroundColor = tc.actionType.color.withAlphaComponent(0.08)
        container.layer.cornerRadius = DesignTokens.Radii.md

        // Large item type icon (becomes a checkmark once applied)
        let typeIconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let iconName = applied ? "checkmark.circle.fill" : Self.iconName(for: tc.itemType)
        let typeIconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: typeIconConfig))
        typeIconView.tintColor = tc.actionType.color
        typeIconView.setContentHuggingPriority(.required, for: .horizontal)
        typeIconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Item type label (prominent)
        let typeLabel = UILabel()
        typeLabel.text = tc.itemType.capitalized
        typeLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        typeLabel.textColor = DesignTokens.Colors.textPrimary

        // Dot separator
        let dotLabel = UILabel()
        dotLabel.text = "\u{00B7}"
        dotLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .bold)
        dotLabel.textColor = DesignTokens.Colors.textTertiary

        // Action badge (flips to past tense when applied)
        let badgeLabel = UILabel()
        badgeLabel.text = (applied ? tc.actionType.appliedLabel : tc.actionType.label).uppercased()
        badgeLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        badgeLabel.textColor = tc.actionType.color

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [typeIconView, typeLabel, dotLabel, badgeLabel, spacer])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.sm
        headerRow.alignment = .center

        let nameLabel = UILabel()
        nameLabel.text = tc.itemName
        nameLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        nameLabel.textColor = DesignTokens.Colors.textPrimary
        nameLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [headerRow, nameLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs

        for change in tc.changes {
            stack.addArrangedSubview(buildChangeRow(change: change, color: tc.actionType.color, applied: applied))
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
        ])
        return container
    }

    private func buildChangeRow(change: SpeakActionChange, color: UIColor, applied: Bool = false) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2

        let fieldLabel = UILabel()
        fieldLabel.text = change.field.capitalized
        fieldLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        fieldLabel.textColor = DesignTokens.Colors.textTertiary
        stack.addArrangedSubview(fieldLabel)

        // Applied mode: show only the final value, no strikethrough/arrow
        if applied {
            let newLabel = UILabel()
            newLabel.text = change.newValue
            newLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
            newLabel.textColor = DesignTokens.Colors.textPrimary
            newLabel.numberOfLines = 3
            stack.addArrangedSubview(newLabel)
            return stack
        }

        if let oldValue = change.oldValue {
            let oldLabel = UILabel()
            let oldAttr = NSMutableAttributedString(
                string: oldValue,
                attributes: [
                    .font: DesignTokens.Typography.rounded(style: .footnote, weight: .regular),
                    .foregroundColor: DesignTokens.Colors.textTertiary,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                ]
            )
            oldLabel.attributedText = oldAttr
            oldLabel.numberOfLines = 2
            stack.addArrangedSubview(oldLabel)

            let arrowNew = UILabel()
            arrowNew.text = "\u{2192} \(change.newValue)"
            arrowNew.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
            arrowNew.textColor = color
            arrowNew.numberOfLines = 2
            stack.addArrangedSubview(arrowNew)
        } else {
            let newLabel = UILabel()
            newLabel.text = change.newValue
            newLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
            newLabel.textColor = DesignTokens.Colors.textPrimary
            newLabel.numberOfLines = 3
            stack.addArrangedSubview(newLabel)
        }

        return stack
    }

    @objc private func approveTapped() { onApprove?() }
    @objc private func dismissTapped() { onDismiss?() }
}
