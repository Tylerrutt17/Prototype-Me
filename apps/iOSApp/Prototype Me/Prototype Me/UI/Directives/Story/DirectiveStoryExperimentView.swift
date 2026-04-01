import UIKit

/// Page 2 visual: a cycling loop diagram — try → observe → adjust — with arrows connecting them.
final class DirectiveStoryExperimentView: UIView, StoryAnimatable {

    private var stepViews: [UIView] = []
    private var arrowViews: [UIImageView] = []

    private let steps: [(icon: String, label: String, color: UIColor)] = [
        ("flame.fill", "Try", DesignTokens.Colors.accent),
        ("eye.fill", "Observe", DesignTokens.Colors.accentSecondary),
        ("arrow.triangle.2.circlepath", "Adjust", DesignTokens.Colors.success),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let rowStack = UIStackView()
        rowStack.axis = .horizontal
        rowStack.spacing = DesignTokens.Spacing.md
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        for (i, step) in steps.enumerated() {
            // Step circle
            let stepView = makeStepView(icon: step.icon, label: step.label, color: step.color)
            rowStack.addArrangedSubview(stepView)
            stepViews.append(stepView)

            stepView.alpha = 0
            stepView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

            // Arrow between steps
            if i < steps.count - 1 {
                let arrowConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
                let arrow = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: arrowConfig))
                arrow.tintColor = DesignTokens.Colors.textTertiary
                arrow.contentMode = .scaleAspectFit
                arrow.alpha = 0
                arrowViews.append(arrow)
                rowStack.addArrangedSubview(arrow)
            }
        }

        // "Repeat" label below
        let repeatLabel = UILabel()
        repeatLabel.text = "repeat"
        repeatLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        repeatLabel.textColor = DesignTokens.Colors.textTertiary
        repeatLabel.textAlignment = .center
        repeatLabel.alpha = 0
        repeatLabel.tag = 100
        repeatLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(repeatLabel)

        NSLayoutConstraint.activate([
            repeatLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            repeatLabel.topAnchor.constraint(equalTo: container.bottomAnchor, constant: DesignTokens.Spacing.xl),
        ])
    }

    private func makeStepView(icon: String, label: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let circle = UIView()
        circle.backgroundColor = color.withAlphaComponent(0.15)
        circle.layer.cornerRadius = 30
        circle.layer.borderWidth = 2
        circle.layer.borderColor = color.withAlphaComponent(0.4).cgColor
        circle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(circle)

        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(iconView)

        let nameLabel = UILabel()
        nameLabel.text = label
        nameLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        nameLabel.textColor = DesignTokens.Colors.textSecondary
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: container.topAnchor),
            circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circle.widthAnchor.constraint(equalToConstant: 60),
            circle.heightAnchor.constraint(equalToConstant: 60),

            iconView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: DesignTokens.Spacing.sm),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for v in stepViews { v.alpha = 1; v.transform = .identity }
            for a in arrowViews { a.alpha = 1 }
            viewWithTag(100)?.alpha = 1
            return
        }

        for (i, step) in stepViews.enumerated() {
            let delay = 0.2 + Double(i) * 0.3

            UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                step.alpha = 1
                step.transform = .identity
            }

            // Show arrow after its preceding step
            if i < arrowViews.count {
                UIView.animate(withDuration: 0.3, delay: delay + 0.15, options: .curveEaseOut) {
                    self.arrowViews[i].alpha = 1
                }
            }
        }

        // Show "repeat" label last
        UIView.animate(withDuration: 0.4, delay: 1.2, options: .curveEaseOut) {
            self.viewWithTag(100)?.alpha = 1
        }
    }

    func stopAnimations() {
        for v in stepViews { v.layer.removeAllAnimations() }
        for a in arrowViews { a.layer.removeAllAnimations() }
    }
}
