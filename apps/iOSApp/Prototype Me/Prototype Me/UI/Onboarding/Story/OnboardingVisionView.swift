import UIKit

/// Screen 1: A clean, smooth glowing line representing the "dialed in" life you can picture.
/// Gently pulses and subtly destabilizes at the edges — you can see it, but can't hold it.
final class OnboardingVisionView: UIView, StoryAnimatable {

    private let lineLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
    private let destabilizeLayer = CAShapeLayer()
    private var hasBuilt = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    private func buildVisual() {
        let rect = bounds.insetBy(dx: DesignTokens.Spacing.lg, dy: DesignTokens.Spacing.xxxl)
        let centerY = rect.midY

        // The smooth, ideal line — gentle sine wave, very controlled
        let smoothPath = UIBezierPath()
        let steps = 120
        smoothPath.move(to: CGPoint(x: rect.minX, y: centerY))

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width
            // Gentle, smooth wave — this is the "vision"
            let y = centerY + sin(t * 2.0 * .pi) * rect.height * 0.08
            smoothPath.addLine(to: CGPoint(x: x, y: y))
        }

        // The destabilized version — same base but gets noisy at the edges
        let unstablePath = UIBezierPath()
        unstablePath.move(to: CGPoint(x: rect.minX, y: centerY))

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width
            let baseY = centerY + sin(t * 2.0 * .pi) * rect.height * 0.08

            // Instability increases toward the edges (start and end)
            let edgeDist = min(t, 1.0 - t) // 0 at edges, 0.5 at center
            let instability = max(0, 1.0 - edgeDist * 4.0) // 1.0 at edges, 0 in middle 75%
            let noise = instability * sin(t * 17.0 * .pi + 2.3) * rect.height * 0.15

            unstablePath.addLine(to: CGPoint(x: x, y: baseY + noise))
        }

        // Wide soft glow
        glowLayer.path = smoothPath.cgPath
        glowLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.15).cgColor
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.lineWidth = 16
        glowLayer.lineCap = .round
        glowLayer.lineJoin = .round
        glowLayer.strokeEnd = 0
        layer.addSublayer(glowLayer)

        // Destabilized edges (drawn on top, fades in and out)
        destabilizeLayer.path = unstablePath.cgPath
        destabilizeLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor
        destabilizeLayer.fillColor = UIColor.clear.cgColor
        destabilizeLayer.lineWidth = 2
        destabilizeLayer.lineCap = .round
        destabilizeLayer.lineJoin = .round
        destabilizeLayer.opacity = 0
        layer.addSublayer(destabilizeLayer)

        // Main clean line
        lineLayer.path = smoothPath.cgPath
        lineLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.9).cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        lineLayer.strokeEnd = 0
        layer.addSublayer(lineLayer)
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            lineLayer.strokeEnd = 1
            glowLayer.strokeEnd = 1
            return
        }

        // Draw the smooth line
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 1.8
        draw.beginTime = CACurrentMediaTime() + 0.2
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)

        lineLayer.strokeEnd = 1
        lineLayer.add(draw, forKey: "draw")
        glowLayer.strokeEnd = 1
        glowLayer.add(draw, forKey: "draw")

        // After the line draws, pulse the glow gently
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self else { return }

            let pulse = CABasicAnimation(keyPath: "lineWidth")
            pulse.fromValue = 16
            pulse.toValue = 24
            pulse.duration = 2.0
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.glowLayer.add(pulse, forKey: "pulse")

            // Flicker the destabilized edges in and out
            let flicker = CAKeyframeAnimation(keyPath: "opacity")
            flicker.values = [0, 0.6, 0, 0, 0.4, 0, 0]
            flicker.keyTimes = [0, 0.15, 0.3, 0.5, 0.65, 0.8, 1.0]
            flicker.duration = 4.0
            flicker.repeatCount = .infinity
            self.destabilizeLayer.strokeEnd = 1
            self.destabilizeLayer.add(flicker, forKey: "flicker")
        }
    }

    func stopAnimations() {
        lineLayer.removeAllAnimations()
        glowLayer.removeAllAnimations()
        destabilizeLayer.removeAllAnimations()
    }
}
