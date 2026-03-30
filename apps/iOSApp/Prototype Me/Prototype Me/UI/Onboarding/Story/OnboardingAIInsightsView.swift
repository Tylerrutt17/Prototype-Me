import UIKit

/// Screen 6: Calendar with pre-filled days. Highlights a week → thinking animation →
/// weekly summary card slides in. Then highlights the full month → monthly summary.
final class OnboardingAIInsightsView: UIView, StoryAnimatable {

    // Calendar
    private let calendarCard = UIView()
    private var dayCells: [InsightDayCell] = []

    // Thinking dots
    private let thinkingDots: [UIView] = (0..<3).map { _ in
        let dot = UIView()
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        return dot
    }
    private let thinkingStack = UIStackView()

    // Summary cards
    private let weeklySummaryCard = UIView()
    private let monthlySummaryCard = UIView()

    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0

    // Same ratings as journal demo so it feels like a continuation
    private let mockRatings: [Int?] = [
        nil,  4,   3,   5,   6,   nil, nil,
        6,    7,   8,   7,   8,   9,   nil,
        8,    9,   5,   4,   6,   7,   8,
        7,    8,   9,   8,   9,   9,   nil,
        8,    9,   7,   nil, nil, nil, nil,
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    // MARK: - Build

    private func buildVisual() {
        // Calendar card
        calendarCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        calendarCard.layer.cornerRadius = DesignTokens.Radii.lg
        calendarCard.layer.borderWidth = 1
        calendarCard.layer.borderColor = DesignTokens.Colors.separator.cgColor
        calendarCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(calendarCard)

        let monthLabel = UILabel()
        monthLabel.text = "March 2026"
        monthLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        monthLabel.textColor = DesignTokens.Colors.textPrimary
        monthLabel.textAlignment = .center
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        calendarCard.addSubview(monthLabel)

        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        for day in ["M", "T", "W", "T", "F", "S", "S"] {
            let label = UILabel()
            label.text = day
            label.font = DesignTokens.Typography.caption2
            label.textColor = DesignTokens.Colors.textTertiary
            label.textAlignment = .center
            headerStack.addArrangedSubview(label)
        }
        calendarCard.addSubview(headerStack)

        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 3
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        calendarCard.addSubview(gridStack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            calendarCard.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.xs),
            calendarCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            calendarCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm),

            monthLabel.topAnchor.constraint(equalTo: calendarCard.topAnchor, constant: pad),
            monthLabel.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: pad),
            monthLabel.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -pad),

            headerStack.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            headerStack.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: pad),
            headerStack.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -pad),

            gridStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: DesignTokens.Spacing.xs),
            gridStack.leadingAnchor.constraint(equalTo: calendarCard.leadingAnchor, constant: pad),
            gridStack.trailingAnchor.constraint(equalTo: calendarCard.trailingAnchor, constant: -pad),
            gridStack.bottomAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: -pad),
        ])

        // Build grid (smaller cells to leave room for summary cards)
        var dayIndex = 0
        for _ in 0..<5 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 3
            for _ in 0..<7 {
                let rating = dayIndex < mockRatings.count ? mockRatings[dayIndex] : nil
                let dayNum = dayIndex + 1
                let cell = InsightDayCell(dayNumber: dayNum <= 31 ? dayNum : nil, rating: rating)
                rowStack.addArrangedSubview(cell)
                cell.heightAnchor.constraint(equalToConstant: 32).isActive = true
                if dayNum <= 31 { dayCells.append(cell) }
                dayIndex += 1
            }
            gridStack.addArrangedSubview(rowStack)
        }

        // Thinking dots (overlaid on calendar)
        let dotColors: [UIColor] = [
            DesignTokens.Colors.accent,
            DesignTokens.Colors.accentSecondary,
            DesignTokens.Colors.accentTertiary,
        ]
        thinkingStack.axis = .horizontal
        thinkingStack.spacing = DesignTokens.Spacing.sm
        thinkingStack.alignment = .center
        thinkingStack.translatesAutoresizingMaskIntoConstraints = false
        thinkingStack.alpha = 0
        addSubview(thinkingStack)

        for (i, dot) in thinkingDots.enumerated() {
            dot.backgroundColor = dotColors[i]
            thinkingStack.addArrangedSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
        }

        NSLayoutConstraint.activate([
            thinkingStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            thinkingStack.topAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: DesignTokens.Spacing.md),
        ])

        // Weekly summary card
        buildSummaryCard(
            weeklySummaryCard,
            icon: "lightbulb.fill",
            title: "WEEK 3 INSIGHTS",
            body: "Best days had morning exercise + early bedtime. Worst day: late screen time the night before."
        )
        weeklySummaryCard.translatesAutoresizingMaskIntoConstraints = false
        weeklySummaryCard.alpha = 0
        addSubview(weeklySummaryCard)

        // Monthly summary card
        buildSummaryCard(
            monthlySummaryCard,
            icon: "chart.line.text.clipboard",
            title: "MARCH SUMMARY",
            body: "Consistency up 40%. Your top pattern: days starting with exercise rated 2.5 points higher on average."
        )
        monthlySummaryCard.translatesAutoresizingMaskIntoConstraints = false
        monthlySummaryCard.alpha = 0
        addSubview(monthlySummaryCard)

        NSLayoutConstraint.activate([
            weeklySummaryCard.topAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: DesignTokens.Spacing.md),
            weeklySummaryCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            weeklySummaryCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm),

            monthlySummaryCard.topAnchor.constraint(equalTo: calendarCard.bottomAnchor, constant: DesignTokens.Spacing.md),
            monthlySummaryCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            monthlySummaryCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm),
        ])

        // Show all dots pre-filled immediately (continuation of journal slide)
        for cell in dayCells { cell.showRatingInstant() }

        calendarCard.alpha = 0
    }

    private func buildSummaryCard(_ card: UIView, icon: String, title: String, body: String) {
        card.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.2).cgColor

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.accent

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.xs

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [headerRow, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let p = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: p),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: p),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -p),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -p),
        ])
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            calendarCard.alpha = 1
            weeklySummaryCard.alpha = 1
            return
        }

        playOneCycle()
    }

    private func playOneCycle() {
        guard !isStopped else { return }
        cycleID += 1
        let currentCycle = cycleID

        // 1. Show calendar (pre-filled)
        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.calendarCard.alpha = 1
        }

        // 2. Highlight week 3 (days 14-20, indices 14...20)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.highlightDays(14...20)

            // 3. Show thinking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                self.showThinking()

                // 4. Hide thinking, show weekly summary
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                    self.hideThinking()
                    UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                        self.weeklySummaryCard.alpha = 1
                    }

                    // 5. Hold, then transition to month
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        guard let self, !self.isStopped, self.cycleID == currentCycle else { return }

                        // Fade out weekly, unhighlight week
                        UIView.animate(withDuration: 0.3) {
                            self.weeklySummaryCard.alpha = 0
                        }
                        self.unhighlightAll()

                        // 6. Highlight all days (full month)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                            self.highlightDays(0...30)

                            // 7. Thinking again
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                                self.showThinking()

                                // 8. Monthly summary
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                                    guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                                    self.hideThinking()
                                    UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                                        self.monthlySummaryCard.alpha = 1
                                    }

                                    // 9. Hold then loop
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                                        guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                                        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn) {
                                            self.calendarCard.alpha = 0
                                            self.monthlySummaryCard.alpha = 0
                                        } completion: { _ in
                                            guard !self.isStopped, self.cycleID == currentCycle else { return }
                                            self.resetState()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                                                self?.playOneCycle()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func highlightDays(_ range: ClosedRange<Int>) {
        for i in range where i < dayCells.count {
            dayCells[i].setHighlighted(true)
        }
    }

    private func unhighlightAll() {
        for cell in dayCells { cell.setHighlighted(false) }
    }

    private func showThinking() {
        thinkingStack.alpha = 1
        for (i, dot) in thinkingDots.enumerated() {
            UIView.animate(withDuration: 0.4, delay: 0.15 * Double(i), options: [.repeat, .autoreverse, .curveEaseInOut]) {
                dot.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            }
        }
    }

    private func hideThinking() {
        UIView.animate(withDuration: 0.2) { self.thinkingStack.alpha = 0 }
        for dot in thinkingDots {
            dot.layer.removeAllAnimations()
            dot.transform = .identity
        }
    }

    private func resetState() {
        UIView.performWithoutAnimation {
            calendarCard.alpha = 0
            weeklySummaryCard.alpha = 0
            monthlySummaryCard.alpha = 0
            thinkingStack.alpha = 0
            for dot in thinkingDots {
                dot.layer.removeAllAnimations()
                dot.transform = .identity
            }
            unhighlightAll()
        }
    }

    func stopAnimations() {
        isStopped = true
        calendarCard.layer.removeAllAnimations()
        weeklySummaryCard.layer.removeAllAnimations()
        monthlySummaryCard.layer.removeAllAnimations()
        for dot in thinkingDots { dot.layer.removeAllAnimations() }
        resetState()
    }
}

