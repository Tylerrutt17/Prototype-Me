import UIKit
import GRDB

/// Lightweight base for all view controllers in the app.
/// Provides dark-theme background, DB access, observation lifecycle, and custom nav bar.
class BaseViewController: UIViewController {

    /// Set by the coordinator before presenting. Provides database access.
    var dbQueue: DatabaseQueue!

    /// Active GRDB observation cancellables — cancelled automatically on deinit.
    var observationCancellable: AnyDatabaseCancellable?

    /// Custom navigation bar — use instead of `navigationItem`.
    let navBar = AppNavBar()

    /// When true, nav bar is removed and content starts at the top of the view.
    var hidesNavBar = false

    /// Anchor subclass content to this instead of `view.safeAreaLayoutGuide.topAnchor`.
    var contentTopAnchor: NSLayoutYAxisAnchor {
        hidesNavBar ? view.topAnchor : navBar.bottomAnchor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        installNavBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        guard !hidesNavBar else { return }
        let shouldShowBack = (navigationController?.viewControllers.count ?? 0) > 1
        navBar.setShowsBackButton(shouldShowBack)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // When the system nav bar is hidden, its gesture recognizer delegate
        // blocks the swipe-back gesture. Clearing the delegate fixes this.
        // Only enable on non-root VCs to avoid a frozen UI state.
        if let nav = navigationController {
            let isPushed = nav.viewControllers.count > 1
            nav.interactivePopGestureRecognizer?.isEnabled = isPushed
            nav.interactivePopGestureRecognizer?.delegate = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hidesNavBar { view.bringSubviewToFront(navBar) }
    }

    private func installNavBar() {
        guard !hidesNavBar else { return }
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)

        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        navBar.onBackTapped = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
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
