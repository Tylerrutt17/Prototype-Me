import UIKit

/// Shown when DatabaseManager fails to initialize (migration error, corruption, etc.).
/// Replaces the crash-on-launch behavior so the user sees an explanation and can report the issue.
final class DatabaseRecoveryViewController: UIViewController {

    private let error: Error
    var onRetrySuccess: ((AppEnvironment) -> Void)?

    init(error: Error) {
        self.error = error
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = DesignTokens.Colors.warning
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Something Went Wrong"
        titleLabel.font = DesignTokens.Typography.title2
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.text = "The app couldn't start properly. This is usually temporary — try closing and reopening the app, or freeing up storage space.\n\nIf this keeps happening, tap Report Issue so we can fix it."
        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        let retryButton = makePrimaryButton(title: "Try Again", action: #selector(retryTapped))
        let reportButton = makeSecondaryButton(title: "Report Issue", action: #selector(reportTapped))

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, bodyLabel, retryButton, reportButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.lg
        stack.setCustomSpacing(DesignTokens.Spacing.xxl, after: bodyLabel)
        stack.setCustomSpacing(DesignTokens.Spacing.md, after: retryButton)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),
            retryButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            retryButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            reportButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            reportButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func retryTapped() {
        do {
            let environment = try AppEnvironment.live()
            onRetrySuccess?(environment)
        } catch {
            // Still failing — shake the button to indicate failure
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.duration = 0.4
            animation.values = [-8, 8, -6, 6, -3, 3, 0]
            view.subviews.first?.layer.add(animation, forKey: "shake")
        }
    }

    @objc private func reportTapped() {
        SupportMailer.presentErrorReport(from: self, error: error)
    }

    // MARK: - Button Helpers

    private func makePrimaryButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = DesignTokens.Typography.headline
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DesignTokens.Colors.accent
        button.layer.cornerRadius = DesignTokens.Radii.md
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeSecondaryButton(title: String, action: Selector) -> UIButton {
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
}
