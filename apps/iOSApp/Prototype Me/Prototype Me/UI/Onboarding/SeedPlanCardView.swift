import UIKit

/// Card view for displaying a seed plan item (directive or playbook) during onboarding.
final class SeedPlanCardView: UIView {

    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        // Glass background
        let glass = GlassPanelView(cornerRadius: DesignTokens.Radii.lg)
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)

        // Accent bar
        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBar)

        // Icon
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = DesignTokens.Colors.textSecondary
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1

        // Body
        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xxs

        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack])
        contentStack.axis = .horizontal
        contentStack.spacing = DesignTokens.Spacing.md
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),

            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.sm),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.sm),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.lg),
            contentStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with card: SeedPlanCard) {
        titleLabel.text = card.title
        bodyLabel.text = card.body

        switch card.type {
        case .directive:
            accentBar.backgroundColor = DesignTokens.Colors.accent
            iconView.image = UIImage(systemName: "arrow.right.circle")
            iconView.tintColor = DesignTokens.Colors.accent
        case .folder:
            accentBar.backgroundColor = DesignTokens.Colors.accentSecondary
            iconView.image = UIImage(systemName: "folder.fill")
            iconView.tintColor = DesignTokens.Colors.accentSecondary
        }
    }
}
