import UIKit

/// Small label showing a Tier value (Foundation / Support / Active) with tier-specific color.
final class TierLabel: UIView {

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

        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
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

    func configure(tier: Tier) {
        let color = tierColor(tier)
        label.text = tier.rawValue.capitalized
        label.textColor = color
        backgroundColor = color.withAlphaComponent(0.12)
    }

    private func tierColor(_ tier: Tier) -> UIColor {
        switch tier {
        case .foundation: return DesignTokens.Colors.accentSecondary  // green-ish
        case .support:    return DesignTokens.Colors.accent           // blue
        case .active:     return DesignTokens.Colors.accentTertiary   // orange
        }
    }
}
