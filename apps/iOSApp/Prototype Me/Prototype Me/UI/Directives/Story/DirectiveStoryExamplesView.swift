import UIKit

/// Page 1 visual: a few static example directive cards that gently fade in,
/// giving the user an immediate sense of what directives look like.
final class DirectiveStoryExamplesView: UIView, StoryAnimatable {

    private struct Example {
        let title: String
        let body: String
        let colorHex: String
    }

    private let examples: [Example] = [
        Example(title: "No screens after 10pm", body: "Wind down and let your brain rest.", colorHex: "#5E5CE6"),
        Example(title: "Walk after lunch", body: "Fresh air to beat the afternoon slump.", colorHex: "#34C759"),
        Example(title: "Journal every morning", body: "Clear your head before the day starts.", colorHex: "#FF9F0A"),
    ]

    private var cards: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])

        for example in examples {
            let card = makeCard(for: example)
            stack.addArrangedSubview(card)
            cards.append(card)
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 10)
        }
    }

    private func makeCard(for example: Example) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = DesignTokens.Colors.surfacePrimary
        wrapper.layer.cornerRadius = DesignTokens.Radii.md
        wrapper.clipsToBounds = true

        let colorBar = UIView()
        colorBar.backgroundColor = UIColor(hex: example.colorHex) ?? .systemPurple
        colorBar.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(colorBar)

        let title = UILabel()
        title.text = example.title
        title.font = DesignTokens.Typography.headline
        title.textColor = DesignTokens.Colors.textPrimary
        title.numberOfLines = 0
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: chevronConfig))
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [title, chevron])
        titleRow.axis = .horizontal
        titleRow.spacing = DesignTokens.Spacing.sm
        titleRow.alignment = .center

        let body = UILabel()
        body.text = example.body
        body.font = DesignTokens.Typography.caption1
        body.textColor = DesignTokens.Colors.textSecondary
        body.numberOfLines = 2

        let contentStack = UIStackView(arrangedSubviews: [titleRow, body])
        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.xs
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(contentStack)

        NSLayoutConstraint.activate([
            colorBar.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: wrapper.topAnchor),
            colorBar.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 4),

            contentStack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: DesignTokens.Spacing.md),
            contentStack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -DesignTokens.Spacing.md),
            contentStack.leadingAnchor.constraint(equalTo: colorBar.trailingAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return wrapper
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for card in cards { card.alpha = 1; card.transform = .identity }
            return
        }

        for (i, card) in cards.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.15 + Double(i) * 0.15,
                usingSpringWithDamping: 0.8,
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
