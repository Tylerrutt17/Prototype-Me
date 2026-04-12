import UIKit

/// "Welcome back" screen shown to returning users while sync pulls their data.
final class SyncLoadingViewController: UIViewController {

    var syncTask: (() async throws -> Void)?
    var onComplete: (() -> Void)?

    // MARK: - Background

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,
        ]
        layer.locations = [0.0, 0.45, 1.0]
        return layer
    }()

    private let blueprintGrid = BlueprintGridView()

    // MARK: - Content

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let trackView = UIView()
    private let shimmerLayer = CAGradientLayer()
    private let retryButton = UIButton(type: .system)
    private let errorIcon = UIImageView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        view.layer.addSublayer(gradientLayer)
        blueprintGrid.frame = view.bounds
        blueprintGrid.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(blueprintGrid)
        buildLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        shimmerLayer.frame = trackView.bounds
        CATransaction.commit()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateEntrance()
        blueprintGrid.startAnimating()
        startSync()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        blueprintGrid.stopAnimating()
    }

    // MARK: - Layout

    private func buildLayout() {
        // Title
        titleLabel.text = "Welcome Back"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status
        statusLabel.text = "Restoring your data..."
        statusLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .regular)
        statusLabel.textColor = DesignTokens.Colors.textSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.alpha = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Indeterminate progress track
        trackView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        trackView.layer.cornerRadius = 3
        trackView.clipsToBounds = true
        trackView.alpha = 0
        trackView.translatesAutoresizingMaskIntoConstraints = false

        // Shimmer gradient inside the track
        shimmerLayer.colors = [
            DesignTokens.Colors.accent.withAlphaComponent(0.0).cgColor,
            DesignTokens.Colors.accent.withAlphaComponent(0.6).cgColor,
            DesignTokens.Colors.accent.withAlphaComponent(0.0).cgColor,
        ]
        shimmerLayer.locations = [0, 0.5, 1.0]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        trackView.layer.addSublayer(shimmerLayer)

        // Error icon (hidden by default)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        errorIcon.image = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: iconConfig)
        errorIcon.tintColor = DesignTokens.Colors.warning
        errorIcon.contentMode = .scaleAspectFit
        errorIcon.alpha = 0
        errorIcon.translatesAutoresizingMaskIntoConstraints = false

        // Retry button (hidden by default)
        var retryConfig = UIButton.Configuration.filled()
        retryConfig.title = "Try Again"
        retryConfig.image = UIImage(systemName: "arrow.clockwise")
        retryConfig.imagePadding = DesignTokens.Spacing.sm
        retryConfig.cornerStyle = .capsule
        retryConfig.baseBackgroundColor = DesignTokens.Colors.accent
        retryConfig.baseForegroundColor = .white
        retryButton.configuration = retryConfig
        retryButton.alpha = 0
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(trackView)
        view.addSubview(errorIcon)
        view.addSubview(retryButton)

        NSLayoutConstraint.activate([
            errorIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorIcon.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -DesignTokens.Spacing.lg),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            trackView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: DesignTokens.Spacing.xl),
            trackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            trackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            trackView.heightAnchor.constraint(equalToConstant: 4),

            retryButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: DesignTokens.Spacing.xl),
            retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            retryButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    // MARK: - Animation

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            titleLabel.alpha = 1
            statusLabel.alpha = 1
            trackView.alpha = 1
            startShimmer()
            return
        }

        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.5, delay: 0.4, options: .curveEaseOut) {
            self.statusLabel.alpha = 1
        }

        UIView.animate(withDuration: 0.4, delay: 0.6, options: .curveEaseOut) {
            self.trackView.alpha = 1
        } completion: { _ in
            self.startShimmer()
        }
    }

    private func startShimmer() {
        let anim = CABasicAnimation(keyPath: "position.x")
        let trackWidth = UIScreen.main.bounds.width - 120
        anim.fromValue = -trackWidth * 0.3
        anim.toValue = trackWidth * 1.3
        anim.duration = 1.2
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerLayer.add(anim, forKey: "shimmer")
    }

    // MARK: - Sync

    private func startSync() {
        // Pre-flight storage check
        if !StorageMonitor.canSafelyWrite {
            showError(isStorageFull: true)
            return
        }

        Task {
            do {
                try await syncTask?()
                await MainActor.run { showComplete() }
            } catch {
                await MainActor.run {
                    let isStorage = (error as NSError).domain == "GRDB.DatabaseError" && (error as NSError).code == 13
                    showError(isStorageFull: isStorage)
                }
            }
        }
    }

    private func showComplete() {
        shimmerLayer.removeAllAnimations()

        UIView.animate(withDuration: 0.3) {
            self.trackView.backgroundColor = DesignTokens.Colors.success
            self.shimmerLayer.opacity = 0
        }

        statusLabel.text = "You're all set!"
        Haptics.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.onComplete?()
        }
    }

    private func showError(isStorageFull: Bool) {
        shimmerLayer.removeAllAnimations()
        Haptics.error()

        titleLabel.text = isStorageFull ? "Storage Full" : "Couldn't Sync"
        statusLabel.text = isStorageFull
            ? "Your device doesn't have enough space to restore your data. Free up storage in Settings, then come back and try again."
            : "Something went wrong while restoring your data. Check your connection and try again."

        UIView.animate(withDuration: 0.3) {
            self.trackView.alpha = 0
            self.errorIcon.alpha = 1
            self.retryButton.alpha = 1
        }
    }

    @objc private func retryTapped() {
        // Reset to loading state
        titleLabel.text = "Welcome Back"
        statusLabel.text = "Restoring your data..."

        UIView.animate(withDuration: 0.3) {
            self.errorIcon.alpha = 0
            self.retryButton.alpha = 0
            self.trackView.alpha = 1
        } completion: { _ in
            self.startShimmer()
            self.startSync()
        }
    }

}
