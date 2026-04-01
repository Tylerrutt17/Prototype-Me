import UIKit

/// Page 7 visual: a golden framework star icon scaling in with a celebration glow.
final class DirectiveStoryFrameworkView: UIView, StoryAnimatable {

    private let starView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "star.fill", withConfiguration: config))
        iv.tintColor = UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 1.0) // Gold
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let glowCircle: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 0.08)
        v.layer.cornerRadius = 70
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let badge: UIView = {
        let pill = UIView()
        pill.backgroundColor = UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 0.12)
        pill.layer.cornerRadius = DesignTokens.Radii.pill
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 0.3).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
        icon.tintColor = UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 1.0)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Discovered, not guessed"
        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        label.textColor = UIColor(red: 0.95, green: 0.65, blue: 0.20, alpha: 1.0)

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
        addSubview(glowCircle)
        addSubview(starView)
        addSubview(badge)

        NSLayoutConstraint.activate([
            glowCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            glowCircle.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -DesignTokens.Spacing.lg),
            glowCircle.widthAnchor.constraint(equalToConstant: 140),
            glowCircle.heightAnchor.constraint(equalToConstant: 140),

            starView.centerXAnchor.constraint(equalTo: centerXAnchor),
            starView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -DesignTokens.Spacing.lg),
            starView.widthAnchor.constraint(equalToConstant: 100),
            starView.heightAnchor.constraint(equalToConstant: 100),

            badge.centerXAnchor.constraint(equalTo: centerXAnchor),
            badge.topAnchor.constraint(equalTo: starView.bottomAnchor, constant: DesignTokens.Spacing.xl),
        ])

        starView.alpha = 0
        starView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        glowCircle.alpha = 0
        glowCircle.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        badge.alpha = 0
        badge.transform = CGAffineTransform(translationX: 0, y: 10)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            starView.alpha = 1; starView.transform = .identity
            glowCircle.alpha = 1; glowCircle.transform = .identity
            badge.alpha = 1; badge.transform = .identity
            return
        }

        // Glow circle expands
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.2) {
            self.glowCircle.alpha = 1
            self.glowCircle.transform = .identity
        }

        // Star scales in with spring
        UIView.animate(withDuration: 0.7, delay: 0.15, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.3) {
            self.starView.alpha = 1
            self.starView.transform = .identity
        }

        // Badge fades in
        UIView.animate(withDuration: 0.4, delay: 0.6, options: .curveEaseOut) {
            self.badge.alpha = 1
            self.badge.transform = .identity
        }

        // Breathing glow pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            UIView.animate(
                withDuration: 2.0,
                delay: 0,
                options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]
            ) {
                self?.glowCircle.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                self?.glowCircle.alpha = 0.6
            }
        }
    }

    func stopAnimations() {
        starView.layer.removeAllAnimations()
        glowCircle.layer.removeAllAnimations()
        badge.layer.removeAllAnimations()
    }
}
