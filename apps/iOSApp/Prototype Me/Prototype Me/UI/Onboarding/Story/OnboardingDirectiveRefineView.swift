import UIKit

/// One fixed mode card at top (Focus-tab style). Underneath, directives cycle
/// through trial-and-error: each directive gets magnified, a thought bubble
/// shows why it didn't work, the text gets struck through, a new thought bubble
/// shows what's better, then the text swaps to the improved directive.
/// Same "fat bubble" + evolution beats as OnboardingSystemEvolvesView, but
/// focused on a single mode.
final class OnboardingDirectiveRefineView: UIView, StoryAnimatable {

    private let modeCard = UIView()
    private let modeIconView = UIImageView()
    private let modeTitleLabel = UILabel()
    private let modeBodyLabel = UILabel()
    private let checkBadge = UIImageView()

    private let directivesHeader = UILabel()
    private let directivesStack = UIStackView()
    private var directiveCards: [UIView] = []
    private var directiveLabels: [UILabel] = []

    private let highlightOverlay = UIView()
    private let thoughtBubble = UILabel()
    private let underlineSweep = UIView()

    private let modeColor = NoteKind.mode.color
    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0

    private struct DirectiveChange {
        let oldText: String
        let newText: String
        let strikeComment: String
        let replaceComment: String
    }

    private let modeName = "Winding Down - Sleeping Better"
    private let modeBody = "That last hour before bed."

    private let changes: [DirectiveChange] = [
        DirectiveChange(
            oldText: "Stop using electronics",
            newText: "Screens off an hour before bed",
            strikeComment: "\"stop\" — Not specific enough",
            replaceComment: "Let's make a clean cutoff"
        ),
        DirectiveChange(
            oldText: "Go to bed earlier",
            newText: "Same bedtime, every night",
            strikeComment: "\"earlier\" — relative to what?",
            replaceComment: "a consistent time my body learns"
        ),
        DirectiveChange(
            oldText: "Calm down at night",
            newText: "Stretch + read for 15 min",
            strikeComment: "\"calm down\" — just lay there wired",
            replaceComment: "a routine my body actually knows"
        ),
    ]

