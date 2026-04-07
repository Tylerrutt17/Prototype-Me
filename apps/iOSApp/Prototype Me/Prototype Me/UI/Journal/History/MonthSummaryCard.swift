import UIKit

/// Card shown in the History list for a single month. Combines local stats
/// (entry count, avg rating, top tags) with optional AI-generated insights.
final class MonthSummaryCard: UICollectionViewCell {

    // Header
    private let monthLabel = UILabel()
    private let avgRatingPill = PaddedLabel()
    private let subtitleLabel = UILabel()

    // Non-AI stats (shown when no AI review)
    private let bestLabel = UILabel()
    private let worstLabel = UILabel()
    private let statsRow = UIStackView()

    // AI: themes (chips row)
    private let aiBadge = PaddedLabel()
    private let themesChipStack = WrappingChipStack()

    // Mechanical: directives the user scheduled but skipped
    private let missedSection = InsightSection()

    // AI: directive insights
    private let focusSection = InsightSection()
    private let winsSection = InsightSection()
    private let gapsSection = InsightSection()

    // AI: suggestion
    private let aiSuggestionContainer = UIView()
    private let aiSuggestionLabel = UILabel()

    private var mainStack: UIStackView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        // ── Header ──
        monthLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        monthLabel.textColor = DesignTokens.Colors.textPrimary

