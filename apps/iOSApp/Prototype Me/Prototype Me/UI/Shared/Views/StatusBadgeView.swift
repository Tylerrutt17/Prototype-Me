import UIKit

/// Pill-shaped badge displaying a status string with a tinted background.
final class StatusBadgeView: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        layer.cornerRadius = DesignTokens.Radii.sm
        clipsToBounds = true

        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.xxs),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.xxs),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm),
        ])
    }

    /// Configure with a DirectiveStatus.
    func configure(status: DirectiveStatus) {
        let (text, tint): (String, UIColor) = switch status {
        case .active:     ("Active",     DesignTokens.Colors.success)
        case .maintained: ("Maintained", DesignTokens.Colors.warning)
        case .retired:    ("Retired",    DesignTokens.Colors.textTertiary)
        }
        configure(text: text, tint: tint)
    }

    /// Configure with an InstanceStatus.
    func configure(instanceStatus: InstanceStatus) {
        let (text, tint): (String, UIColor) = switch instanceStatus {
        case .pending: ("Pending", DesignTokens.Colors.warning)
        case .done:    ("Done",    DesignTokens.Colors.success)
        case .skipped: ("Skipped", DesignTokens.Colors.textTertiary)
        }
        configure(text: text, tint: tint)
    }

    /// Generic configuration with text and tint color.
    func configure(text: String, tint: UIColor) {
        label.text = text.uppercased()
        label.textColor = tint
        backgroundColor = tint.withAlphaComponent(0.15)
    }
}