// MARK: - Insight Day Cell

private final class InsightDayCell: UIView {

    private let numberLabel = UILabel()
    private let dotView = UIView()
    private let highlightBorder = UIView()
    private let rating: Int?

    init(dayNumber: Int?, rating: Int?) {
        self.rating = rating
        super.init(frame: .zero)

        layer.cornerRadius = 4

        highlightBorder.layer.cornerRadius = 4
        highlightBorder.layer.borderWidth = 1.5
        highlightBorder.layer.borderColor = DesignTokens.Colors.accent.cgColor
        highlightBorder.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.1)
        highlightBorder.alpha = 0
        highlightBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(highlightBorder)

        numberLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        numberLabel.textColor = dayNumber != nil ? DesignTokens.Colors.textSecondary : .clear
        numberLabel.textAlignment = .center
        numberLabel.text = dayNumber.map { "\($0)" }
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(numberLabel)

        dotView.layer.cornerRadius = 3
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.alpha = 0
        addSubview(dotView)

        if let rating {
            dotView.backgroundColor = Self.ratingColor(for: rating)
        }

        NSLayoutConstraint.activate([
            highlightBorder.topAnchor.constraint(equalTo: topAnchor),
            highlightBorder.bottomAnchor.constraint(equalTo: bottomAnchor),
            highlightBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            highlightBorder.trailingAnchor.constraint(equalTo: trailingAnchor),

            numberLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            numberLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),

            dotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotView.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 1),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showRatingInstant() {
        guard rating != nil else { return }
        dotView.alpha = 1
        backgroundColor = dotView.backgroundColor?.withAlphaComponent(0.08)
    }

    func setHighlighted(_ highlighted: Bool) {
        UIView.animate(withDuration: 0.2) {
            self.highlightBorder.alpha = highlighted ? 1 : 0
        }
    }

    static func ratingColor(for rating: Int) -> UIColor {
        switch rating {
        case 1...3:  return DesignTokens.Colors.destructive
        case 4...5:  return DesignTokens.Colors.warning
        case 6...7:  return UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0)
        default:     return DesignTokens.Colors.success
        }
    }
}