    var prefersFullWidth: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildLayout()
        }
    }

    // MARK: - Build

    private func buildLayout() {
        buildModeCard()
        buildDirectives()
        buildThoughtBubble()
    }

    private func buildModeCard() {
        modeCard.backgroundColor = modeColor.withAlphaComponent(0.08)
        modeCard.layer.cornerRadius = DesignTokens.Radii.lg
        modeCard.layer.borderWidth = 1.5
        modeCard.layer.borderColor = modeColor.cgColor
        modeCard.alpha = 0
        modeCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modeCard)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        modeIconView.image = UIImage(systemName: "bolt.fill", withConfiguration: iconConfig)
        modeIconView.tintColor = modeColor
        modeIconView.contentMode = .scaleAspectFit
        modeIconView.translatesAutoresizingMaskIntoConstraints = false

        modeTitleLabel.text = modeName
        modeTitleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        modeTitleLabel.textColor = modeColor

        modeBodyLabel.text = modeBody
        modeBodyLabel.font = DesignTokens.Typography.caption1
        modeBodyLabel.textColor = modeColor.withAlphaComponent(0.7)
        modeBodyLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [modeTitleLabel, modeBodyLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xs

        let row = UIStackView(arrangedSubviews: [modeIconView, textStack])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        modeCard.addSubview(row)

        let badgeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        checkBadge.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: badgeConfig)
        checkBadge.tintColor = modeColor
        checkBadge.translatesAutoresizingMaskIntoConstraints = false
        modeCard.addSubview(checkBadge)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            modeCard.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.md),
            modeCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            modeCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),

            modeIconView.widthAnchor.constraint(equalToConstant: 24),
            modeIconView.heightAnchor.constraint(equalToConstant: 24),

            row.topAnchor.constraint(equalTo: modeCard.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: modeCard.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: modeCard.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(lessThanOrEqualTo: checkBadge.leadingAnchor, constant: -DesignTokens.Spacing.sm),

            checkBadge.topAnchor.constraint(equalTo: modeCard.topAnchor, constant: DesignTokens.Spacing.sm),
            checkBadge.trailingAnchor.constraint(equalTo: modeCard.trailingAnchor, constant: -DesignTokens.Spacing.sm),
        ])
    }

    private func buildDirectives() {
        directivesHeader.text = "DIRECTIVES"
        directivesHeader.font = DesignTokens.Typography.caption1
        directivesHeader.textColor = DesignTokens.Colors.textTertiary
        directivesHeader.alpha = 0
        directivesHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(directivesHeader)

        directivesStack.axis = .vertical
        directivesStack.spacing = DesignTokens.Spacing.sm
        directivesStack.alignment = .fill
        directivesStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(directivesStack)

        NSLayoutConstraint.activate([
            directivesHeader.topAnchor.constraint(equalTo: modeCard.bottomAnchor, constant: DesignTokens.Spacing.xl),
            directivesHeader.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),

            directivesStack.topAnchor.constraint(equalTo: directivesHeader.bottomAnchor, constant: DesignTokens.Spacing.sm),
            directivesStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            directivesStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        for change in changes {
            let (card, label) = makeDirectiveCard(text: change.oldText)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 8)
            directivesStack.addArrangedSubview(card)
            directiveCards.append(card)
            directiveLabels.append(label)
        }
    }

    private func makeDirectiveCard(text: String) -> (UIView, UILabel) {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor

        let dot = UIView()
        dot.backgroundColor = DesignTokens.Colors.accent
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dot)

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary
        label.numberOfLines = 1

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: chevronConfig))
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, UIView(), chevron])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),
            dot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            dot.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: DesignTokens.Spacing.sm),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        return (card, label)
    }

    private func buildThoughtBubble() {
        highlightOverlay.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        highlightOverlay.layer.cornerRadius = DesignTokens.Radii.sm
        highlightOverlay.layer.borderWidth = 1.5
        highlightOverlay.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor
        highlightOverlay.alpha = 0
        addSubview(highlightOverlay)

        thoughtBubble.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        thoughtBubble.textColor = DesignTokens.Colors.textSecondary
        thoughtBubble.textAlignment = .center
        thoughtBubble.numberOfLines = 2
        thoughtBubble.alpha = 0
        thoughtBubble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thoughtBubble)

        underlineSweep.layer.cornerRadius = 1.5
        underlineSweep.alpha = 0
        addSubview(underlineSweep)

        NSLayoutConstraint.activate([
            thoughtBubble.centerXAnchor.constraint(equalTo: centerXAnchor),
            thoughtBubble.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            thoughtBubble.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
            thoughtBubble.topAnchor.constraint(equalTo: directivesStack.bottomAnchor, constant: DesignTokens.Spacing.lg),
        ])
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        cycleID += 1
        let currentCycle = cycleID
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            modeCard.alpha = 1
            directivesHeader.alpha = 1
            for card in directiveCards { card.alpha = 1; card.transform = .identity }
            return
        }

        // Mode card springs in
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.modeCard.alpha = 1
        }

        // Header
        UIView.animate(withDuration: 0.3, delay: 0.4, options: .curveEaseOut) {
            self.directivesHeader.alpha = 1
        }

        // Directives cascade in
        for (i, card) in directiveCards.enumerated() {
            UIView.animate(withDuration: 0.4, delay: 0.5 + Double(i) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                card.alpha = 1
                card.transform = .identity
            }
        }

        // Start the refine loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.refineStep(0, cycle: currentCycle)
        }
    }

    private func refineStep(_ step: Int, cycle: Int) {
        guard !isStopped, cycleID == cycle else { return }

        let currentStep = step % changes.count
        let change = changes[currentStep]
        let label = directiveLabels[currentStep]
        let oldText = label.attributedText?.string ?? label.text ?? ""

        // ── 1. MAGNIFY — highlight box + scale label up ──
        layoutIfNeeded()
        let labelFrame = label.convert(label.bounds, to: self)
        let inset: CGFloat = 6
        highlightOverlay.frame = labelFrame.insetBy(dx: -inset, dy: -inset)
        highlightOverlay.layer.cornerRadius = DesignTokens.Radii.sm

        let scale: CGFloat = 1.3
        let shiftX = label.bounds.width * ((scale - 1) / 2)
        let magnifyTransform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: shiftX / scale, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
            self.highlightOverlay.alpha = 1
            self.highlightOverlay.transform = magnifyTransform
            label.transform = magnifyTransform
        }

        // ── 2. THOUGHT (strike) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }
            self.showThought(change.strikeComment, color: DesignTokens.Colors.destructive.withAlphaComponent(0.8))
        }

        // ── 3. STRIKETHROUGH ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            UIView.animate(withDuration: 0.15, animations: {
                self.highlightOverlay.backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.15)
                self.highlightOverlay.layer.borderColor = DesignTokens.Colors.destructive.withAlphaComponent(0.5).cgColor
            }, completion: { _ in
                UIView.animate(withDuration: 0.15, animations: {
                    label.alpha = 0
                }, completion: { _ in
                    label.attributedText = NSAttributedString(string: oldText, attributes: [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: DesignTokens.Colors.destructive,
                        .foregroundColor: DesignTokens.Colors.destructive.withAlphaComponent(0.5),
                        .font: DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold),
                    ])
                    UIView.animate(withDuration: 0.15) {
                        label.alpha = 1
                    }
                })
            })
            Haptics.light()
        }

        // ── 4. THOUGHT (replace) ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }
            self.showThought(change.replaceComment, color: DesignTokens.Colors.success)
        }

        // ── 5. SWAP TEXT ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.8) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            UIView.animate(withDuration: 0.15, animations: {
                self.highlightOverlay.backgroundColor = DesignTokens.Colors.success.withAlphaComponent(0.12)
                self.highlightOverlay.layer.borderColor = DesignTokens.Colors.success.withAlphaComponent(0.5).cgColor
            })

            UIView.animate(withDuration: 0.15, animations: {
                label.alpha = 0
            }, completion: { _ in
                label.attributedText = nil
                label.text = change.newText
                label.textColor = DesignTokens.Colors.success
                label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)

                // Resize the highlight overlay to match the new text's width.
                // Reset transforms, remeasure, set new frame + scale transform —
                // all while the label is faded out so the jump is invisible.
                self.highlightOverlay.transform = .identity
                label.transform = .identity
                self.layoutIfNeeded()

                let newLabelFrame = label.convert(label.bounds, to: self)
                self.highlightOverlay.frame = newLabelFrame.insetBy(dx: -inset, dy: -inset)

                let newShiftX = label.bounds.width * ((scale - 1) / 2)
                let newMagnifyTransform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: newShiftX / scale, y: 0)
                self.highlightOverlay.transform = newMagnifyTransform
                label.transform = newMagnifyTransform

                UIView.animate(withDuration: 0.15) {
                    label.alpha = 1
                }
            })
            Haptics.success()
        }

        // ── 6. SETTLE ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            UIView.animate(withDuration: 0.4) {
                self.highlightOverlay.alpha = 0
                self.highlightOverlay.transform = .identity
                label.transform = .identity
                self.thoughtBubble.alpha = 0
            }
            self.highlightOverlay.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
            self.highlightOverlay.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor
        }

        // Next step — if we just finished the final change, reset all labels
        // before looping back so the next cycle starts with the "old text" again.
        let isLastInCycle = currentStep == changes.count - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.2) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }
            if isLastInCycle {
                self.fadeDirectiveLabelsBackToOld()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                    self?.refineStep(step + 1, cycle: cycle)
                }
            } else {
                self.refineStep(step + 1, cycle: cycle)
            }
        }
    }

    /// Crossfade every directive label back to its original "old text" so the
    /// next trial-and-error cycle can play out from the beginning again.
    private func fadeDirectiveLabelsBackToOld() {
        for (i, label) in directiveLabels.enumerated() {
            let oldText = changes[i].oldText
            UIView.animate(withDuration: 0.25, animations: {
                label.alpha = 0
            }, completion: { _ in
                label.attributedText = nil
                label.text = oldText
                label.textColor = DesignTokens.Colors.textPrimary
                label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
                UIView.animate(withDuration: 0.25) {
                    label.alpha = 1
                }
            })
        }
    }

    private func showThought(_ text: String, color: UIColor) {
        UIView.animate(withDuration: 0.15) {
            self.thoughtBubble.alpha = 0
            self.thoughtBubble.transform = .identity
            self.underlineSweep.alpha = 0
        } completion: { _ in
            self.thoughtBubble.text = text
            self.thoughtBubble.textColor = color
            self.underlineSweep.backgroundColor = color

            self.thoughtBubble.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                self.thoughtBubble.alpha = 1
                self.thoughtBubble.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.thoughtBubble.transform = .identity
                }

                self.layoutIfNeeded()
                let textWidth = self.thoughtBubble.intrinsicContentSize.width
                let startX = self.thoughtBubble.frame.minX
                let sweepWidth: CGFloat = 20

                self.underlineSweep.frame = CGRect(
                    x: startX,
                    y: self.thoughtBubble.frame.maxY + 3,
                    width: sweepWidth,
                    height: 3
                )
                self.underlineSweep.alpha = 1

                let wordCount = max(text.split(separator: " ").count, 1)
                let sweepDuration = Double(wordCount) * 0.22

                UIView.animate(withDuration: sweepDuration, delay: 0.1, options: .curveEaseInOut) {
                    self.underlineSweep.frame = CGRect(
                        x: startX + max(textWidth - sweepWidth, 0),
                        y: self.thoughtBubble.frame.maxY + 3,
                        width: sweepWidth,
                        height: 3
                    )
                } completion: { _ in
                    UIView.animate(withDuration: 0.2) {
                        self.underlineSweep.alpha = 0
                    }
                }
            }
        }
    }

    func stopAnimations() {
        isStopped = true
        highlightOverlay.alpha = 0
        highlightOverlay.transform = .identity
        thoughtBubble.alpha = 0
        underlineSweep.alpha = 0
        underlineSweep.layer.removeAllAnimations()
        modeCard.layer.removeAllAnimations()
        for card in directiveCards { card.layer.removeAllAnimations() }
        for label in directiveLabels { label.transform = .identity }
    }

    // MARK: - Reset

    private func resetState() {
        highlightOverlay.alpha = 0
        highlightOverlay.transform = .identity
        thoughtBubble.alpha = 0
        underlineSweep.alpha = 0

        modeCard.alpha = 0
        directivesHeader.alpha = 0

        // Reset directive cards to original state
        for (i, card) in directiveCards.enumerated() {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 8)
            let label = directiveLabels[i]
            label.attributedText = nil
            label.text = changes[i].oldText
            label.textColor = DesignTokens.Colors.textPrimary
            label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            label.transform = .identity
        }
    }
}
