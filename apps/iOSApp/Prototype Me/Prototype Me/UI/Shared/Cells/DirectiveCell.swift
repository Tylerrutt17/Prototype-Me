import UIKit

/// Collection view cell for displaying a Directive in list views.
final class DirectiveCell: UICollectionViewCell {

    static let reuseID = "DirectiveCell"

    private let statusBadge = StatusBadgeView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let pressureIndicator = PressureIndicator()
    private let scheduleIcon = UIImageView()
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

        titleLabel.font = DesignTokens.Typography.headline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1

        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 2

        scheduleIcon.image = UIImage(systemName: "calendar.badge.clock")
        scheduleIcon.tintColor = DesignTokens.Colors.accent
        scheduleIcon.contentMode = .scaleAspectFit

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        // Top row: statusBadge + pressureIndicator + scheduleIcon + chevron
        let topRow = UIStackView(arrangedSubviews: [statusBadge, pressureIndicator, UIView(), scheduleIcon, chevron])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.sm
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            pressureIndicator.widthAnchor.constraint(equalToConstant: 12),
            pressureIndicator.heightAnchor.constraint(equalToConstant: 12),
            scheduleIcon.widthAnchor.constraint(equalToConstant: 16),
            scheduleIcon.heightAnchor.constraint(equalToConstant: 16),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with data: DirectiveRowData) {
        statusBadge.configure(status: data.directive.status)
        titleLabel.text = data.directive.title
        bodyLabel.text = data.directive.body
        bodyLabel.isHidden = data.directive.body == nil

        pressureIndicator.configure(level: data.pressureLevel)
        pressureIndicator.isHidden = !data.directive.balloonEnabled

        scheduleIcon.isHidden = !data.scheduledToday
    }
}
