import UIKit

/// Reusable glassmorphism panel: frosted blur + subtle border gradient + pulsing glow shadow.
final class GlassPanelView: UIView {

    private let blurView: UIVisualEffectView
    private let tintOverlay = UIView()
    private let borderGradient = CAGradientLayer()
    private let borderMask = CAShapeLayer()
    private let glowLayer = CALayer()
    private let panelCornerRadius: CGFloat

    init(cornerRadius: CGFloat = DesignTokens.Radii.xl) {
        self.panelCornerRadius = cornerRadius
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupView() {
        // Glow layer (behind everything, needs to be visible outside bounds)
        clipsToBounds = false
        glowLayer.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08).cgColor
        glowLayer.shadowColor = DesignTokens.Colors.accent.cgColor
        glowLayer.shadowRadius = 30
        glowLayer.shadowOpacity = 0.15
        glowLayer.shadowOffset = .zero
        glowLayer.cornerRadius = panelCornerRadius
        layer.insertSublayer(glowLayer, at: 0)

        // Blur view
        blurView.alpha = 0.7
        blurView.layer.cornerRadius = panelCornerRadius
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        // Tint overlay
        tintOverlay.backgroundColor = DesignTokens.Colors.surfacePrimary.withAlphaComponent(0.3)
        tintOverlay.layer.cornerRadius = panelCornerRadius
        tintOverlay.clipsToBounds = true
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tintOverlay)

        // Frosted border gradient
        borderGradient.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.white.withAlphaComponent(0.03).cgColor,
        ]
        borderGradient.startPoint = CGPoint(x: 0, y: 0)
        borderGradient.endPoint = CGPoint(x: 1, y: 1)
        borderGradient.mask = borderMask
        borderMask.fillColor = UIColor.clear.cgColor
        borderMask.strokeColor = UIColor.white.cgColor
        borderMask.lineWidth = 1
        layer.addSublayer(borderGradient)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintOverlay.topAnchor.constraint(equalTo: topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        startGlowAnimation()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = bounds
        borderGradient.frame = bounds
        borderMask.path = UIBezierPath(roundedRect: bounds, cornerRadius: panelCornerRadius).cgPath
        CATransaction.commit()
    }

    // MARK: - Glow Animation

    private func startGlowAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 30
        pulse.toValue = 50
        pulse.duration = 3.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(pulse, forKey: "glowPulse")
    }
}
