import UIKit

/// A reusable empty state view with an icon, message, and optional CTA button.
/// Configured per-screen with different content.
class EmptyStateView: UIView {

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)

    var onAction: (() -> Void)?

    init(icon: String, title: String, message: String, buttonTitle: String? = nil) {
        super.init(frame: .zero)
        setup(icon: icon, title: title, message: message, buttonTitle: buttonTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(icon: String, title: String, message: String, buttonTitle: String?) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
        iconImageView.tintColor = DesignTokens.Colors.textTertiary
        iconImageView.contentMode = .scaleAspectFit
        stack.addArrangedSubview(iconImageView)
        stack.setCustomSpacing(DesignTokens.Spacing.lg, after: iconImageView)

        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.title3
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        messageLabel.text = message
        messageLabel.font = DesignTokens.Typography.body
        messageLabel.textColor = DesignTokens.Colors.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        stack.addArrangedSubview(messageLabel)

        if let buttonTitle {
            var btnConfig = UIButton.Configuration.filled()
            btnConfig.title = buttonTitle
            btnConfig.baseBackgroundColor = DesignTokens.Colors.accent
            btnConfig.baseForegroundColor = .white
            btnConfig.cornerStyle = .medium
            btnConfig.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.md,
                leading: DesignTokens.Spacing.xl,
                bottom: DesignTokens.Spacing.md,
                trailing: DesignTokens.Spacing.xl
            )
            btnConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = DesignTokens.Typography.headline
                return outgoing
            }
            actionButton.configuration = btnConfig
            actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            stack.setCustomSpacing(DesignTokens.Spacing.xl, after: messageLabel)
            stack.addArrangedSubview(actionButton)
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor,
                constant: DesignTokens.Spacing.xl
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -DesignTokens.Spacing.xl
            )
        ])
    }

    @objc private func actionTapped() {
        onAction?()
    }
}