        avgRatingPill.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold)
        avgRatingPill.textColor = DesignTokens.Colors.accent
        avgRatingPill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        avgRatingPill.layer.cornerRadius = 9
        avgRatingPill.clipsToBounds = true
        avgRatingPill.textAlignment = .center
        avgRatingPill.contentInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        avgRatingPill.setContentHuggingPriority(.required, for: .horizontal)
        avgRatingPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [monthLabel, UIView(), avgRatingPill])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = DesignTokens.Spacing.sm

        let headerStack = UIStackView(arrangedSubviews: [topRow, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 3

        // ── Non-AI stats ──
        bestLabel.font = DesignTokens.Typography.caption1
        bestLabel.textColor = DesignTokens.Colors.success
        bestLabel.numberOfLines = 0
        worstLabel.font = DesignTokens.Typography.caption1
        worstLabel.textColor = DesignTokens.Colors.warning
        worstLabel.numberOfLines = 0

        statsRow.addArrangedSubview(bestLabel)
        statsRow.addArrangedSubview(worstLabel)
        statsRow.axis = .vertical
        statsRow.spacing = 3

        // ── AI badge ──
        aiBadge.text = "PROTOTYPE REVIEW"
        aiBadge.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        aiBadge.textColor = DesignTokens.Colors.accent
        aiBadge.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        aiBadge.layer.cornerRadius = 6
        aiBadge.clipsToBounds = true
        aiBadge.contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        aiBadge.setContentHuggingPriority(.required, for: .horizontal)
        let aiBadgeRow = UIStackView(arrangedSubviews: [aiBadge, UIView()])
        aiBadgeRow.axis = .horizontal
        aiBadgeRow.alignment = .leading

        // ── AI: themes chips ──
        themesChipStack.translatesAutoresizingMaskIntoConstraints = false

        // ── Mechanical: missed checklists ──
        missedSection.configureLabel("MISSED", color: DesignTokens.Colors.destructive)

        // ── AI: directive sections ──
        focusSection.configureLabel("FOCUS AREAS", color: DesignTokens.Colors.warning)
        winsSection.configureLabel("WORKING", color: DesignTokens.Colors.success)
        gapsSection.configureLabel("CONSIDER ADDING", color: DesignTokens.Colors.accent)

        // ── AI: suggestion box ──
        aiSuggestionContainer.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        aiSuggestionContainer.layer.cornerRadius = DesignTokens.Radii.md
        aiSuggestionLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiSuggestionLabel.textColor = DesignTokens.Colors.accent
        aiSuggestionLabel.numberOfLines = 0
        aiSuggestionLabel.translatesAutoresizingMaskIntoConstraints = false
        aiSuggestionContainer.addSubview(aiSuggestionLabel)
        let sp: CGFloat = 10
        NSLayoutConstraint.activate([
            aiSuggestionLabel.topAnchor.constraint(equalTo: aiSuggestionContainer.topAnchor, constant: sp),
            aiSuggestionLabel.bottomAnchor.constraint(equalTo: aiSuggestionContainer.bottomAnchor, constant: -sp),
            aiSuggestionLabel.leadingAnchor.constraint(equalTo: aiSuggestionContainer.leadingAnchor, constant: sp + 2),
            aiSuggestionLabel.trailingAnchor.constraint(equalTo: aiSuggestionContainer.trailingAnchor, constant: -sp - 2),
        ])

        // ── Main stack ──
        mainStack = UIStackView(arrangedSubviews: [
            headerStack, statsRow, missedSection, aiBadgeRow, themesChipStack,
            focusSection, winsSection, gapsSection, aiSuggestionContainer,
        ])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: subtitleLabel)
        mainStack.setCustomSpacing(DesignTokens.Spacing.md, after: statsRow)
        mainStack.setCustomSpacing(DesignTokens.Spacing.sm, after: aiBadgeRow)

        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with summary: HistoryMonthSummary, review: PeriodicReview?) {
        monthLabel.text = HistoryDateFormat.monthTitle(summary.month)

        if let avg = summary.averageRating {
            avgRatingPill.text = "\(String(format: "%.1f", avg)) avg"
            avgRatingPill.isHidden = false
        } else {
            avgRatingPill.isHidden = true
        }

        var subtitleParts: [String] = ["\(summary.entryCount) entr\(summary.entryCount == 1 ? "y" : "ies")"]
        if !summary.topTags.isEmpty {
            subtitleParts.append(summary.topTags.joined(separator: ", "))
        }
        subtitleLabel.text = subtitleParts.joined(separator: " • ")

        let hasReview = review != nil

        // Non-AI stats (only when no review)
        statsRow.isHidden = hasReview
        if !hasReview {
            if let best = summary.bestDay {
                bestLabel.text = "↑ Best: \(HistoryDateFormat.shortDate(best.date)) · \(best.rating ?? 0)/10"
                bestLabel.isHidden = false
            } else {
                bestLabel.isHidden = true
            }
            if let worst = summary.worstDay, worst.id != summary.bestDay?.id {
                worstLabel.text = "↓ Lowest: \(HistoryDateFormat.shortDate(worst.date)) · \(worst.rating ?? 0)/10"
                worstLabel.isHidden = false
            } else {
                worstLabel.isHidden = true
            }
            statsRow.isHidden = bestLabel.isHidden && worstLabel.isHidden
        }

        // AI content — hide everything by default
        // mainStack order: header(0), statsRow(1), missed(2), aiBadgeRow(3), themes(4), ...
        missedSection.isHidden = true
        let badgeRow = mainStack.arrangedSubviews[3]
        badgeRow.isHidden = !hasReview
        themesChipStack.isHidden = true
        focusSection.isHidden = true
        winsSection.isHidden = true
        gapsSection.isHidden = true
        aiSuggestionContainer.isHidden = true

        guard let review else { return }

        // Missed (mechanical — show even without AI insights)
        if !review.missedScheduled.isEmpty {
            missedSection.setItems(review.missedScheduled.map { item in
                let plural = item.missedCount == 1 ? "day" : "days"
                return (item.directiveTitle, "\(item.missedCount) \(plural) missed")
            })
            missedSection.isHidden = false
        }

        // Themes
        if !review.themes.isEmpty {
            themesChipStack.setThemes(review.themes)
            themesChipStack.isHidden = false
        }

        // Focus
        if !review.directiveFocus.isEmpty {
            focusSection.setItems(review.directiveFocus.map { ($0.directiveTitle, $0.reason) })
            focusSection.isHidden = false
        }

        // Wins
        if !review.directiveWins.isEmpty {
            winsSection.setItems(review.directiveWins.map { ($0.directiveTitle, $0.evidence) })
            winsSection.isHidden = false
        }

        // Gaps
        if !review.directiveGaps.isEmpty {
            gapsSection.setItems(review.directiveGaps.map { ($0.suggestedTitle, "For: \($0.theme)") })
            gapsSection.isHidden = false
        }

        // Suggestion
        if let suggestion = review.suggestion, !suggestion.isEmpty {
            aiSuggestionLabel.text = "💡 \(suggestion)"
            aiSuggestionContainer.isHidden = false
        }
    }
}

