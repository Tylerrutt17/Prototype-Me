import UIKit

/// Page 4 visual: shows the AI brainstorming flow — you describe a problem,
/// the AI suggests directives to try.
final class DirectiveStoryToolsView: UIView, StoryAnimatable {

    private var allViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])

        // User message bubble
        let userBubble = makeUserBubble("I can't stay focused at work and I keep getting distracted")
        stack.addArrangedSubview(userBubble)
        allViews.append(userBubble)

        // AI response label
        let aiLabel = UILabel()
        aiLabel.text = "Here are some directives to try:"
        aiLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiLabel.textColor = DesignTokens.Colors.textSecondary
        stack.addArrangedSubview(aiLabel)
        allViews.append(aiLabel)

        // Suggested directive cards
        let suggestions: [(title: String, body: String, color: String)] = [
            ("Phone in another room while working", "Remove the temptation entirely.", "#5E5CE6"),
            ("Work in 25-min focused blocks", "Short sprints with breaks in between.", "#FF9500"),
        ]

        for suggestion in suggestions {
            let card = makeDirectiveCard(title: suggestion.title, body: suggestion.body, colorHex: suggestion.color)
            stack.addArrangedSubview(card)
            allViews.append(card)
        }

        for v in allViews {
            v.alpha = 0
            v.transform = CGAffineTransform(translationX: 0, y: 12)
        }
    }

    private func makeUserBubble(_ text: String) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
        wrapper.layer.cornerRadius = DesignTokens.Radii.lg
        wrapper.layer.borderWidth = 1
        wrapper.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.25).cgColor

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: "mic.fill", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = "\"\(text)\""
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        label.textColor = DesignTokens.Colors.textPrimary
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(row)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -pad),
        ])

        return wrapper
    }

    private func makeDirectiveCard(title: String, body: String, colorHex: String) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = DesignTokens.Colors.surfacePrimary
        wrapper.layer.cornerRadius = DesignTokens.Radii.md
        wrapper.clipsToBounds = true

        let colorBar = UIView()
        colorBar.backgroundColor = UIColor(hex: colorHex) ?? .systemPurple
        colorBar.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(colorBar)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.headline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: chevronConfig))
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, chevron])
        titleRow.axis = .horizontal
        titleRow.spacing = DesignTokens.Spacing.sm
        titleRow.alignment = .center

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 2

        let contentStack = UIStackView(arrangedSubviews: [titleRow, bodyLabel])
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
            for v in allViews { v.alpha = 1; v.transform = .identity }
            return
        }

        for (i, view) in allViews.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.15 + Double(i) * 0.25,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for v in allViews { v.layer.removeAllAnimations() }
    }
}
