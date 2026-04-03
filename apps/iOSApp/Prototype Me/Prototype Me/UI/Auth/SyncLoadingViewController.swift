import UIKit

/// "Welcome back" screen shown to returning users while sync pulls their data.
final class SyncLoadingViewController: UIViewController {

    var syncTask: (() async -> Void)?
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

        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(trackView)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            trackView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: DesignTokens.Spacing.xl),
            trackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            trackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            trackView.heightAnchor.constraint(equalToConstant: 4),
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
        Task {
            await syncTask?()
            await MainActor.run {
                showComplete()
            }
        }
    }

    private func showComplete() {
        shimmerLayer.removeAllAnimations()

        // Fill the track solid green
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
}
