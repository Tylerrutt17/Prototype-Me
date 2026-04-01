import UIKit
import SpriteKit

/// Cinematic ambient screen with SpriteKit particles and a glassmorphism CTA panel.
/// The "hero" moment of onboarding.
final class FocusConsoleViewController: UIViewController {

    var onGetStarted: (() -> Void)?

    // MARK: - Layers

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,   // dark navy
            UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,   // deep purple-blue
            UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,   // ground
        ]
        layer.locations = [0.0, 0.5, 1.0]
        return layer
    }()

    private var skView: SKView!
    private var particleScene: AmbientParticleScene!

    // MARK: - UI

    private let glassPanel = GlassPanelView()
    private let logoIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let ctaButton = AppButton(title: "Set Up My Plan")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGradient()
        setupParticles()
        setupGlassPanel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = view.bounds
        CATransaction.commit()
        skView.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateEntrance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        particleScene?.isPaused = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        skView?.presentScene(nil)
    }

    // MARK: - Setup

    private func setupGradient() {
        view.layer.addSublayer(gradientLayer)
    }

    private func setupParticles() {
        skView = SKView()
        skView.allowsTransparency = true
        skView.backgroundColor = .clear
        view.addSubview(skView)

        particleScene = AmbientParticleScene(size: view.bounds.size)
        skView.presentScene(particleScene)
    }

    private func setupGlassPanel() {
        glassPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glassPanel)

        // Logo
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        logoIcon.image = UIImage(systemName: "scope", withConfiguration: config)
        logoIcon.tintColor = DesignTokens.Colors.accent
        logoIcon.contentMode = .scaleAspectFit
        logoIcon.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.text = "Prototype Me"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center

        // Subtitle
        subtitleLabel.text = "Let's set up your personal system"
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // CTA
        ctaButton.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [logoIcon, titleLabel, subtitleLabel, ctaButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.alignment = .center
        stack.setCustomSpacing(DesignTokens.Spacing.xxl, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        glassPanel.addSubview(stack)

        let maxWidth: CGFloat = 340
        let padding = DesignTokens.Spacing.xxl

        NSLayoutConstraint.activate([
            glassPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            glassPanel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),
            glassPanel.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            glassPanel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            glassPanel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),

            stack.topAnchor.constraint(equalTo: glassPanel.topAnchor, constant: padding),
            stack.bottomAnchor.constraint(equalTo: glassPanel.bottomAnchor, constant: -padding),
            stack.leadingAnchor.constraint(equalTo: glassPanel.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: glassPanel.trailingAnchor, constant: -padding),

            ctaButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            ctaButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
        ])

        // Start invisible
        glassPanel.alpha = 0
        glassPanel.transform = CGAffineTransform(translationX: 0, y: 30).scaledBy(x: 0.95, y: 0.95)
    }

    // MARK: - Animations

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            glassPanel.alpha = 1
            glassPanel.transform = .identity
            startAmbientDrift()
            return
        }

        UIView.animate(
            withDuration: 0.8,
            delay: 0.4,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.2
        ) {
            self.glassPanel.alpha = 1
            self.glassPanel.transform = .identity
        } completion: { _ in
            self.startAmbientDrift()
        }
    }

    private func startAmbientDrift() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let drift = CAKeyframeAnimation(keyPath: "transform.translation.y")
        drift.values = [0, -4, 0, 4, 0]
        drift.keyTimes = [0, 0.25, 0.5, 0.75, 1.0]
        drift.duration = 6.0
        drift.repeatCount = .infinity
        drift.timingFunctions = (0..<4).map { _ in CAMediaTimingFunction(name: .easeInEaseOut) }
        glassPanel.layer.add(drift, forKey: "ambientDrift")
    }

    // MARK: - Actions

    @objc private func ctaTapped() {
        Haptics.medium()
        onGetStarted?()
    }
}
