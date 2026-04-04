import UIKit

/// Smaller card shown beneath a month card for each week's AI review.
final class WeeklyReviewCard: UICollectionViewCell {

    private let weekLabel = UILabel()
    private let ratingPill = UILabel()
    private let summaryLabel = UILabel()
    private let suggestionContainer = UIView()
    private let suggestionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private let containerView = UIView()

    private func setupCell() {
        contentView.backgroundColor = .clear
        containerView.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.5)
        containerView.layer.cornerRadius = DesignTokens.Radii.md
        containerView.clipsToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = DesignTokens.Colors.separator.withAlphaComponent(0.2).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        // Indent weekly cards from the left to visually nest under month card
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        weekLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        weekLabel.textColor = DesignTokens.Colors.textSecondary

        ratingPill.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        ratingPill.textColor = DesignTokens.Colors.accent
        ratingPill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        ratingPill.layer.cornerRadius = 8
        ratingPill.clipsToBounds = true
        ratingPill.textAlignment = .center
        ratingPill.setContentHuggingPriority(.required, for: .horizontal)

        summaryLabel.font = DesignTokens.Typography.footnote
        summaryLabel.textColor = DesignTokens.Colors.textPrimary
        summaryLabel.numberOfLines = 0

        // Suggestion box
        suggestionContainer.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        suggestionContainer.layer.cornerRadius = DesignTokens.Radii.sm

        suggestionLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        suggestionLabel.textColor = DesignTokens.Colors.accent
        suggestionLabel.numberOfLines = 0
        suggestionLabel.translatesAutoresizingMaskIntoConstraints = false
        suggestionContainer.addSubview(suggestionLabel)

        let sp: CGFloat = DesignTokens.Spacing.sm
        NSLayoutConstraint.activate([
            suggestionLabel.topAnchor.constraint(equalTo: suggestionContainer.topAnchor, constant: sp),
            suggestionLabel.bottomAnchor.constraint(equalTo: suggestionContainer.bottomAnchor, constant: -sp),
            suggestionLabel.leadingAnchor.constraint(equalTo: suggestionContainer.leadingAnchor, constant: sp + 2),
            suggestionLabel.trailingAnchor.constraint(equalTo: suggestionContainer.trailingAnchor, constant: -sp - 2),
        ])

        let topRow = UIStackView(arrangedSubviews: [weekLabel, UIView(), ratingPill])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, summaryLabel, suggestionContainer])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.setCustomSpacing(DesignTokens.Spacing.xs, after: topRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -pad),
        ])
    }

    func configure(with review: PeriodicReview) {
        weekLabel.text = HistoryDateFormat.weekRange(start: review.periodStart, end: review.periodEnd)
        summaryLabel.text = review.summary

        if let avg = review.avgRating {
            ratingPill.text = "  \(String(format: "%.1f", avg))  "
            ratingPill.isHidden = false
        } else {
            ratingPill.isHidden = true
        }

        if let suggestion = review.suggestion, !suggestion.isEmpty {
            suggestionLabel.text = "💡 \(suggestion)"
            suggestionContainer.isHidden = false
        } else {
            suggestionContainer.isHidden = true
        }
    }
}
