import UIKit

/// Page 4 visual: directive cards where some archive out and others strengthen,
/// showing that not everything sticks — and that's okay.
final class DirectiveStoryEvolutionView: UIView, StoryAnimatable {

    private var cards: [UIView] = []

    private let items: [(text: String, sticks: Bool)] = [
        ("Wake up at 5am", false),
        ("Daily journaling", true),
        ("Cold showers", false),
        ("Exercise 3x/week", true),
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
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        for item in items {
            let card = makeCard(text: item.text)
            stack.addArrangedSubview(card)
            cards.append(card)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 15)
        }
    }

    private func makeCard(text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.6)
        pill.layer.cornerRadius = DesignTokens.Radii.lg
        pill.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .body, weight: .medium)
        label.textColor = DesignTokens.Colors.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: inset),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -inset),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.lg),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return pill
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for (i, card) in cards.enumerated() {
                card.alpha = items[i].sticks ? 1 : 0.3
                card.transform = .identity
            }
            return
        }

        // Phase 1: All cards appear
        for (i, card) in cards.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: 0.1 + Double(i) * 0.12,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                card.alpha = 1
                card.transform = .identity
            }
        }

        // Phase 2: Non-sticking cards fade/slide out, sticking ones glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            for (i, card) in self.cards.enumerated() {
                if self.items[i].sticks {
                    // Strengthen: subtle glow
                    UIView.animate(withDuration: 0.4) {
                        card.backgroundColor = DesignTokens.Colors.success.withAlphaComponent(0.15)
                        card.layer.borderWidth = 1.5
                        card.layer.borderColor = DesignTokens.Colors.success.withAlphaComponent(0.4).cgColor
                    }
                } else {
                    // Archive out: fade + strikethrough effect
                    UIView.animate(withDuration: 0.5, delay: Double(i) * 0.1, options: .curveEaseIn) {
                        card.alpha = 0.25
                        card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    }
                    // Strikethrough the label
                    if let label = card.subviews.compactMap({ $0 as? UILabel }).first {
                        UIView.transition(with: label, duration: 0.3, options: .transitionCrossDissolve) {
                            label.attributedText = NSAttributedString(string: label.text ?? "", attributes: [
                                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                .foregroundColor: DesignTokens.Colors.textTertiary,
                            ])
                        }
                    }
                }
            }
        }
    }

    func stopAnimations() {
        for card in cards { card.layer.removeAllAnimations() }
    }
}
