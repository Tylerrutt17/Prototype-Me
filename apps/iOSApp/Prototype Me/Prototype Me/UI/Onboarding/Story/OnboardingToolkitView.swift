import UIKit

/// Transition screen: Three tool icons (directives, modes, balloons) in a row,
/// staggering in one by one with labels. Brief visual breath before the feature deep-dives.
final class OnboardingToolkitView: UIView, StoryAnimatable {

    private var toolViews: [UIView] = []
    private var hasBuilt = false

    private let tools: [(icon: String, label: String, color: UIColor)] = [
        ("arrow.right.circle.fill", "Directives", DesignTokens.Colors.accent),
        ("bolt.fill", "Modes", NoteKind.mode.color),
        ("balloon.fill", "Balloons", DesignTokens.Colors.success),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    private func buildVisual() {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.xxl
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        for tool in tools {
            let circleSize: CGFloat = 56

            // Circle background
            let circle = UIView()
            circle.backgroundColor = tool.color.withAlphaComponent(0.15)
            circle.layer.cornerRadius = circleSize / 2
            circle.translatesAutoresizingMaskIntoConstraints = false

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            let iconView = UIImageView(image: UIImage(systemName: tool.icon, withConfiguration: iconConfig))
            iconView.tintColor = tool.color
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(iconView)

            let label = UILabel()
            label.text = tool.label
            label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
            label.textColor = DesignTokens.Colors.textSecondary
            label.textAlignment = .center

            let stack = UIStackView(arrangedSubviews: [circle, label])
            stack.axis = .vertical
            stack.spacing = DesignTokens.Spacing.sm
            stack.alignment = .center

            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: circleSize),
                circle.heightAnchor.constraint(equalToConstant: circleSize),
                iconView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            ])

            stack.alpha = 0
            stack.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

            row.addArrangedSubview(stack)
            toolViews.append(stack)
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for v in toolViews { v.alpha = 1; v.transform = .identity }
            return
        }

        for (i, view) in toolViews.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.2 + Double(i) * 0.15,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for v in toolViews { v.layer.removeAllAnimations() }
    }
}
