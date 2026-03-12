import UIKit

/// Collection view cell for diary / day-entry list rows.
final class DayEntryCell: UICollectionViewCell {

    static let reuseID = "DayEntryCell"

    private let ratingCircle = RatingCircleView()
    private let dateLabel = UILabel()
    private let diaryLabel = UILabel()
    private let tagsLabel = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        dateLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        dateLabel.textColor = DesignTokens.Colors.textPrimary

        diaryLabel.font = DesignTokens.Typography.caption1
        diaryLabel.textColor = DesignTokens.Colors.textSecondary
        diaryLabel.numberOfLines = 2

        tagsLabel.font = DesignTokens.Typography.caption2
        tagsLabel.textColor = DesignTokens.Colors.accent
        tagsLabel.numberOfLines = 1

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        ratingCircle.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [dateLabel, diaryLabel, tagsLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xxs

        let mainStack = UIStackView(arrangedSubviews: [ratingCircle, textStack, chevron])
        mainStack.axis = .horizontal
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 12),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with summary: DayEntrySummary) {
        ratingCircle.configure(rating: summary.entry.rating)
        dateLabel.text = formattedDate(summary.entry.date)
        diaryLabel.text = summary.diaryPreview
        tagsLabel.text = summary.tagNames.map { "#\($0)" }.joined(separator: "  ")
        tagsLabel.isHidden = summary.tagNames.isEmpty
    }

    private func formattedDate(_ dateString: String) -> String {
        let inputFmt = DateFormatter()
        inputFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inputFmt.date(from: dateString) else { return dateString }
        let outputFmt = DateFormatter()
        outputFmt.dateStyle = .medium
        return outputFmt.string(from: date)
    }
}
