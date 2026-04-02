import UIKit

/// "Welcome back" screen shown to returning users while sync pulls their data.
/// Displays a syncing animation and auto-dismisses when sync completes.
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

    private var waveLayers: [CAShapeLayer] = []

    // MARK: - Content

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        view.layer.addSublayer(gradientLayer)
        setupWaves()
        buildLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
        layoutWaves()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateEntrance()
        animateWaves()
        startSync()
    }

    // MARK: - Wavy Lines

    private func setupWaves() {
        let colors: [(UIColor, CGFloat)] = [
            (DesignTokens.Colors.accent, 0.12),
            (DesignTokens.Colors.accentSecondary, 0.10),
            (DesignTokens.Colors.accentTertiary, 0.08),
            (DesignTokens.Colors.accent, 0.06),
            (DesignTokens.Colors.accentSecondary, 0.05),
        ]

        for (color, alpha) in colors {
            let layer = CAShapeLayer()
            layer.strokeColor = color.withAlphaComponent(alpha).cgColor
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 2
            layer.lineCap = .round
            view.layer.insertSublayer(layer, above: gradientLayer)
            waveLayers.append(layer)
        }
    }

    private func layoutWaves() {
        let w = view.bounds.width
        let h = view.bounds.height
        guard w > 0 else { return }

        let configs: [(yCenter: CGFloat, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat, lineWidth: CGFloat)] = [
            (h * 0.20, 40, 1.5, 0.0, 2.5),
            (h * 0.30, 55, 1.0, 0.8, 2.0),
            (h * 0.45, 35, 2.0, 1.6, 1.5),
            (h * 0.65, 50, 1.2, 2.4, 2.0),
            (h * 0.78, 30, 1.8, 3.2, 1.5),
        ]

        for (i, layer) in waveLayers.enumerated() {
            guard i < configs.count else { break }
            let c = configs[i]
            layer.lineWidth = c.lineWidth
            layer.path = wavePath(width: w, yCenter: c.yCenter, amplitude: c.amplitude, frequency: c.frequency, phase: c.phase).cgPath
        }
    }

    private func wavePath(width: CGFloat, yCenter: CGFloat, amplitude: CGFloat, frequency: CGFloat, phase: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let steps = 120
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = t * width
            let y = yCenter + sin(t * frequency * 2 * .pi + phase) * amplitude
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func animateWaves() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let durations: [CFTimeInterval] = [7.0, 9.0, 6.0, 8.0, 10.0]
        let amplitudes: [CGFloat] = [40, 55, 35, 50, 30]
        let frequencies: [CGFloat] = [1.5, 1.0, 2.0, 1.2, 1.8]
        let phases: [CGFloat] = [0.0, 0.8, 1.6, 2.4, 3.2]
        let yCenters: [CGFloat] = [0.20, 0.30, 0.45, 0.65, 0.78]

        let w = view.bounds.width
        let h = view.bounds.height

        for (i, layer) in waveLayers.enumerated() {
            guard i < durations.count else { break }

            let fromPath = wavePath(
                width: w,
                yCenter: h * yCenters[i],
                amplitude: amplitudes[i],
                frequency: frequencies[i],
                phase: phases[i]
            ).cgPath

            let toPath = wavePath(
                width: w,
                yCenter: h * yCenters[i],
                amplitude: amplitudes[i] * 0.7,
                frequency: frequencies[i],
                phase: phases[i] + .pi
            ).cgPath

            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = fromPath
            anim.toValue = toPath
            anim.duration = durations[i]
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(anim, forKey: "waveShift")
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        // Icon
        let config = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
        iconView.image = UIImage(systemName: "arrow.triangle.2.circlepath", withConfiguration: config)
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.alpha = 0
        iconView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        iconView.layer.shadowColor = DesignTokens.Colors.accent.cgColor
        iconView.layer.shadowRadius = 24
        iconView.layer.shadowOpacity = 0.4
        iconView.layer.shadowOffset = .zero

        // Title
        titleLabel.text = "Welcome Back"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Status
        statusLabel.text = "Syncing your data..."
        statusLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .regular)
        statusLabel.textColor = DesignTokens.Colors.textSecondary
        statusLabel.textAlignment = .center
        statusLabel.alpha = 0
        statusLabel.transform = CGAffineTransform(translationX: 0, y: 15)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        // Spinner
        spinner.color = DesignTokens.Colors.accent
        spinner.alpha = 0
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, statusLabel, spinner])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xl
        stack.alignment = .center
        stack.setCustomSpacing(DesignTokens.Spacing.sm, after: statusLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),
        ])
    }

    // MARK: - Entrance Animation

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            iconView.alpha = 1; iconView.transform = .identity
            titleLabel.alpha = 1; titleLabel.transform = .identity
            statusLabel.alpha = 1; statusLabel.transform = .identity
            spinner.alpha = 1; spinner.startAnimating()
            startIconSpin()
            return
        }

        UIView.animate(withDuration: 0.7, delay: 0.2, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.3) {
            self.iconView.alpha = 1
            self.iconView.transform = .identity
        } completion: { _ in
            self.startIconSpin()
        }

        UIView.animate(withDuration: 0.5, delay: 0.45, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        UIView.animate(withDuration: 0.5, delay: 0.6, options: .curveEaseOut) {
            self.statusLabel.alpha = 1
            self.statusLabel.transform = .identity
        }

        UIView.animate(withDuration: 0.3, delay: 0.7, options: .curveEaseOut) {
            self.spinner.alpha = 1
        } completion: { _ in
            self.spinner.startAnimating()
        }
    }

    private func startIconSpin() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 3.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        iconView.layer.add(rotation, forKey: "spin")
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
        iconView.layer.removeAnimation(forKey: "spin")
        spinner.stopAnimating()

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
        iconView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
        iconView.tintColor = DesignTokens.Colors.success
        iconView.layer.shadowColor = DesignTokens.Colors.success.cgColor

        statusLabel.text = "You're all set!"
        Haptics.success()

        // Brief pause then navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.onComplete?()
        }
    }
}
