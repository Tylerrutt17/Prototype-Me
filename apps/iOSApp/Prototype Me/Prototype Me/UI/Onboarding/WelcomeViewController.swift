import UIKit
import SpriteKit

/// Brief celebration screen with particles, checkmark animation, and auto-dismiss.
final class WelcomeViewController: UIViewController {

    var onReady: (() -> Void)?

    // MARK: - Layers

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.05, green: 0.07, blue: 0.18, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.06, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0).cgColor,
        ]
        layer.locations = [0.0, 0.5, 1.0]
        return layer
    }()

    private var skView: SKView!
    private var particleScene: AmbientParticleScene!

    // MARK: - UI

    private let checkmarkView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.layer.addSublayer(gradientLayer)
        setupParticles()
        setupContent()
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

        // Auto-dismiss after 2.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.onReady?()
        }
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

    private func setupParticles() {
        skView = SKView()
        skView.allowsTransparency = true
        skView.backgroundColor = .clear
        view.addSubview(skView)

        particleScene = AmbientParticleScene(size: view.bounds.size)
        particleScene.intensityMultiplier = 2.0  // Celebration mode
        skView.presentScene(particleScene)
    }

    private func setupContent() {
        // Checkmark
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        checkmarkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        checkmarkView.tintColor = DesignTokens.Colors.success
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.alpha = 0
        checkmarkView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)

        // Title
        titleLabel.text = "Welcome to Prototype Me"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 20)

        // Subtitle
        subtitleLabel.text = "Your plan is ready."
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 15)

        let stack = UIStackView(arrangedSubviews: [checkmarkView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xl
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),
        ])
    }

    // MARK: - Animation

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            checkmarkView.alpha = 1; checkmarkView.transform = .identity
            titleLabel.alpha = 1; titleLabel.transform = .identity
            subtitleLabel.alpha = 1; subtitleLabel.transform = .identity
            Haptics.success()
            return
        }

        // Checkmark spring scale-in
        UIView.animate(withDuration: 0.6, delay: 0.3, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.3) {
            self.checkmarkView.alpha = 1
            self.checkmarkView.transform = .identity
        } completion: { _ in
            Haptics.success()
        }

        // Title slides up
        UIView.animate(withDuration: 0.4, delay: 0.6, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        // Subtitle slides up
        UIView.animate(withDuration: 0.4, delay: 0.8, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
    }
}
