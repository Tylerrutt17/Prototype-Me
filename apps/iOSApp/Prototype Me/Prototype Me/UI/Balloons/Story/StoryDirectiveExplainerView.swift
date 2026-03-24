import UIKit

/// Page 2 visual: a mock directive card with a balloon toggle that animates on,
/// showing users where balloons are activated.
final class StoryDirectiveExplainerView: UIView, StoryAnimatable {

    private let mockCard = UIView()
    private let toggle = UISwitch()
    private let detailStack = UIStackView()
    private let arrowLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildMockCard()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildMockCard() {
        // Mock directive card
        mockCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        mockCard.layer.cornerRadius = DesignTokens.Radii.lg
        mockCard.layer.borderWidth = 1
        mockCard.layer.borderColor = DesignTokens.Colors.separator.cgColor
        mockCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mockCard)

        // "DIRECTIVE" label above the card
        let directiveLabel = UILabel()
        directiveLabel.text = "Inside a directive..."
        directiveLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        directiveLabel.textColor = DesignTokens.Colors.textTertiary
        directiveLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(directiveLabel)

        // Section header inside card
        let sectionLabel = UILabel()
        sectionLabel.text = "BALLOON / TIMER"
        sectionLabel.font = DesignTokens.Typography.caption1
        sectionLabel.textColor = DesignTokens.Colors.textSecondary

        // Header row: icon + title + toggle
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: "timer", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.warning
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Enable Balloon / Timer"
        titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        toggle.isOn = false
        toggle.onTintColor = DesignTokens.Colors.accent
        toggle.isUserInteractionEnabled = false
        toggle.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), toggle])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.sm
        headerRow.alignment = .center

        // Duration row (hidden initially, revealed on toggle)
        let durationTitle = UILabel()
        durationTitle.text = "DURATION"
        durationTitle.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        durationTitle.textColor = DesignTokens.Colors.textTertiary

        let durationValue = UILabel()
        durationValue.text = "24 hours"
        durationValue.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        durationValue.textColor = DesignTokens.Colors.textPrimary

        detailStack.axis = .vertical
        detailStack.spacing = DesignTokens.Spacing.xs
        detailStack.addArrangedSubview(durationTitle)
        detailStack.addArrangedSubview(durationValue)
        detailStack.isHidden = true
        detailStack.alpha = 0

        // Stack inside card
        let cardStack = UIStackView(arrangedSubviews: [sectionLabel, headerRow, detailStack])
        cardStack.axis = .vertical
        cardStack.spacing = DesignTokens.Spacing.md
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        mockCard.addSubview(cardStack)

        // Arrow pointing up at the toggle, placed below the card
        arrowLabel.text = "↑ Tap to activate"
        arrowLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        arrowLabel.textColor = DesignTokens.Colors.accent
        arrowLabel.alpha = 0
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrowLabel)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            directiveLabel.bottomAnchor.constraint(equalTo: mockCard.topAnchor, constant: -DesignTokens.Spacing.sm),
            directiveLabel.leadingAnchor.constraint(equalTo: mockCard.leadingAnchor, constant: DesignTokens.Spacing.xs),

            mockCard.centerYAnchor.constraint(equalTo: centerYAnchor, constant: DesignTokens.Spacing.md),
            mockCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            mockCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),

            cardStack.topAnchor.constraint(equalTo: mockCard.topAnchor, constant: pad),
            cardStack.bottomAnchor.constraint(equalTo: mockCard.bottomAnchor, constant: -pad),
            cardStack.leadingAnchor.constraint(equalTo: mockCard.leadingAnchor, constant: pad),
            cardStack.trailingAnchor.constraint(equalTo: mockCard.trailingAnchor, constant: -pad),

            arrowLabel.topAnchor.constraint(equalTo: mockCard.bottomAnchor, constant: DesignTokens.Spacing.md),
            arrowLabel.centerXAnchor.constraint(equalTo: mockCard.centerXAnchor),
        ])

        // Start invisible
        mockCard.alpha = 0
        mockCard.transform = CGAffineTransform(translationX: 0, y: 15)
        directiveLabel.alpha = 0
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            mockCard.alpha = 1; mockCard.transform = .identity
            mockCard.superview?.subviews.first { $0 is UILabel && ($0 as? UILabel)?.text == "Inside a directive..." }?.alpha = 1
            toggle.isOn = true
            detailStack.isHidden = false; detailStack.alpha = 1
            return
        }

        let directiveLabel = subviews.first { ($0 as? UILabel)?.text == "Inside a directive..." }

        // Card slides up
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.mockCard.alpha = 1
            self.mockCard.transform = .identity
            directiveLabel?.alpha = 1
        }

        // Arrow hint appears
        UIView.animate(withDuration: 0.3, delay: 0.7, options: .curveEaseOut) {
            self.arrowLabel.alpha = 1
        }

        // Toggle flips on after a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.toggle.setOn(true, animated: true)
            Haptics.selection()

            // Arrow fades out
            UIView.animate(withDuration: 0.2) {
                self.arrowLabel.alpha = 0
            }

            // Duration row reveals
            UIView.animate(withDuration: 0.35, delay: 0.2, options: .curveEaseOut) {
                self.detailStack.isHidden = false
                self.detailStack.alpha = 1
            }

            // Subtle glow pulse on the card to emphasize activation
            UIView.animate(withDuration: 0.4, delay: 0.15) {
                self.mockCard.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.5).cgColor
            } completion: { _ in
                UIView.animate(withDuration: 0.6) {
                    self.mockCard.layer.borderColor = DesignTokens.Colors.separator.cgColor
                }
            }
        }
    }

    func stopAnimations() {
        mockCard.layer.removeAllAnimations()
        layer.removeAllAnimations()
    }
}
