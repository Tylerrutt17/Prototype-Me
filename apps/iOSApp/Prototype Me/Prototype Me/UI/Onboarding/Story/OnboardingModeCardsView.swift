import UIKit

/// Page 5: Mock mode cards with one getting selected with purple shimmer.
final class OnboardingModeCardsView: UIView, StoryAnimatable {

    private var modeCards: [UIView] = []
    private let modeColor = NoteKind.mode.color

    private let modes = ["Deep Work", "Recovery", "Social"]

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

        for (i, name) in modes.enumerated() {
            let card = makeModeCard(title: name, index: i)
            stack.addArrangedSubview(card)
            modeCards.append(card)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: -30, y: 0)
        }
    }

    private func makeModeCard(title: String, index: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfaceSecondary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.layer.borderWidth = 1.5
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor
        card.clipsToBounds = false
        card.tag = 100 + index

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let icon = UIImageView(image: UIImage(systemName: "bolt.fill", withConfiguration: iconConfig))
        icon.tintColor = DesignTokens.Colors.textTertiary
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = title
        label.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let check = UIImageView(image: UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig))
        check.tintColor = modeColor
        check.alpha = 0
        check.tag = 200

        let row = UIStackView(arrangedSubviews: [icon, label, UIView(), check])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        return card
    }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for card in modeCards { card.alpha = 1; card.transform = .identity }
            selectCard(at: 0, animated: false)
            return
        }

        // Cards slide in from left
        for (i, card) in modeCards.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.1 + Double(i) * 0.12,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.3
            ) {
                card.alpha = 1
                card.transform = .identity
            }
        }

        // After cards settle, select the first one
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.selectCard(at: 0, animated: true)
        }
    }

    func stopAnimations() {
        for card in modeCards { card.layer.removeAllAnimations() }
    }

    private func selectCard(at index: Int, animated: Bool) {
        guard index < modeCards.count else { return }
        let card = modeCards[index]
        let mc = modeColor

        if animated {
            // Spring pop
            card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 10) {
                card.transform = .identity
            }

            UIView.animate(withDuration: 0.3) {
                card.backgroundColor = mc.withAlphaComponent(0.08)
                card.layer.borderColor = mc.cgColor
            }

            // Checkmark
            if let check = card.viewWithTag(200) as? UIImageView {
                check.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
                UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.5, initialSpringVelocity: 12) {
                    check.alpha = 1
                    check.transform = .identity
                }
            }

            // Shimmer border after a beat
            DispatchQueue.main.async {
                ShimmerBorder.add(to: card, color: mc, cornerRadius: DesignTokens.Radii.lg)
            }

            Haptics.selection()
        } else {
            card.backgroundColor = mc.withAlphaComponent(0.08)
            card.layer.borderColor = mc.cgColor
            if let check = card.viewWithTag(200) as? UIImageView {
                check.alpha = 1
            }
        }
    }
}
