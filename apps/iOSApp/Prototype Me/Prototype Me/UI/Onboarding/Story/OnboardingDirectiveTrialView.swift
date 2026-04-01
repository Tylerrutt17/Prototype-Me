import UIKit

/// Onboarding visual: starts with many directive cards, then cuts the ones that
/// don't work (fade + strikethrough), leaving the winners glowing green.
/// Shows the trial-and-error process of finding what works.
final class OnboardingDirectiveTrialView: UIView, StoryAnimatable {

    private var cards: [UIView] = []
    private let titleBadge = UILabel()
    private let cardsStack = UIStackView()

    // (text, sticks)
    private let items: [(text: String, sticks: Bool)] = [
        ("Wake up at 5am", false),
        ("Meditate 10 min", true),
        ("Cold showers", false),
        ("Journal before bed", true),
        ("No sugar", false),
        ("Exercise 3x/week", true),
        ("Read for 30 min", false),
    ]

    var prefersFullWidth: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        // "DIRECTIVES" title badge — shows first, then fades
        titleBadge.text = "DIRECTIVES"
        titleBadge.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleBadge.textColor = DesignTokens.Colors.accent
        titleBadge.textAlignment = .center
        titleBadge.alpha = 0
        titleBadge.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        titleBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleBadge)

        NSLayoutConstraint.activate([
            titleBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Cards stack — hidden initially, appears after title fades
        cardsStack.axis = .vertical
        cardsStack.spacing = DesignTokens.Spacing.sm
        cardsStack.alignment = .fill
        cardsStack.alpha = 0
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardsStack)

        NSLayoutConstraint.activate([
            cardsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            cardsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        for item in items {
            let card = makeCard(text: item.text)
            cardsStack.addArrangedSubview(card)
            cards.append(card)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 12)
        }
    }

    private func makeCard(text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.5)
        pill.layer.cornerRadius = DesignTokens.Radii.md
        pill.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: "arrow.right.circle.fill", withConfiguration: iconConfig))
        icon.tintColor = DesignTokens.Colors.textTertiary
        icon.contentMode = .scaleAspectFit
        icon.tag = 10

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        label.textColor = DesignTokens.Colors.textPrimary

        let row = UIStackView(arrangedSubviews: [icon, label, UIView()])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(row)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20),
            row.topAnchor.constraint(equalTo: pill.topAnchor, constant: inset),
            row.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -inset),
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.md),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        return pill
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        // Reset
        titleBadge.alpha = 0
        titleBadge.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        cardsStack.alpha = 0
        for card in cards {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 12)
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            titleBadge.alpha = 0
            cardsStack.alpha = 1
            for card in cards { card.alpha = 1; card.transform = .identity }
            return
        }

        // Phase 1: "DIRECTIVES" title scales in
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3) {
            self.titleBadge.alpha = 1
            self.titleBadge.transform = .identity
        }

        // Phase 2: Title fades out, cards appear one by one
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }

            UIView.animate(withDuration: 0.3) {
                self.titleBadge.alpha = 0
            }
            UIView.animate(withDuration: 0.2, delay: 0.2) {
                self.cardsStack.alpha = 1
            }

            for (i, card) in self.cards.enumerated() {
                UIView.animate(
                    withDuration: 0.4,
                    delay: 0.3 + Double(i) * 0.12,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.3
                ) {
                    card.alpha = 1
                    card.transform = .identity
                }
            }
        }
    }

    func stopAnimations() {
        titleBadge.layer.removeAllAnimations()
        for card in cards { card.layer.removeAllAnimations() }
    }
}
