import UIKit

/// Smaller card shown beneath a month card for each week's AI review.
final class WeeklyReviewCard: UICollectionViewCell {

    private let weekLabel = UILabel()
    private let summaryLabel = UILabel()
    private let suggestionLabel = UILabel()
    private let ratingLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.5)
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        weekLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        weekLabel.textColor = DesignTokens.Colors.textSecondary

        ratingLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        ratingLabel.textColor = DesignTokens.Colors.accent

        summaryLabel.font = DesignTokens.Typography.footnote
        summaryLabel.textColor = DesignTokens.Colors.textPrimary
        summaryLabel.numberOfLines = 0

        suggestionLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        suggestionLabel.textColor = DesignTokens.Colors.accent
        suggestionLabel.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [weekLabel, UIView(), ratingLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, summaryLabel, suggestionLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
    }

    func configure(with review: PeriodicReview) {
        weekLabel.text = HistoryDateFormat.weekRange(start: review.periodStart, end: review.periodEnd)
        summaryLabel.text = review.summary

        if let avg = review.avgRating {
            ratingLabel.text = String(format: "%.1f avg", avg)
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        if let suggestion = review.suggestion, !suggestion.isEmpty {
            suggestionLabel.text = "💡 \(suggestion)"
            suggestionLabel.isHidden = false
        } else {
            suggestionLabel.isHidden = true
        }
    }
}
