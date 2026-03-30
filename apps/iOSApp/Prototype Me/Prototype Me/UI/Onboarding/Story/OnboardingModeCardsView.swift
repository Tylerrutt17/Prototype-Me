import UIKit

/// Modes demo: Horizontal paging carousel of mode cards at the top.
/// Auto-swipes through modes, directives below crossfade to match the active mode.
final class OnboardingModeCardsView: UIView, StoryAnimatable {

    private let scrollView = UIScrollView()
    private var modeCards: [UIView] = []
    private let directivesStack = UIStackView()
    private var directiveGroups: [[UIView]] = []  // One group per mode
    private let modeColor = NoteKind.mode.color
    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0
    private var currentModeIndex = 0

    private struct ModeData {
        let name: String
        let directives: [(title: String, color: UIColor)]
    }

    private let modes: [ModeData] = [
        ModeData(name: "Deep Work", directives: [
            ("No distractions until noon", DesignTokens.Colors.accent),
            ("2-hour focus block", DesignTokens.Colors.accentSecondary),
            ("Phone on silent", DesignTokens.Colors.accentTertiary),
        ]),
        ModeData(name: "Recovery", directives: [
            ("No screens after 9pm", DesignTokens.Colors.success),
            ("Light stretching", DesignTokens.Colors.accentSecondary),
            ("Journal before bed", DesignTokens.Colors.accent),
        ]),
        ModeData(name: "Social", directives: [
            ("Be present — phone away", DesignTokens.Colors.warning),
            ("Ask good questions", DesignTokens.Colors.accentTertiary),
        ]),
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
        let cardWidth = bounds.width - DesignTokens.Spacing.xl * 2
        let cardHeight: CGFloat = 64
        let cardSpacing: CGFloat = DesignTokens.Spacing.md

        // Horizontal scroll for mode cards
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isPagingEnabled = false
        scrollView.isUserInteractionEnabled = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.md),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: cardHeight),
        ])

        // Build mode cards inside scroll view
        let inset = (bounds.width - cardWidth) / 2
        var xOffset = inset

        for (i, mode) in modes.enumerated() {
            let card = makeModeCard(title: mode.name, index: i)
            card.frame = CGRect(x: xOffset, y: 0, width: cardWidth, height: cardHeight)
            scrollView.addSubview(card)
            modeCards.append(card)
            xOffset += cardWidth + cardSpacing
        }

        scrollView.contentSize = CGSize(
            width: xOffset - cardSpacing + inset,
            height: cardHeight
        )

        // "Directives" section header
        let headerLabel = UILabel()
        headerLabel.text = "DIRECTIVES"
        headerLabel.font = DesignTokens.Typography.caption1
        headerLabel.textColor = DesignTokens.Colors.textTertiary
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerLabel)

        // Directives stack
        directivesStack.axis = .vertical
        directivesStack.spacing = DesignTokens.Spacing.sm
        directivesStack.alignment = .fill
        directivesStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(directivesStack)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),

            directivesStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            directivesStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            directivesStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        // Build directive card groups (one set per mode, all hidden initially)
        for mode in modes {
            var group: [UIView] = []
            for (title, color) in mode.directives {
                let card = makeDirectiveCard(title: title, color: color)
                card.alpha = 0
                group.append(card)
            }
            directiveGroups.append(group)
        }

        // Start everything hidden
        for card in modeCards { card.alpha = 0 }
        headerLabel.alpha = 0
        headerLabel.tag = 500
    }

    private func makeModeCard(title: String, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfaceSecondary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.layer.borderWidth = 1.5
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor
        card.tag = 100 + index

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let icon = UIImageView(image: UIImage(systemName: "bolt.fill", withConfiguration: iconConfig))
        icon.tintColor = DesignTokens.Colors.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.tag = 300

        let label = UILabel()
        label.text = title
        label.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig))
        check.tintColor = modeColor
        check.alpha = 0
        check.tag = 200

        let row = UIStackView(arrangedSubviews: [icon, label, UIView(), check])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        return card
    }

    private func makeDirectiveCard(title: String, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor

        let accentBar = UIView()
        accentBar.backgroundColor = color
        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentBar)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: "arrow.right.circle.fill", withConfiguration: iconConfig))
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary

        let row = UIStackView(arrangedSubviews: [icon, label, UIView()])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignTokens.Spacing.sm),
            accentBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: DesignTokens.Spacing.sm),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        return card
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            for card in modeCards { card.alpha = 1 }
            selectMode(at: 0, animated: false)
            showDirectives(for: 0, animated: false)
            return
        }

        cycleID += 1
        let currentCycle = cycleID

        // 1. Fade in all mode cards
        for card in modeCards {
            UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
                card.alpha = 1
            }
        }

        // Show directives header
        if let header = viewWithTag(500) {
            UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut) {
                header.alpha = 1
            }
        }

        // 2. Select first mode and show its directives
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.selectMode(at: 0, animated: true)
            self.showDirectives(for: 0, animated: true)

            // 3. Swipe to next mode after a pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                self.swipeToMode(1, cycle: currentCycle)
            }
        }
    }

    private func swipeToMode(_ index: Int, cycle: Int) {
        guard !isStopped, cycleID == cycle, index < modes.count else {
            // Done cycling — loop back after a pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == cycle else { return }
                self.swipeToMode(0, cycle: cycle)
            }
            return
        }

        // Deselect current
        deselectMode(at: currentModeIndex)

        // Fade out current directives
        hideDirectives(for: currentModeIndex)

        // Scroll to new mode card
        let cardWidth = bounds.width - DesignTokens.Spacing.xl * 2
        let cardSpacing = DesignTokens.Spacing.md
        let targetX = CGFloat(index) * (cardWidth + cardSpacing)

        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseInOut) {
            self.scrollView.contentOffset = CGPoint(x: targetX, y: 0)
        }

        // Select new mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == cycle else { return }
            self.selectMode(at: index, animated: true)
            self.showDirectives(for: index, animated: true)
            self.currentModeIndex = index

            // Next swipe
            let nextIndex = index + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == cycle else { return }
                self.swipeToMode(nextIndex >= self.modes.count ? 0 : nextIndex, cycle: cycle)
            }
        }
    }

    func stopAnimations() {
        isStopped = true
        for card in modeCards { card.layer.removeAllAnimations() }
        for group in directiveGroups { for card in group { card.layer.removeAllAnimations() } }
        resetState()
    }

    // MARK: - Mode Selection

    private func selectMode(at index: Int, animated: Bool) {
        guard index < modeCards.count else { return }
        let card = modeCards[index]
        let mc = modeColor
        currentModeIndex = index

        if animated {
            UIView.animate(withDuration: 0.3) {
                card.backgroundColor = mc.withAlphaComponent(0.08)
                card.layer.borderColor = mc.cgColor
                if let icon = card.viewWithTag(300) as? UIImageView { icon.tintColor = mc }
            }
            if let check = card.viewWithTag(200) as? UIImageView {
                UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut) {
                    check.alpha = 1
                }
            }
            Haptics.selection()
        } else {
            card.backgroundColor = mc.withAlphaComponent(0.08)
            card.layer.borderColor = mc.cgColor
            if let icon = card.viewWithTag(300) as? UIImageView { icon.tintColor = mc }
            if let check = card.viewWithTag(200) as? UIImageView { check.alpha = 1 }
        }
    }

    private func deselectMode(at index: Int) {
        guard index < modeCards.count else { return }
        let card = modeCards[index]
        UIView.animate(withDuration: 0.2) {
            card.backgroundColor = DesignTokens.Colors.surfaceSecondary
            card.layer.borderColor = DesignTokens.Colors.separator.cgColor
            if let icon = card.viewWithTag(300) as? UIImageView {
                icon.tintColor = DesignTokens.Colors.textTertiary
            }
            if let check = card.viewWithTag(200) as? UIImageView {
                check.alpha = 0
            }
        }
    }

    // MARK: - Directives

    private func showDirectives(for modeIndex: Int, animated: Bool) {
        guard modeIndex < directiveGroups.count else { return }
        let group = directiveGroups[modeIndex]

        // Add to stack
        for card in group {
            if card.superview == nil {
                directivesStack.addArrangedSubview(card)
            }
        }

        if animated {
            for (i, card) in group.enumerated() {
                UIView.animate(withDuration: 0.3, delay: Double(i) * 0.08, options: .curveEaseOut) {
                    card.alpha = 1
                }
            }
        } else {
            for card in group { card.alpha = 1 }
        }
    }

    private func hideDirectives(for modeIndex: Int) {
        guard modeIndex < directiveGroups.count else { return }
        let group = directiveGroups[modeIndex]

        UIView.animate(withDuration: 0.2) {
            for card in group { card.alpha = 0 }
        } completion: { _ in
            for card in group { card.removeFromSuperview() }
        }
    }

    // MARK: - Reset

    private func resetState() {
        currentModeIndex = 0
        scrollView.contentOffset = .zero

        for card in modeCards {
            card.layer.removeAllAnimations()
            UIView.performWithoutAnimation {
                card.alpha = 0
                card.backgroundColor = DesignTokens.Colors.surfaceSecondary
                card.layer.borderColor = DesignTokens.Colors.separator.cgColor
                if let check = card.viewWithTag(200) as? UIImageView { check.alpha = 0 }
                if let icon = card.viewWithTag(300) as? UIImageView {
                    icon.tintColor = DesignTokens.Colors.textTertiary
                }
            }
        }

        for group in directiveGroups {
            for card in group {
                card.layer.removeAllAnimations()
                UIView.performWithoutAnimation {
                    card.alpha = 0
                    card.removeFromSuperview()
                }
            }
        }

        if let header = viewWithTag(500) {
            UIView.performWithoutAnimation { header.alpha = 0 }
        }
    }
}
