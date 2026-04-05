import UIKit

/// Collection view cell for displaying a Directive in list views.
final class DirectiveCell: InteractiveCell {

    static let reuseID = "DirectiveCell"

    private let colorDot = ColorDotView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let balloonIcon = UIImageView()
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

        colorDot.size = 14

        titleLabel.font = DesignTokens.Typography.headline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 2

        balloonIcon.image = UIImage(systemName: "balloon.fill")
        balloonIcon.contentMode = .scaleAspectFit
        balloonIcon.setContentHuggingPriority(.required, for: .horizontal)

        scheduleIcon.image = UIImage(systemName: "calendar.badge.clock")
        scheduleIcon.tintColor = DesignTokens.Colors.accent
        scheduleIcon.contentMode = .scaleAspectFit

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        // Title row: [color dot] title [balloon icon] [schedule icon] chevron
        let titleRow = UIStackView(arrangedSubviews: [colorDot, titleLabel, balloonIcon, scheduleIcon, chevron])
        titleRow.axis = .horizontal
        titleRow.spacing = DesignTokens.Spacing.sm
        titleRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleRow, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            colorDot.widthAnchor.constraint(equalToConstant: 14),
            colorDot.heightAnchor.constraint(equalToConstant: 14),
            balloonIcon.widthAnchor.constraint(equalToConstant: 18),
            balloonIcon.heightAnchor.constraint(equalToConstant: 18),
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
        titleLabel.text = data.directive.title
        bodyLabel.text = data.directive.body
        bodyLabel.isHidden = data.directive.body == nil

        colorDot.configure(hex: data.directive.color)
        colorDot.isHidden = data.directive.color == nil

        if let level = data.pressureLevel {
            balloonIcon.tintColor = balloonTint(for: level)
            balloonIcon.isHidden = false
        } else {
            balloonIcon.isHidden = true
        }

        scheduleIcon.isHidden = !data.scheduledToday
    }

    private func balloonTint(for level: PressureLevel) -> UIColor {
        switch level {
        case .green:  return DesignTokens.Colors.success
        case .yellow: return DesignTokens.Colors.warning
        case .red:    return DesignTokens.Colors.destructive
        }
    }
}
