import UIKit

/// Animated background with soft light streaks flowing diagonally across the screen.
/// Warm, energetic feel — like light leaking through glass.
final class FlowingLightView: UIView {

    private var streakLayers: [CAGradientLayer] = []
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    private struct Streak {
        let color1: UIColor
        let color2: UIColor
        let width: CGFloat       // fraction of screen width
        let speed: CGFloat       // how fast it drifts
        let angle: CGFloat       // rotation in radians
        let phaseX: CGFloat
        let phaseY: CGFloat
        let anchorX: CGFloat
        let anchorY: CGFloat
        let opacity: Float
    }

    private let streaks: [Streak] = [
        Streak(color1: DesignTokens.Colors.accent,          color2: DesignTokens.Colors.accentSecondary,
               width: 0.6, speed: 0.12, angle: 0.5, phaseX: 0.0, phaseY: 0.3, anchorX: 0.3, anchorY: 0.2, opacity: 0.15),
        Streak(color1: DesignTokens.Colors.accentTertiary,  color2: DesignTokens.Colors.accent,
               width: 0.5, speed: 0.08, angle: -0.3, phaseX: 1.5, phaseY: 1.0, anchorX: 0.7, anchorY: 0.6, opacity: 0.12),
        Streak(color1: DesignTokens.Colors.accentSecondary, color2: DesignTokens.Colors.accentTertiary,
               width: 0.45, speed: 0.15, angle: 0.7, phaseX: 3.0, phaseY: 2.2, anchorX: 0.2, anchorY: 0.7, opacity: 0.10),
        Streak(color1: DesignTokens.Colors.accent,          color2: DesignTokens.Colors.accentTertiary,
               width: 0.55, speed: 0.10, angle: -0.5, phaseX: 4.5, phaseY: 0.8, anchorX: 0.8, anchorY: 0.3, opacity: 0.08),
        Streak(color1: DesignTokens.Colors.accentSecondary, color2: DesignTokens.Colors.accent,
               width: 0.35, speed: 0.18, angle: 0.4, phaseX: 2.0, phaseY: 3.5, anchorX: 0.5, anchorY: 0.85, opacity: 0.10),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        buildStreaks()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        displayLink?.invalidate()
    }

    private func buildStreaks() {
        for streak in streaks {
            let layer = CAGradientLayer()
            layer.colors = [
                streak.color1.withAlphaComponent(0).cgColor,
                streak.color1.cgColor,
                streak.color2.cgColor,
                streak.color2.withAlphaComponent(0).cgColor,
            ]
            layer.locations = [0, 0.35, 0.65, 1.0]
            layer.startPoint = CGPoint(x: 0, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 0.5)
            layer.opacity = streak.opacity
            self.layer.addSublayer(layer)
            streakLayers.append(layer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePositions(at: 0)
    }

    func startAnimating() {
        stopAnimating()
        guard !UIAccessibility.isReduceMotionEnabled else {
            updatePositions(at: 0)
            return
        }
        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 15)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        updatePositions(at: CACurrentMediaTime() - startTime)
    }

    private func updatePositions(at time: CFTimeInterval) {
        let w = bounds.width
        let h = bounds.height
        guard w > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, streak) in streaks.enumerated() {
            let t = CGFloat(time) * streak.speed
            let streakW = w * streak.width
            let streakH = h * 1.8  // tall enough to cover screen at angle

            let cx = w * streak.anchorX + sin(t * 2 * .pi + streak.phaseX) * w * 0.3
            let cy = h * streak.anchorY + cos(t * 2 * .pi + streak.phaseY) * h * 0.2

            streakLayers[i].bounds = CGRect(x: 0, y: 0, width: streakW, height: streakH)
            streakLayers[i].position = CGPoint(x: cx, y: cy)
            streakLayers[i].transform = CATransform3DMakeRotation(streak.angle, 0, 0, 1)
        }

        CATransaction.commit()
    }
}
