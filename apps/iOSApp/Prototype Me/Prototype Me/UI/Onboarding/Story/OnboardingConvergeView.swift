import UIKit

/// Differentiator page visual: feature icons scattered around that drift and converge
/// toward a central Framework star and Mode bolt, showing all features feeding into the system.
final class OnboardingConvergeView: UIView, StoryAnimatable {

    private var featureIcons: [UIView] = []
    private let frameworkStar = UIImageView()
    private let modeBolt = UIImageView()
    private var hasAnimated = false

    private let features: [(icon: String, color: UIColor)] = [
        ("arrow.right.circle.fill", DesignTokens.Colors.accent),        // Directives
        ("balloon.fill", DesignTokens.Colors.success),                   // Balloons
        ("checklist", DesignTokens.Colors.accentSecondary),              // Schedules
        ("book.fill", DesignTokens.Colors.accentTertiary),               // Journal
        ("brain.head.profile", DesignTokens.Colors.accent),              // AI
        ("folder.fill", DesignTokens.Colors.accentSecondary),            // Notes
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        // Central targets
        let starConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        frameworkStar.image = UIImage(systemName: "star.fill", withConfiguration: starConfig)
        frameworkStar.tintColor = NoteKind.framework.color
        frameworkStar.contentMode = .scaleAspectFit
        frameworkStar.translatesAutoresizingMaskIntoConstraints = false
        frameworkStar.alpha = 0
        addSubview(frameworkStar)

        let boltConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        modeBolt.image = UIImage(systemName: "bolt.fill", withConfiguration: boltConfig)
        modeBolt.tintColor = NoteKind.mode.color
        modeBolt.contentMode = .scaleAspectFit
        modeBolt.translatesAutoresizingMaskIntoConstraints = false
        modeBolt.alpha = 0
        addSubview(modeBolt)

        NSLayoutConstraint.activate([
            frameworkStar.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -24),
            frameworkStar.centerYAnchor.constraint(equalTo: centerYAnchor),

            modeBolt.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 24),
            modeBolt.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Feature icons
        for feature in features {
            let size: CGFloat = 28
            let circle = UIView()
            circle.backgroundColor = feature.color.withAlphaComponent(0.12)
            circle.layer.cornerRadius = size / 2 + 6
            circle.frame = CGRect(x: 0, y: 0, width: size + 12, height: size + 12)
            circle.alpha = 0

            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let iconView = UIImageView(image: UIImage(systemName: feature.icon, withConfiguration: config))
            iconView.tintColor = feature.color
            iconView.contentMode = .scaleAspectFit
            iconView.frame = circle.bounds.insetBy(dx: 6, dy: 6)
            circle.addSubview(iconView)

            addSubview(circle)
            featureIcons.append(circle)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasAnimated, bounds.width > 0 else { return }

        // Scatter feature icons around the edges
        let cx = bounds.midX
        let cy = bounds.midY
        let radius = min(bounds.width, bounds.height) * 0.4

        for (i, icon) in featureIcons.enumerated() {
            let angle = (CGFloat(i) / CGFloat(featureIcons.count)) * 2 * .pi - .pi / 2
            icon.center = CGPoint(
                x: cx + cos(angle) * radius,
                y: cy + sin(angle) * radius
            )
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        hasAnimated = true

        guard !UIAccessibility.isReduceMotionEnabled else {
            for icon in featureIcons { icon.alpha = 0.5 }
            frameworkStar.alpha = 1
            modeBolt.alpha = 1
            return
        }

        // Phase 1: Feature icons fade in scattered
        for (i, icon) in featureIcons.enumerated() {
            UIView.animate(withDuration: 0.3, delay: Double(i) * 0.08) {
                icon.alpha = 1
            }
        }

        // Phase 2: Central targets appear
        UIView.animate(withDuration: 0.5, delay: 0.6, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3) {
            self.frameworkStar.alpha = 1
            self.frameworkStar.transform = .identity
            self.modeBolt.alpha = 1
            self.modeBolt.transform = .identity
        }

        // Phase 3: Icons drift inward toward center
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.bounds.width > 0 else { return }
            let cx = self.bounds.midX
            let cy = self.bounds.midY
            let closeRadius = min(self.bounds.width, self.bounds.height) * 0.2

            for (i, icon) in self.featureIcons.enumerated() {
                let angle = (CGFloat(i) / CGFloat(self.featureIcons.count)) * 2 * .pi - .pi / 2
                let target = CGPoint(
                    x: cx + cos(angle) * closeRadius,
                    y: cy + sin(angle) * closeRadius
                )

                UIView.animate(
                    withDuration: 0.8,
                    delay: Double(i) * 0.06,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 0.2
                ) {
                    icon.center = target
                    icon.alpha = 0.6
                }
            }
        }

        // Phase 4: Central icons glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            UIView.animate(
                withDuration: 1.5,
                delay: 0,
                options: [.repeat, .autoreverse, .curveEaseInOut]
            ) {
                self?.frameworkStar.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                self?.modeBolt.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }
        }
    }

    func stopAnimations() {
        frameworkStar.layer.removeAllAnimations()
        modeBolt.layer.removeAllAnimations()
        for icon in featureIcons { icon.layer.removeAllAnimations() }
    }
}
