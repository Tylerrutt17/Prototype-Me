import UIKit

/// Vision page: a golden star icon with orbiting habit/principle labels converging inward,
/// representing the Framework — your personal operating system built over time.
final class OnboardingFrameworkView: UIView, StoryAnimatable {

    private let starView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "star.fill", withConfiguration: config))
        iv.tintColor = NoteKind.framework.color
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let glowCircle: UIView = {
        let v = UIView()
        v.backgroundColor = NoteKind.framework.color.withAlphaComponent(0.06)
        v.layer.cornerRadius = 55
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var orbitLabels: [UIView] = []

    private let habits: [(text: String, icon: String)] = [
        ("Meditate", "brain.head.profile"),
        ("Exercise", "figure.run"),
        ("Journal", "book.fill"),
        ("Be present", "heart.fill"),
        ("Read daily", "book.closed.fill"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        addSubview(glowCircle)
        addSubview(starView)

        NSLayoutConstraint.activate([
            glowCircle.centerXAnchor.constraint(equalTo: centerXAnchor),
            glowCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            glowCircle.widthAnchor.constraint(equalToConstant: 110),
            glowCircle.heightAnchor.constraint(equalToConstant: 110),

            starView.centerXAnchor.constraint(equalTo: centerXAnchor),
            starView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Create orbit labels
        for habit in habits {
            let pill = makePill(text: habit.text, icon: habit.icon)
            pill.alpha = 0
            addSubview(pill)
            orbitLabels.append(pill)
        }

        starView.alpha = 0
        starView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        glowCircle.alpha = 0
        glowCircle.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
    }

    private func makePill(text: String, icon: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.7)
        pill.layer.cornerRadius = DesignTokens.Radii.pill
        pill.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconView.tintColor = NoteKind.framework.color
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        label.textColor = DesignTokens.Colors.textSecondary

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.xs
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -5),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.sm),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.sm),
        ])

        return pill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        // Position orbit labels in a circle around center
        let cx = bounds.midX
        let cy = bounds.midY
        let radius: CGFloat = min(bounds.width, bounds.height) * 0.38

        for (i, pill) in orbitLabels.enumerated() {
            let angle = (CGFloat(i) / CGFloat(orbitLabels.count)) * 2 * .pi - .pi / 2
            let x = cx + cos(angle) * radius
            let y = cy + sin(angle) * radius
            pill.center = CGPoint(x: x, y: y)
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            starView.alpha = 1; starView.transform = .identity
            glowCircle.alpha = 1; glowCircle.transform = .identity
            for pill in orbitLabels { pill.alpha = 1 }
            return
        }

        // Phase 1: Labels appear scattered
        for (i, pill) in orbitLabels.enumerated() {
            UIView.animate(withDuration: 0.4, delay: Double(i) * 0.1, options: .curveEaseOut) {
                pill.alpha = 1
            }
        }

        // Phase 2: Star appears
        UIView.animate(withDuration: 0.6, delay: 0.7, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3) {
            self.starView.alpha = 1
            self.starView.transform = .identity
            self.glowCircle.alpha = 1
            self.glowCircle.transform = .identity
        }

        // Phase 3: Labels drift inward slightly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.bounds.width > 0 else { return }
            let cx = self.bounds.midX
            let cy = self.bounds.midY
            let closerRadius = min(self.bounds.width, self.bounds.height) * 0.30

            for (i, pill) in self.orbitLabels.enumerated() {
                let angle = (CGFloat(i) / CGFloat(self.orbitLabels.count)) * 2 * .pi - .pi / 2
                let x = cx + cos(angle) * closerRadius
                let y = cy + sin(angle) * closerRadius

                UIView.animate(withDuration: 0.8, delay: Double(i) * 0.05, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.2) {
                    pill.center = CGPoint(x: x, y: y)
                    pill.backgroundColor = NoteKind.framework.color.withAlphaComponent(0.12)
                }
            }
        }

        // Breathing glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
                self?.glowCircle.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            }
        }
    }

    func stopAnimations() {
        starView.layer.removeAllAnimations()
        glowCircle.layer.removeAllAnimations()
        for pill in orbitLabels { pill.layer.removeAllAnimations() }
    }
}
