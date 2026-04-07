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
        observeStorageWarnings()
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

    // MARK: - Storage & Error Banners

    private var storageBanner: UIView?
    private var toastView: UIView?
    private var toastDismissWork: DispatchWorkItem?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: StorageMonitor.storageWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: StorageMonitor.writeFailedNotification, object: nil)
    }

    /// Call from subclass viewDidLoad (after super) to opt into storage/error monitoring.
    func observeStorageWarnings() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleStorageWarning(_:)),
            name: StorageMonitor.storageWarningNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleWriteFailed(_:)),
            name: StorageMonitor.writeFailedNotification, object: nil
        )
        // Check immediately
        if StorageMonitor.isStorageLow {
            showStorageBanner(availableMB: StorageMonitor.availableMB)
        }
    }

    @objc private func handleStorageWarning(_ notification: Notification) {
        let mb = notification.userInfo?["availableMB"] as? Int ?? StorageMonitor.availableMB
        DispatchQueue.main.async { [weak self] in
            self?.showStorageBanner(availableMB: mb)
        }
    }

    @objc private func handleWriteFailed(_ notification: Notification) {
        let message = notification.userInfo?["message"] as? String ?? "Save failed"
        DispatchQueue.main.async { [weak self] in
            self?.showToast(message)
        }
    }

    private func showStorageBanner(availableMB: Int) {
        guard storageBanner == nil else { return }

        let banner = UIView()
        banner.backgroundColor = DesignTokens.Colors.warning.withAlphaComponent(0.15)
        banner.layer.cornerRadius = DesignTokens.Radii.md
        banner.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = DesignTokens.Colors.warning
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.font = DesignTokens.Typography.footnote
        label.textColor = DesignTokens.Colors.textPrimary
        label.numberOfLines = 0
        if availableMB <= 10 {
            label.text = "Device storage critically low (\(availableMB) MB). Saves may fail."
        } else {
            label.text = "Device storage is low (\(availableMB) MB free). Free up space to avoid data loss."
        }

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        banner.addSubview(stack)
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: banner.topAnchor, constant: DesignTokens.Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -DesignTokens.Spacing.md),

            banner.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.sm),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        banner.alpha = 0
        UIView.animate(withDuration: 0.3) { banner.alpha = 1 }
        storageBanner = banner
    }

    func removeStorageBanner() {
        guard let banner = storageBanner else { return }
        UIView.animate(withDuration: 0.3, animations: { banner.alpha = 0 }) { _ in
            banner.removeFromSuperview()
        }
        storageBanner = nil
    }

    private func showToast(_ message: String) {
        // Remove existing toast
        toastDismissWork?.cancel()
        toastView?.removeFromSuperview()

        let toast = UIView()
        toast.backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.9)
        toast.layer.cornerRadius = DesignTokens.Radii.md
        toast.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.font = DesignTokens.Typography.footnote
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        toast.addSubview(label)
        view.addSubview(toast)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: DesignTokens.Spacing.md),
            label.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -DesignTokens.Spacing.md),
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: DesignTokens.Spacing.lg),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -DesignTokens.Spacing.lg),

            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            toast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            toast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.3) {
            toast.alpha = 1
            toast.transform = .identity
        }
        toastView = toast

        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.3, animations: {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 20)
            }) { _ in
                toast.removeFromSuperview()
                if self?.toastView === toast { self?.toastView = nil }
            }
        }
        toastDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    // MARK: - Loading Helpers

    func showLoadingState() {
        // TODO: Add inline spinner
    }

    func hideLoadingState() {
        // TODO: Remove inline spinner
    }

    func showError(_ error: Error) {
        StorageMonitor.handleWriteError(error)
    }
}
