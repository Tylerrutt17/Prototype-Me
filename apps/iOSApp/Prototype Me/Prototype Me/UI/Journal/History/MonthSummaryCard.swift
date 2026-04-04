import UIKit

/// Card shown in the History list for a single month. Combines local stats
/// (entry count, avg rating, top tags) with optional AI-generated review content.
final class MonthSummaryCard: UICollectionViewCell {

    // Header
    private let monthLabel = UILabel()
    private let avgRatingPill = PaddedLabel()
    private let subtitleLabel = UILabel()

    // Non-AI stats (shown when no AI review)
    private let bestLabel = UILabel()
    private let worstLabel = UILabel()
    private let statsRow = UIStackView()

    // AI review content
    private let aiBadge = PaddedLabel()
    private let aiSummaryLabel = UILabel()
    private let aiDayStack = UIStackView()
    private let aiBestCard = DayNoteCard()
    private let aiWorstCard = DayNoteCard()
    private let aiSuggestionContainer = UIView()
    private let aiSuggestionLabel = UILabel()
    private let aiDirectiveLabel = UILabel()

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
        aiBadge.text = "AI REVIEW"
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

        // ── AI: summary ──
        aiSummaryLabel.font = DesignTokens.Typography.subheadline
        aiSummaryLabel.textColor = DesignTokens.Colors.textPrimary
        aiSummaryLabel.numberOfLines = 0

        // ── AI: day cards (inline, smaller than detail view) ──
        aiDayStack.axis = .vertical
        aiDayStack.spacing = DesignTokens.Spacing.xs

        // ── AI: suggestion box ──
        aiSuggestionContainer.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        aiSuggestionContainer.layer.cornerRadius = DesignTokens.Radii.md

        aiSuggestionLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiSuggestionLabel.textColor = DesignTokens.Colors.accent
        aiSuggestionLabel.numberOfLines = 0
        aiSuggestionLabel.translatesAutoresizingMaskIntoConstraints = false
        aiSuggestionContainer.addSubview(aiSuggestionLabel)

        let sp = DesignTokens.Spacing.sm + 2 // 10pt
        NSLayoutConstraint.activate([
            aiSuggestionLabel.topAnchor.constraint(equalTo: aiSuggestionContainer.topAnchor, constant: sp),
            aiSuggestionLabel.bottomAnchor.constraint(equalTo: aiSuggestionContainer.bottomAnchor, constant: -sp),
            aiSuggestionLabel.leadingAnchor.constraint(equalTo: aiSuggestionContainer.leadingAnchor, constant: sp + 2),
            aiSuggestionLabel.trailingAnchor.constraint(equalTo: aiSuggestionContainer.trailingAnchor, constant: -sp - 2),
        ])

        // ── AI: directive insights ──
        aiDirectiveLabel.font = DesignTokens.Typography.caption1
        aiDirectiveLabel.textColor = DesignTokens.Colors.textTertiary
        aiDirectiveLabel.numberOfLines = 0

        // ── Main stack ──
        mainStack = UIStackView(arrangedSubviews: [
            headerStack, statsRow, aiBadgeRow, aiSummaryLabel, aiDayStack, aiSuggestionContainer, aiDirectiveLabel,
        ])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        // Custom spacing for visual rhythm
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

        // Avg rating pill
        if let avg = summary.averageRating {
            avgRatingPill.text = "\(String(format: "%.1f", avg)) avg"
            avgRatingPill.isHidden = false
        } else {
            avgRatingPill.isHidden = true
        }

        // Combined subtitle
        var subtitleParts: [String] = ["\(summary.entryCount) entr\(summary.entryCount == 1 ? "y" : "ies")"]
        if !summary.topTags.isEmpty {
            subtitleParts.append(summary.topTags.joined(separator: ", "))
        }
        subtitleLabel.text = subtitleParts.joined(separator: " • ")

        let hasReview = review != nil

        // Non-AI stats (hidden when review present)
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

        // AI content
        let badgeRow = mainStack.arrangedSubviews[2] // aiBadgeRow
        badgeRow.isHidden = !hasReview
        aiSummaryLabel.isHidden = !hasReview
        aiDayStack.isHidden = !hasReview
        aiSuggestionContainer.isHidden = true
        aiDirectiveLabel.isHidden = true

        // Reset day cards
        aiDayStack.arrangedSubviews.forEach { aiDayStack.removeArrangedSubview($0); $0.removeFromSuperview() }

        guard let review else { return }

        aiSummaryLabel.text = review.summary

        // Day note cards
        if let note = review.bestDayNote {
            let title = review.bestDay.map { "↑ \(HistoryDateFormat.shortDate($0))" } ?? "↑ Best"
            aiBestCard.configure(title: title, body: note, accent: DesignTokens.Colors.success)
            aiDayStack.addArrangedSubview(aiBestCard)
        }
        if let note = review.lowestDayNote {
            let title = review.lowestDay.map { "↓ \(HistoryDateFormat.shortDate($0))" } ?? "↓ Lowest"
            aiWorstCard.configure(title: title, body: note, accent: DesignTokens.Colors.warning)
            aiDayStack.addArrangedSubview(aiWorstCard)
        }
        aiDayStack.isHidden = aiDayStack.arrangedSubviews.isEmpty

        if let suggestion = review.suggestion, !suggestion.isEmpty {
            aiSuggestionLabel.text = "💡 \(suggestion)"
            aiSuggestionContainer.isHidden = false
        }

        if let insights = review.directiveInsights, !insights.isEmpty {
            aiDirectiveLabel.text = insights
            aiDirectiveLabel.isHidden = false
        }
    }
}

// MARK: - DayNoteCard (inline day summary used in month card)

final class DayNoteCard: UIView {
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupView() }

    private func setupView() {
        layer.cornerRadius = DesignTokens.Radii.sm

        titleLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textPrimary
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let h = DesignTokens.Spacing.sm + 2
        let v = DesignTokens.Spacing.sm
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: v),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -v),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: h),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -h),
        ])
    }

    func configure(title: String, body: String, accent: UIColor) {
        titleLabel.text = title
        titleLabel.textColor = accent
        bodyLabel.text = body
        backgroundColor = accent.withAlphaComponent(0.08)
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
