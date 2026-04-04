import UIKit

/// Card shown in the History list for a single month. Combines local stats
/// (entry count, avg rating, top tags) with optional AI-generated review content.
final class MonthSummaryCard: UICollectionViewCell {

    private let monthLabel = UILabel()
    private let entryCountLabel = UILabel()
    private let avgRatingLabel = UILabel()
    private let bestLabel = UILabel()
    private let worstLabel = UILabel()
    private let tagsLabel = UILabel()

    // AI review fields
    private let aiSummaryLabel = UILabel()
    private let aiSuggestionLabel = UILabel()
    private let aiDirectiveLabel = UILabel()
    private let aiDivider = UIView()

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

        monthLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        monthLabel.textColor = DesignTokens.Colors.textPrimary

        entryCountLabel.font = DesignTokens.Typography.caption1
        entryCountLabel.textColor = DesignTokens.Colors.textSecondary

        avgRatingLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        avgRatingLabel.textColor = DesignTokens.Colors.accent

        bestLabel.font = DesignTokens.Typography.caption1
        bestLabel.textColor = DesignTokens.Colors.success
        bestLabel.numberOfLines = 0

        worstLabel.font = DesignTokens.Typography.caption1
        worstLabel.textColor = DesignTokens.Colors.warning
        worstLabel.numberOfLines = 0

        tagsLabel.font = DesignTokens.Typography.caption1
        tagsLabel.textColor = DesignTokens.Colors.textTertiary

        // AI fields
        aiDivider.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        aiDivider.translatesAutoresizingMaskIntoConstraints = false
        aiDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        aiSummaryLabel.font = DesignTokens.Typography.body
        aiSummaryLabel.textColor = DesignTokens.Colors.textPrimary
        aiSummaryLabel.numberOfLines = 0

        aiSuggestionLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiSuggestionLabel.textColor = DesignTokens.Colors.accent
        aiSuggestionLabel.numberOfLines = 0

        aiDirectiveLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiDirectiveLabel.textColor = DesignTokens.Colors.textSecondary
        aiDirectiveLabel.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [monthLabel, UIView(), avgRatingLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        mainStack = UIStackView(arrangedSubviews: [
            topRow, entryCountLabel, bestLabel, worstLabel, tagsLabel,
            aiDivider, aiSummaryLabel, aiSuggestionLabel, aiDirectiveLabel,
        ])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.translatesAutoresizingMaskIntoConstraints = false
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
        entryCountLabel.text = "\(summary.entryCount) entr\(summary.entryCount == 1 ? "y" : "ies")"

        if let avg = summary.averageRating {
            avgRatingLabel.text = String(format: "%.1f avg", avg)
            avgRatingLabel.isHidden = false
        } else {
            avgRatingLabel.isHidden = true
        }

        // Use AI review notes if available, fall back to raw data
        if let review, let bestNote = review.bestDayNote {
            bestLabel.text = "↑ \(bestNote)"
            bestLabel.isHidden = false
        } else if let best = summary.bestDay {
            bestLabel.text = "Best: \(best.date) (\(best.rating ?? 0)/10)"
            bestLabel.isHidden = false
        } else {
            bestLabel.isHidden = true
        }

        if let review, let lowestNote = review.lowestDayNote {
            worstLabel.text = "↓ \(lowestNote)"
            worstLabel.isHidden = false
        } else if let worst = summary.worstDay, worst.id != summary.bestDay?.id {
            worstLabel.text = "Lowest: \(worst.date) (\(worst.rating ?? 0)/10)"
            worstLabel.isHidden = false
        } else {
            worstLabel.isHidden = true
        }

        if !summary.topTags.isEmpty {
            tagsLabel.text = "Top tags: " + summary.topTags.joined(separator: ", ")
            tagsLabel.isHidden = false
        } else {
            tagsLabel.isHidden = true
        }

        // AI review content
        let hasReview = review != nil
        aiDivider.isHidden = !hasReview
        aiSummaryLabel.isHidden = !hasReview
        aiSuggestionLabel.isHidden = true
        aiDirectiveLabel.isHidden = true

        if let review {
            aiSummaryLabel.text = review.summary

            if let suggestion = review.suggestion, !suggestion.isEmpty {
                aiSuggestionLabel.text = "💡 \(suggestion)"
                aiSuggestionLabel.isHidden = false
            }

            if let insights = review.directiveInsights, !insights.isEmpty {
                aiDirectiveLabel.text = insights
                aiDirectiveLabel.isHidden = false
            }
        }
    }
}
