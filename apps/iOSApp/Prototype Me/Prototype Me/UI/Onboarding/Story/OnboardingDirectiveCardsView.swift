import UIKit

/// Page 4: Mock directive cards appearing one by one with spring animations.
final class OnboardingDirectiveCardsView: UIView, StoryAnimatable {

    private var cards: [UIView] = []

    private let directives = [
        ("Drink more water", DesignTokens.Colors.success),
        ("Morning meditation", DesignTokens.Colors.accent),
        ("Weekly review", DesignTokens.Colors.accentTertiary),
        ("Read for 20 minutes", DesignTokens.Colors.accentSecondary),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildCards()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildCards() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        for (title, color) in directives {
            let card = makeCard(title: title, color: color)
            stack.addArrangedSubview(card)
            cards.append(card)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 30)
        }
    }

    private func makeCard(title: String, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor

        let accentBar = UIView()
        accentBar.backgroundColor = color
        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentBar)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: "arrow.right.circle.fill", withConfiguration: iconConfig))
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary

        let row = UIStackView(arrangedSubviews: [icon, label, UIView()])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignTokens.Spacing.sm),
            accentBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: DesignTokens.Spacing.md),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        return card
    }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for card in cards { card.alpha = 1; card.transform = .identity }
            return
        }

        for (i, card) in cards.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.15 + Double(i) * 0.15,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3
            ) {
                card.alpha = 1
                card.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for card in cards { card.layer.removeAllAnimations() }
    }
}