// MARK: - InsightSection

/// A titled section showing a list of (title, detail) items.
final class InsightSection: UIView {
    private let headerLabel = UILabel()
    private let itemsStack = UIStackView()
    private var accentColor: UIColor = .systemGray

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupView() }

    private func setupView() {
        headerLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)

        itemsStack.axis = .vertical
        itemsStack.spacing = DesignTokens.Spacing.xs

        let outerStack = UIStackView(arrangedSubviews: [headerLabel, itemsStack])
        outerStack.axis = .vertical
        outerStack.spacing = DesignTokens.Spacing.xs
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    func configureLabel(_ text: String, color: UIColor) {
        headerLabel.text = text
        headerLabel.textColor = color
        accentColor = color
    }

    func setItems(_ items: [(String, String)]) {
        itemsStack.arrangedSubviews.forEach { itemsStack.removeArrangedSubview($0); $0.removeFromSuperview() }
        for (title, detail) in items {
            itemsStack.addArrangedSubview(makeItem(title: title, detail: detail))
        }
    }

    private func makeItem(title: String, detail: String) -> UIView {
        let card = UIView()
        card.backgroundColor = accentColor.withAlphaComponent(0.08)
        card.layer.cornerRadius = DesignTokens.Radii.sm

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = DesignTokens.Typography.caption1
        detailLabel.textColor = DesignTokens.Colors.textSecondary
        detailLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let h = 10.0, v = 8.0
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: v),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -v),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: h),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -h),
        ])
        return card
    }
}

// MARK: - WrappingChipStack

/// Horizontally wrapping chip layout for themes.
final class WrappingChipStack: UIView {
    private var chips: [UIView] = []

    func setThemes(_ themes: [PeriodicReview.Theme]) {
        chips.forEach { $0.removeFromSuperview() }
        chips = []
        for theme in themes {
            let chip = makeChip(for: theme)
            addSubview(chip)
            chips.append(chip)
        }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    private func makeChip(for theme: PeriodicReview.Theme) -> UIView {
        let container = UIView()
        container.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
        container.layer.cornerRadius = 10

        let label = UILabel()
        label.text = theme.mentions > 1 ? "\(theme.name) · \(theme.mentions)" : theme.name
        label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        label.textColor = DesignTokens.Colors.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])
        return container
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutChips(in: bounds.width)
    }

    override var intrinsicContentSize: CGSize {
        let targetWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width - 64
        let height = layoutChips(in: targetWidth, measure: true)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    @discardableResult
    private func layoutChips(in width: CGFloat, measure: Bool = false) -> CGFloat {
        let spacing: CGFloat = 6
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for chip in chips {
            let size = chip.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            if !measure { chip.frame = CGRect(x: x, y: y, width: size.width, height: size.height) }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return y + rowHeight
    }
}

// MARK: - PaddedLabel

/// UILabel with contentInsets for use as pills/badges.
final class PaddedLabel: UILabel {
    var contentInsets: UIEdgeInsets = .zero { didSet { invalidateIntrinsicContentSize() } }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + contentInsets.left + contentInsets.right,
                      height: base.height + contentInsets.top + contentInsets.bottom)
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let inner = bounds.inset(by: contentInsets)
        let rect = super.textRect(forBounds: inner, limitedToNumberOfLines: numberOfLines)
        return CGRect(
            x: rect.origin.x - contentInsets.left,
            y: rect.origin.y - contentInsets.top,
            width: rect.width + contentInsets.left + contentInsets.right,
            height: rect.height + contentInsets.top + contentInsets.bottom
        )
    }
}
