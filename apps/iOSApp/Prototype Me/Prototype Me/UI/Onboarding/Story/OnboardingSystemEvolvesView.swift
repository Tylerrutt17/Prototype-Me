import UIKit

/// Shows two Mode notes with directives inside.
/// Each directive gets highlighted, scales up like a magnifying glass,
/// shows a thought bubble ("that didn't work", "let's try this"), then
/// strikethrough + replacement. Making the evolution impossible to miss.
final class OnboardingSystemEvolvesView: UIView, StoryAnimatable {

    private let headerLabel = UILabel()
    private let modeStack = UIStackView()
    private var mode1Directives: [UILabel] = []
    private var mode2Directives: [UILabel] = []
    private let highlightOverlay = UIView()
    private let thoughtBubble = UILabel()
    private let underlineSweep = UIView()
    private var isStopped = false
    private var cycleID = 0

    var prefersFullWidth: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Build

    private func buildLayout() {
        // "An example over time" header
        headerLabel.text = "AN EXAMPLE OVER TIME"
        headerLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold)
        headerLabel.textColor = DesignTokens.Colors.textTertiary
        headerLabel.textAlignment = .center
        headerLabel.alpha = 0
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerLabel)

        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.md),
            headerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            mainStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        // Modes stack (vertical — each card full-width so the animation reads bigger)
        modeStack.axis = .vertical
        modeStack.spacing = DesignTokens.Spacing.sm
        modeStack.distribution = .fill
        mainStack.addArrangedSubview(modeStack)

        let modeColor = NoteKind.mode.color

        let mode1 = UIView()
        buildNoteCard(
            mode1,
            icon: "bolt.fill",
            title: "Computer Work - MODE",
            note: "Eyes burning, back sore by afternoon",
            color: modeColor,
            directives: ["Rest my eyes more", "Stretch when I can"],
            directiveLabels: &mode1Directives
        )
        modeStack.addArrangedSubview(mode1)

        let mode2 = UIView()
        buildNoteCard(
            mode2,
            icon: "bolt.fill",
            title: "Winding Down - MODE",
            note: "Can't switch off, scrolling till late",
            color: modeColor,
            directives: ["Try to relax", "Put my phone down"],
            directiveLabels: &mode2Directives
        )
        modeStack.addArrangedSubview(mode2)

        // Highlight overlay
        highlightOverlay.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        highlightOverlay.layer.cornerRadius = DesignTokens.Radii.sm
        highlightOverlay.layer.borderWidth = 1.5
        highlightOverlay.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor
        highlightOverlay.alpha = 0
        addSubview(highlightOverlay)

        // Thought bubble — shows commentary below the cards
        thoughtBubble.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        thoughtBubble.textColor = DesignTokens.Colors.textSecondary
        thoughtBubble.textAlignment = .center
        thoughtBubble.alpha = 0
        thoughtBubble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thoughtBubble)

        // Underline sweep — small bar that slides under the thought text (manual frame, no constraints)
        underlineSweep.layer.cornerRadius = 1.5
        underlineSweep.alpha = 0
        addSubview(underlineSweep)

        NSLayoutConstraint.activate([
            thoughtBubble.centerXAnchor.constraint(equalTo: centerXAnchor),
            thoughtBubble.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: DesignTokens.Spacing.lg),
        ])

        // Start hidden
        mode1.alpha = 0
        mode1.transform = CGAffineTransform(translationX: 0, y: 10)
        mode2.alpha = 0
        mode2.transform = CGAffineTransform(translationX: 0, y: 10)
    }

    private func buildNoteCard(
        _ card: UIView,
        icon: String,
        title: String,
        note: String? = nil,
        color: UIColor,
        directives: [String],
        directiveLabels: inout [UILabel]
    ) {
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // Accent bar
        let bar = UIView()
        bar.backgroundColor = color
        bar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bar)

        // Header
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold)
        titleLabel.textColor = color
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView()])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.xs
        headerRow.alignment = .center

        // Collect sections for the card stack
        var cardSubviews: [UIView] = [headerRow]

        // Optional note — labels the issues this mode tries to fix, so the directives' job is obvious
        if let note = note {
            let noteLabel = UILabel()
            noteLabel.text = "Reason — \(note)"
            noteLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .regular)
            noteLabel.textColor = DesignTokens.Colors.textTertiary
            noteLabel.numberOfLines = 0
            cardSubviews.append(noteLabel)
        }

        // Directives
        let dirStack = UIStackView()
        dirStack.axis = .vertical
        dirStack.spacing = 4

        for text in directives {
            let label = UILabel()
            label.text = text
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
            label.textColor = DesignTokens.Colors.textPrimary
            dirStack.addArrangedSubview(label)
            directiveLabels.append(label)
        }
        cardSubviews.append(dirStack)

        let cardStack = UIStackView(arrangedSubviews: cardSubviews)
        cardStack.axis = .vertical
        cardStack.spacing = DesignTokens.Spacing.sm
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: card.topAnchor),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 3),

            cardStack.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: pad),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
        ])
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        cycleID += 1
        let currentCycle = cycleID

        guard !UIAccessibility.isReduceMotionEnabled else {
            headerLabel.alpha = 1
            for v in modeStack.arrangedSubviews { v.alpha = 1; v.transform = .identity }
            return
        }

        // Header fades in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.headerLabel.alpha = 1
        }

        // Cards appear
        for (i, v) in modeStack.arrangedSubviews.enumerated() {
            UIView.animate(withDuration: 0.5, delay: 0.15 + Double(i) * 0.12, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                v.alpha = 1
                v.transform = .identity
            }
        }

        // Start evolving
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.evolveStep(0, cycle: currentCycle)
        }
    }

    private func evolveStep(_ step: Int, cycle: Int) {
        guard !isStopped, cycleID == cycle else { return }

        let changes: [(labels: [UILabel], index: Int, newText: String, strikeComment: String, replaceComment: String)] = [
            (mode1Directives, 0, "20-20-20 every 30 min",
             "\"rest my eyes more\" — too vague to actually do", "20-20-20 is specific and timed"),
            (mode2Directives, 0, "Read 10 pages before bed",
             "\"try to relax\" — never knew what that meant", "a book actually settles my brain"),
            (mode1Directives, 1, "Stand up and stretch every 45 min",
             "\"stretch when I can\" — only when I remembered", "every 45 min, no guessing"),
            (mode2Directives, 1, "Phone in another room after 9pm",
             "\"put my phone down\" — picked it right back up", "phone out of reach, no choice"),
        ]

        let currentStep = step % changes.count
        let change = changes[currentStep]

        guard change.index < change.labels.count else { return }
        let label = change.labels[change.index]
        let oldText = label.attributedText?.string ?? label.text ?? ""

        // ── 1. MAGNIFY — highlight box + scale label up ──
        self.layoutIfNeeded()
        let labelFrame = label.convert(label.bounds, to: self)
        let inset: CGFloat = 6
        highlightOverlay.frame = labelFrame.insetBy(dx: -inset, dy: -inset)
        highlightOverlay.layer.cornerRadius = DesignTokens.Radii.sm

        let scale: CGFloat = 1.4
        let shiftX = label.bounds.width * ((scale - 1) / 2)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
            self.highlightOverlay.alpha = 1
            label.transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: shiftX / scale, y: 0)
        }

        // ── 2. PAUSE — let them see what's being focused on ──

        // ── 3. THOUGHT (strike) — flash thought bubble with why ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            self.showThought(change.strikeComment, color: DesignTokens.Colors.destructive.withAlphaComponent(0.8))
        }

        // ── 4. FLASH LABEL — pulse the label to draw eyes back up ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            // Quick flash pulse on the highlight
            UIView.animate(withDuration: 0.15, animations: {
                self.highlightOverlay.backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.15)
                self.highlightOverlay.layer.borderColor = DesignTokens.Colors.destructive.withAlphaComponent(0.5).cgColor
            }, completion: { _ in
                // Apply strikethrough while attention is on it
                UIView.animate(withDuration: 0.15, animations: {
                    label.alpha = 0
                }, completion: { _ in
                    label.attributedText = NSAttributedString(string: oldText, attributes: [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: DesignTokens.Colors.destructive,
                        .foregroundColor: DesignTokens.Colors.destructive.withAlphaComponent(0.5),
                        .font: DesignTokens.Typography.rounded(style: .caption2, weight: .medium),
                    ])
                    UIView.animate(withDuration: 0.15) {
                        label.alpha = 1
                    }
                })
            })
            Haptics.light()
        }

        // ── 5. THOUGHT (replace) — flash new thought with what's better ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            self.showThought(change.replaceComment, color: DesignTokens.Colors.success)
        }

        // ── 6. FLASH + REPLACE — pulse label again, swap text ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.5) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            // Flash highlight to green
            UIView.animate(withDuration: 0.15, animations: {
                self.highlightOverlay.backgroundColor = DesignTokens.Colors.success.withAlphaComponent(0.12)
                self.highlightOverlay.layer.borderColor = DesignTokens.Colors.success.withAlphaComponent(0.5).cgColor
            })

            // Swap text
            UIView.animate(withDuration: 0.15, animations: {
                label.alpha = 0
            }, completion: { _ in
                label.attributedText = nil
                label.text = change.newText
                label.textColor = DesignTokens.Colors.success
                label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
                UIView.animate(withDuration: 0.15) {
                    label.alpha = 1
                }
            })
            Haptics.success()
        }

        // ── 7. SETTLE — shrink back down, clear everything ──
        DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }

            UIView.animate(withDuration: 0.5) {
                self.highlightOverlay.alpha = 0
                label.transform = .identity
                self.thoughtBubble.alpha = 0
            }
            // Reset highlight colors for next use
            self.highlightOverlay.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
            self.highlightOverlay.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor

            UIView.animate(withDuration: 0.3) {
                label.textColor = DesignTokens.Colors.textPrimary
            }
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        }

        // Next step
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) { [weak self] in
            self?.evolveStep(step + 1, cycle: cycle)
        }
    }

    private func showThought(_ text: String, color: UIColor = DesignTokens.Colors.textSecondary) {
        // Fade out old thought + sweep
        UIView.animate(withDuration: 0.15) {
            self.thoughtBubble.alpha = 0
            self.thoughtBubble.transform = .identity
            self.underlineSweep.alpha = 0
        } completion: { _ in
            let displayText = "\" \(text) \""
            self.thoughtBubble.text = displayText
            self.thoughtBubble.textColor = color
            self.underlineSweep.backgroundColor = color

            // Pop in thought
            self.thoughtBubble.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                self.thoughtBubble.alpha = 1
                self.thoughtBubble.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.thoughtBubble.transform = .identity
                }

                // Start underline sweep after text settles
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

                // Calculate duration based on word count (~0.25s per word)
                let wordCount = max(text.split(separator: " ").count, 1)
                let sweepDuration = Double(wordCount) * 0.25

                UIView.animate(withDuration: sweepDuration, delay: 0.1, options: .curveEaseInOut) {
                    self.underlineSweep.frame = CGRect(
                        x: startX + textWidth - sweepWidth,
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
        thoughtBubble.alpha = 0
        underlineSweep.alpha = 0
        underlineSweep.layer.removeAllAnimations()
        for v in modeStack.arrangedSubviews { v.layer.removeAllAnimations() }
        // Reset any scaled labels
        for label in mode1Directives + mode2Directives {
            label.transform = .identity
        }
    }
}
