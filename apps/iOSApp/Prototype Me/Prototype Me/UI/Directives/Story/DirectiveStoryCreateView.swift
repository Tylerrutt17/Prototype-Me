import UIKit

/// Page 2 visual: shows a problem label, then a directive card appears as the solution.
/// Simple two-step animation: problem → directive.
final class DirectiveStoryCreateView: UIView, StoryAnimatable {

    // MARK: - Content

    private let problemText = "I can't fall asleep at night…"

    // MARK: - UI

    private let problemIcon = UIImageView()
    private let problemLabel = UILabel()
    private let arrowIcon = UIImageView()
    private let directiveCard = UIView()
    private var allViews: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        // Problem row
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        problemIcon.image = UIImage(systemName: "cloud.fill", withConfiguration: iconConfig)
        problemIcon.tintColor = .systemPurple
        problemIcon.contentMode = .scaleAspectFit
        problemIcon.setContentHuggingPriority(.required, for: .horizontal)

        problemLabel.text = problemText
        problemLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        problemLabel.textColor = DesignTokens.Colors.textPrimary
        problemLabel.numberOfLines = 0

        let problemRow = UIStackView(arrangedSubviews: [problemIcon, problemLabel])
        problemRow.axis = .horizontal
        problemRow.spacing = DesignTokens.Spacing.md
        problemRow.alignment = .center

        let problemWrapper = UIView()
        problemWrapper.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        problemWrapper.layer.cornerRadius = DesignTokens.Radii.lg
        problemWrapper.layer.borderWidth = 1
        problemWrapper.layer.borderColor = UIColor.systemPurple.withAlphaComponent(0.25).cgColor
        problemRow.translatesAutoresizingMaskIntoConstraints = false
        problemWrapper.addSubview(problemRow)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            problemRow.topAnchor.constraint(equalTo: problemWrapper.topAnchor, constant: pad),
            problemRow.bottomAnchor.constraint(equalTo: problemWrapper.bottomAnchor, constant: -pad),
            problemRow.leadingAnchor.constraint(equalTo: problemWrapper.leadingAnchor, constant: pad),
            problemRow.trailingAnchor.constraint(equalTo: problemWrapper.trailingAnchor, constant: -pad),
        ])

        // Arrow
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        arrowIcon.image = UIImage(systemName: "arrow.down", withConfiguration: arrowConfig)
        arrowIcon.tintColor = DesignTokens.Colors.textTertiary
        arrowIcon.contentMode = .scaleAspectFit

        // Directive card (mirrors DirectiveCell)
        buildDirectiveCard()

        // Stack
        let stack = UIStackView(arrangedSubviews: [problemWrapper, arrowIcon, directiveCard])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            arrowIcon.heightAnchor.constraint(equalToConstant: 20),
        ])

        allViews = [problemWrapper, arrowIcon, directiveCard]
        for v in allViews {
            v.alpha = 0
            v.transform = CGAffineTransform(translationX: 0, y: 10)
        }
    }

    private func buildDirectiveCard() {
        directiveCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        directiveCard.layer.cornerRadius = DesignTokens.Radii.md
        directiveCard.clipsToBounds = true

        let colorBar = UIView()
        colorBar.backgroundColor = UIColor(hex: "#5E5CE6") ?? .systemPurple
        colorBar.translatesAutoresizingMaskIntoConstraints = false
        directiveCard.addSubview(colorBar)

        let title = UILabel()
        title.text = "No screens after 10pm"
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
        body.text = "Wind down and let your brain rest."
        body.font = DesignTokens.Typography.caption1
        body.textColor = DesignTokens.Colors.textSecondary
        body.numberOfLines = 2

        let contentStack = UIStackView(arrangedSubviews: [titleRow, body])
        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.xs
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        directiveCard.addSubview(contentStack)

        NSLayoutConstraint.activate([
            colorBar.leadingAnchor.constraint(equalTo: directiveCard.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: directiveCard.topAnchor),
            colorBar.bottomAnchor.constraint(equalTo: directiveCard.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 4),

            contentStack.topAnchor.constraint(equalTo: directiveCard.topAnchor, constant: DesignTokens.Spacing.md),
            contentStack.bottomAnchor.constraint(equalTo: directiveCard.bottomAnchor, constant: -DesignTokens.Spacing.md),
            contentStack.leadingAnchor.constraint(equalTo: colorBar.trailingAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: directiveCard.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for v in allViews { v.alpha = 1; v.transform = .identity }
            return
        }

        // Problem fades in first
        UIView.animate(
            withDuration: 0.5,
            delay: 0.2,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3
        ) {
            self.allViews[0].alpha = 1
            self.allViews[0].transform = .identity
        }

        // Arrow
        UIView.animate(
            withDuration: 0.4,
            delay: 0.8,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.3
        ) {
            self.allViews[1].alpha = 1
            self.allViews[1].transform = .identity
        }

        // Directive card slides in
        UIView.animate(
            withDuration: 0.6,
            delay: 1.2,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.4
        ) {
            self.allViews[2].alpha = 1
            self.allViews[2].transform = .identity
        }
    }

    func stopAnimations() {
        for v in allViews { v.layer.removeAllAnimations() }
    }
}
