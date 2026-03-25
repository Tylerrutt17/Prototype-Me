import UIKit

/// Page 9: App logo/icon with celebration-level particles — "Let's build your system."
final class OnboardingHeroView: UIView, StoryAnimatable {

    private let iconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "scope", withConfiguration: config))
        iv.tintColor = DesignTokens.Colors.accent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let appNameLabel: UILabel = {
        let label = UILabel()
        label.text = "Prototype Me"
        label.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        label.textColor = DesignTokens.Colors.textPrimary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(iconView)
        addSubview(appNameLabel)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -DesignTokens.Spacing.xl),
            iconView.widthAnchor.constraint(equalToConstant: 100),
            iconView.heightAnchor.constraint(equalToConstant: 100),

            appNameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            appNameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])

        iconView.alpha = 0
        iconView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        appNameLabel.alpha = 0
        appNameLabel.transform = CGAffineTransform(translationX: 0, y: 15)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            iconView.alpha = 1; iconView.transform = .identity
            appNameLabel.alpha = 1; appNameLabel.transform = .identity
            return
        }

        // Icon spring scale-in
        UIView.animate(withDuration: 0.7, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3) {
            self.iconView.alpha = 1
            self.iconView.transform = .identity
        }

        // App name slides up
        UIView.animate(withDuration: 0.4, delay: 0.5, options: .curveEaseOut) {
            self.appNameLabel.alpha = 1
            self.appNameLabel.transform = .identity
        }

        Haptics.success()
    }

    func stopAnimations() {
        iconView.layer.removeAllAnimations()
        appNameLabel.layer.removeAllAnimations()
    }
}
