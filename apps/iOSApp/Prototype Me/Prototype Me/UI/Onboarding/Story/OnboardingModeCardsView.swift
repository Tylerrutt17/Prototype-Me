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

    // Swipe hint hand
    private let swipeHintView = UIImageView()
    private var swipeHintDismissed = false

    // User interaction: when the user swipes the carousel, pause auto-cycling
    // for `inactivityTimeout` seconds of no interaction, then resume.
    private var isUserControlled = false
    private var resumeTimer: Timer?
    private let inactivityTimeout: TimeInterval = 7.0

    private struct ModeData {
        let name: String
        let directives: [String]
    }

    private let modes: [ModeData] = [
        ModeData(name: "Winding Down", directives: [
            "No screens after 9pm",
            "Read 10 min before bed",
            "Lights dim by 10",
        ]),
        ModeData(name: "Computer Work", directives: [
            "Eye break every 30 min",
            "Stand up each hour",
            "Walk during lunch",
        ]),
        ModeData(name: "Deep Work", directives: [
            "No distractions until noon",
            "2-hour focus block",
            "Phone on silent",
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
        scrollView.isPagingEnabled = false // custom paging — card stride != bounds.width
        scrollView.isUserInteractionEnabled = true
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
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
            for title in mode.directives {
                let card = makeDirectiveCard(title: title)
                card.alpha = 0
                group.append(card)
            }
            directiveGroups.append(group)
        }

        // Start everything hidden
        for card in modeCards { card.alpha = 0 }
        headerLabel.alpha = 0
        headerLabel.tag = 500

        // Swipe hint hand
        buildSwipeHint()
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

    private func makeDirectiveCard(title: String) -> UIView {
        // Matches DirectiveCell styling: 4pt color bar on the left, no dot.
        // Color is intentionally neutral here so the focus stays on the titles —
        // the per-directive colors were noise in this preview context.
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor
        card.clipsToBounds = true

        let colorBar = UIView()
        colorBar.backgroundColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.5)
        colorBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(colorBar)

        let label = UILabel()
        label.text = title
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

        NSLayoutConstraint.activate([
            colorBar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: card.topAnchor),
            colorBar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 4),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignTokens.Spacing.md),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignTokens.Spacing.md),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return card
    }

    // MARK: - Swipe Hint

    private func buildSwipeHint() {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .light)
        swipeHintView.image = UIImage(systemName: "hand.draw.fill", withConfiguration: config)
        swipeHintView.tintColor = DesignTokens.Colors.textSecondary.withAlphaComponent(0.55)
        swipeHintView.contentMode = .scaleAspectFit
        swipeHintView.alpha = 0
        swipeHintView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(swipeHintView)

        NSLayoutConstraint.activate([
            swipeHintView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: DesignTokens.Spacing.sm),
            swipeHintView.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    private func showSwipeHint() {
        guard !swipeHintDismissed, !UIAccessibility.isReduceMotionEnabled else { return }

        UIView.animate(withDuration: 0.4, delay: 1.2, options: .curveEaseOut) {
            self.swipeHintView.alpha = 1
        } completion: { _ in
            guard !self.swipeHintDismissed else { return }
            self.animateSwipeHint()
        }
    }

    private func animateSwipeHint() {
        guard !swipeHintDismissed else { return }

        // Swipe left motion, repeating
        let startX: CGFloat = 12
        swipeHintView.transform = CGAffineTransform(translationX: startX, y: 0)

        UIView.animate(
            withDuration: 0.8,
            delay: 0.3,
            options: [.curveEaseInOut]
        ) {
            self.swipeHintView.transform = CGAffineTransform(translationX: -20, y: 0)
        } completion: { [weak self] finished in
            guard let self, finished, !self.swipeHintDismissed else { return }
            // Reset and repeat
            UIView.animate(withDuration: 0.3, delay: 0.6, options: .curveEaseOut) {
                self.swipeHintView.transform = CGAffineTransform(translationX: startX, y: 0)
            } completion: { [weak self] _ in
                self?.animateSwipeHint()
            }
        }
    }

    private func dismissSwipeHint() {
        guard !swipeHintDismissed else { return }
        swipeHintDismissed = true
        swipeHintView.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.swipeHintView.alpha = 0
            self.swipeHintView.transform = CGAffineTransform(translationX: -10, y: 0).scaledBy(x: 0.8, y: 0.8)
        }
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
            self.showSwipeHint()

            // 3. Swipe to next mode after a pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                self.swipeToMode(1, cycle: currentCycle)
            }
        }
    }

    private func swipeToMode(_ index: Int, cycle: Int) {
        guard !isStopped, !isUserControlled, cycleID == cycle, index < modes.count else {
            // Done cycling — loop back after a pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard let self, !self.isStopped, !self.isUserControlled, self.cycleID == cycle else { return }
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
            guard let self, !self.isStopped, !self.isUserControlled, self.cycleID == cycle else { return }
            self.selectMode(at: index, animated: true)
            self.showDirectives(for: index, animated: true)
            self.currentModeIndex = index

            // Next swipe
            let nextIndex = index + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard let self, !self.isStopped, !self.isUserControlled, self.cycleID == cycle else { return }
                self.swipeToMode(nextIndex >= self.modes.count ? 0 : nextIndex, cycle: cycle)
            }
        }
    }

    func stopAnimations() {
        isStopped = true
        resumeTimer?.invalidate()
        resumeTimer = nil
        isUserControlled = false
        swipeHintView.layer.removeAllAnimations()
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
        swipeHintDismissed = false
        swipeHintView.alpha = 0
        swipeHintView.transform = .identity

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

    // MARK: - User Interaction

    private var cardStride: CGFloat {
        let cardWidth = bounds.width - DesignTokens.Spacing.xl * 2
        return cardWidth + DesignTokens.Spacing.md
    }

    private func pauseForUserControl() {
        isUserControlled = true
        cycleID += 1 // invalidate any pending auto callbacks
        resumeTimer?.invalidate()
        resumeTimer = nil
    }

    private func scheduleAutoResume() {
        resumeTimer?.invalidate()
        resumeTimer = Timer.scheduledTimer(withTimeInterval: inactivityTimeout, repeats: false) { [weak self] _ in
            self?.resumeAutoCycle()
        }
    }

    private func resumeAutoCycle() {
        guard !isStopped else { return }
        isUserControlled = false
        cycleID += 1
        let next = (currentModeIndex + 1) % modes.count
        swipeToMode(next, cycle: cycleID)
    }

    /// Apply a mode change triggered by the user swiping (no scroll animation —
    /// the scrollView has already moved under the user's finger).
    private func applyUserModeChange(to index: Int) {
        guard index != currentModeIndex, index < modes.count else { return }
        deselectMode(at: currentModeIndex)
        // Remove old directives immediately (no fade-out delay). Otherwise the
        // stack view briefly holds both sets, pushing the new cards down until
        // the old ones are removed — which reads as a jolt.
        removeDirectivesImmediately(for: currentModeIndex)
        currentModeIndex = index
        selectMode(at: index, animated: true)
        showDirectives(for: index, animated: true)
    }

    private func removeDirectivesImmediately(for modeIndex: Int) {
        guard modeIndex < directiveGroups.count else { return }
        for card in directiveGroups[modeIndex] {
            card.layer.removeAllAnimations()
            card.alpha = 0
            card.removeFromSuperview()
        }
    }
}

// MARK: - UIScrollViewDelegate

extension OnboardingModeCardsView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dismissSwipeHint()
        pauseForUserControl()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // Snap to the nearest card, biased by swipe velocity so a flick still
        // pages forward.
        let stride = cardStride
        guard stride > 0 else { return }
        let projected = targetContentOffset.pointee.x + velocity.x * 60
        let maxIndex = CGFloat(modes.count - 1)
        let snapped = max(0, min(maxIndex, round(projected / stride)))
        targetContentOffset.pointee = CGPoint(x: snapped * stride, y: 0)
        applyUserModeChange(to: Int(snapped))
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { scheduleAutoResume() }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scheduleAutoResume()
    }
}
