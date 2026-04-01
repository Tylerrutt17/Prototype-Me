import UIKit

/// Page 5 visual: three tool icons (balloon, schedule, history) appearing with staggered animations.
final class DirectiveStoryToolsView: UIView, StoryAnimatable {

    private var toolViews: [UIView] = []

    private let tools: [(icon: String, label: String, color: UIColor)] = [
        ("balloon.fill", "Balloons", DesignTokens.Colors.success),
        ("checklist", "Schedules", DesignTokens.Colors.accent),
        ("clock.arrow.circlepath", "History", DesignTokens.Colors.accentSecondary),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.xxl
        stack.alignment = .center
        stack.distribution = .equalCentering
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        for tool in tools {
            let toolView = makeToolView(icon: tool.icon, label: tool.label, color: tool.color)
            stack.addArrangedSubview(toolView)
            toolViews.append(toolView)
            toolView.alpha = 0
            toolView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5).translatedBy(x: 0, y: 20)
        }
    }

    private func makeToolView(icon: String, label: String, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Circle background
        let circle = UIView()
        circle.backgroundColor = color.withAlphaComponent(0.12)
        circle.layer.cornerRadius = 35
        circle.layer.borderWidth = 1.5
        circle.layer.borderColor = color.withAlphaComponent(0.3).cgColor
        circle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(circle)

        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
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
            circle.widthAnchor.constraint(equalToConstant: 70),
            circle.heightAnchor.constraint(equalToConstant: 70),

            iconView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: DesignTokens.Spacing.md),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            nameLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for v in toolViews { v.alpha = 1; v.transform = .identity }
            return
        }

        for (i, tool) in toolViews.enumerated() {
            UIView.animate(
                withDuration: 0.6,
                delay: 0.2 + Double(i) * 0.2,
                usingSpringWithDamping: 0.65,
                initialSpringVelocity: 0.3
            ) {
                tool.alpha = 1
                tool.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for v in toolViews { v.layer.removeAllAnimations() }
    }
}
