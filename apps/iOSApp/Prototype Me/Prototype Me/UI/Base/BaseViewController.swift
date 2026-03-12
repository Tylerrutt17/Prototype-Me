import UIKit

/// Lightweight base for all view controllers in the app.
/// Provides dark-theme background and placeholder helpers for the UI shell.
class BaseViewController: UIViewController {

    // Future: var observationTokens: [DatabaseCancellable] = []
    // Future: var activeTasks: [Task<Void, Never>] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
    }

    // MARK: - Placeholder Helpers

    /// Adds a centered title + subtitle label stack for placeholder screens.
    func configurePlaceholder(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil
    ) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let systemImage {
            let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
            let imageView = UIImageView(
                image: UIImage(systemName: systemImage, withConfiguration: config)
            )
            imageView.tintColor = DesignTokens.Colors.textTertiary
            imageView.contentMode = .scaleAspectFit
            stack.addArrangedSubview(imageView)
            stack.setCustomSpacing(DesignTokens.Spacing.lg, after: imageView)
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.title2
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        stack.addArrangedSubview(titleLabel)

        if let subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = DesignTokens.Typography.body
            subtitleLabel.textColor = DesignTokens.Colors.textSecondary
            subtitleLabel.textAlignment = .center
            subtitleLabel.numberOfLines = 0
            stack.addArrangedSubview(subtitleLabel)
        }

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
            )
        ])
    }

    /// Creates a styled demo navigation button for placeholder screens.
    func makeDemoButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DesignTokens.Typography.headline
        button.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        button.backgroundColor = DesignTokens.Colors.surfacePrimary
        button.layer.cornerRadius = DesignTokens.Radii.md
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Future Loading/Error Helpers

    func showLoadingState() {
        // TODO: Add inline spinner
    }

    func hideLoadingState() {
        // TODO: Remove inline spinner
    }

    func showError(_ error: Error) {
        // TODO: Show toast/banner
    }
}
