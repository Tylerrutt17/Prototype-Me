import UIKit

/// Page 3 visual: example directive types appearing one at a time with staggered animations.
final class DirectiveStoryTypesView: UIView, StoryAnimatable {

    private var rows: [UIView] = []

    private let examples: [(icon: String, text: String, color: UIColor)] = [
        ("flame.fill", "Meditate daily", DesignTokens.Colors.accent),
        ("nosign", "No phone before 9am", DesignTokens.Colors.destructive),
        ("drop.fill", "Drink more water", DesignTokens.Colors.accentSecondary),
        ("heart.fill", "Lead with empathy", DesignTokens.Colors.accentTertiary),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildRows()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildRows() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        for example in examples {
            let row = makeRow(icon: example.icon, text: example.text, color: example.color)
            stack.addArrangedSubview(row)
            rows.append(row)
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.95, y: 0.95)
        }
    }

    private func makeRow(icon: String, text: String, color: UIColor) -> UIView {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
        pill.layer.cornerRadius = DesignTokens.Radii.lg
        pill.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .body, weight: .medium)
        label.textColor = DesignTokens.Colors.textPrimary

        let dot = UIView()
        dot.backgroundColor = color.withAlphaComponent(0.4)
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = UIStackView(arrangedSubviews: [iconView, label, UIView(), dot])
        rowStack.axis = .horizontal
        rowStack.spacing = DesignTokens.Spacing.md
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(rowStack)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            rowStack.topAnchor.constraint(equalTo: pill.topAnchor, constant: inset),
            rowStack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -inset),
            rowStack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.lg),
            rowStack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return pill
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for row in rows { row.alpha = 1; row.transform = .identity }
            return
        }

        for (i, row) in rows.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.15 + Double(i) * 0.18,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3
            ) {
                row.alpha = 1
                row.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for row in rows { row.layer.removeAllAnimations() }
    }
}
