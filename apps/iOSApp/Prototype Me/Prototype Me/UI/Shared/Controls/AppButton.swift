import UIKit

/// Standard app button with style variants.
class AppButton: UIButton {

    enum Style {
        case primary
        case secondary
        case destructive
    }

    init(title: String, style: Style = .primary) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        configureStyle(style)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureStyle(_ style: Style) {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.md,
            leading: DesignTokens.Spacing.xl,
            bottom: DesignTokens.Spacing.md,
            trailing: DesignTokens.Spacing.xl
        )
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DesignTokens.Typography.headline
            return outgoing
        }

        switch style {
        case .primary:
            config.baseBackgroundColor = DesignTokens.Colors.accent
            config.baseForegroundColor = .white
        case .secondary:
            config.baseBackgroundColor = DesignTokens.Colors.surfaceSecondary
            config.baseForegroundColor = DesignTokens.Colors.accent
        case .destructive:
            config.baseBackgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.15)
            config.baseForegroundColor = DesignTokens.Colors.destructive
        }

        configuration = config
    }
}
