import UIKit

/// Page 1 visual: large brain SF Symbol with spring scale-in entrance.
final class StoryParticleView: UIView, StoryAnimatable {

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 100, weight: .ultraLight)
        let iv = UIImageView(image: UIImage(systemName: "brain.head.profile", withConfiguration: config))
        iv.tintColor = DesignTokens.Colors.accent.withAlphaComponent(0.7)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let badge: UIView = {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
        pill.layer.cornerRadius = DesignTokens.Radii.pill
        pill.layer.borderWidth = 1
        pill.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "flask.fill"))
        icon.tintColor = DesignTokens.Colors.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Cognitive-Science Based Feature"
        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        label.textColor = DesignTokens.Colors.accent

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.xs
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: DesignTokens.Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        return pill
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(iconView)
        addSubview(badge)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -DesignTokens.Spacing.lg),
            iconView.widthAnchor.constraint(equalToConstant: 120),
            iconView.heightAnchor.constraint(equalToConstant: 120),

            badge.centerXAnchor.constraint(equalTo: centerXAnchor),
            badge.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
        ])
        iconView.alpha = 0
        iconView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        badge.alpha = 0
        badge.transform = CGAffineTransform(translationX: 0, y: 10)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            iconView.alpha = 1; iconView.transform = .identity
            badge.alpha = 1; badge.transform = .identity
            return
        }
        UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3) {
            self.iconView.alpha = 1
            self.iconView.transform = .identity
        }
        UIView.animate(withDuration: 0.4, delay: 0.5, options: .curveEaseOut) {
            self.badge.alpha = 1
            self.badge.transform = .identity
        }
    }

    func stopAnimations() {
        iconView.layer.removeAllAnimations()
        badge.layer.removeAllAnimations()
    }
}
