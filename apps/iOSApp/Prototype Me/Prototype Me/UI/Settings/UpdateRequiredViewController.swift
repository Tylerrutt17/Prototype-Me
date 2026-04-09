import UIKit

/// Full-screen blocker shown when the server returns 426 Upgrade Required.
/// Directs the user to update the app before sync can resume.
class UpdateRequiredViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        setup()
    }

    private func setup() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
        let iconView = UIImageView(image: UIImage(systemName: "arrow.up.circle", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        stack.addArrangedSubview(iconView)
        stack.setCustomSpacing(DesignTokens.Spacing.lg, after: iconView)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Update Required"
        titleLabel.font = DesignTokens.Typography.title2
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        // Message
        let messageLabel = UILabel()
        messageLabel.text = "A newer version of Prototype Me is required to sync your data. Please update the app to continue."
        messageLabel.font = DesignTokens.Typography.body
        messageLabel.textColor = DesignTokens.Colors.textSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        stack.addArrangedSubview(messageLabel)
        stack.setCustomSpacing(DesignTokens.Spacing.xl, after: messageLabel)

        // Update button
        var btnConfig = UIButton.Configuration.filled()
        btnConfig.title = "Update Now"
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
        let updateButton = UIButton(configuration: btnConfig)
        updateButton.addTarget(self, action: #selector(openAppStore), for: .touchUpInside)
        stack.addArrangedSubview(updateButton)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor,
                constant: DesignTokens.Spacing.xl
            ),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -DesignTokens.Spacing.xl
            ),
        ])
    }

    @objc private func openAppStore() {
        // Replace with your actual App Store URL once live
        if let url = URL(string: "https://apps.apple.com/app/id6761582427") {
            UIApplication.shared.open(url)
        }
    }
}
