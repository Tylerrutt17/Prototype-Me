import UIKit

/// Compact collection view cell for schedule instances (directive name + status pill).
final class ScheduleInstanceRowCell: UICollectionViewCell {

    static let reuseID = "ScheduleInstanceRowCell"

    private let titleLabel = UILabel()
    private let statusBadge = StatusBadgeView()

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
        contentView.layer.cornerRadius = DesignTokens.Radii.sm
        contentView.clipsToBounds = true

        titleLabel.font = DesignTokens.Typography.subheadline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [titleLabel, UIView(), statusBadge])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with row: ScheduleInstanceRow) {
        titleLabel.text = row.directiveTitle
        statusBadge.configure(instanceStatus: row.instance.status)

        // Dim completed rows
        contentView.alpha = row.instance.status == .done ? 0.6 : 1.0
    }
}
