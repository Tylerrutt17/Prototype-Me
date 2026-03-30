import UIKit

/// Screen 2: A continuously messy, jagged line that loops endlessly —
/// representing the chaos of life without a system (ups/downs, inconsistency).
final class OnboardingMessyLineView: UIView, StoryAnimatable {

    private let lineLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
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
            buildLine()
        }
    }

    private func buildLine() {
        let rect = bounds.insetBy(dx: DesignTokens.Spacing.lg, dy: DesignTokens.Spacing.xxxl)
        let path = messyPath(in: rect)

        // Soft glow behind the line
        glowLayer.path = path.cgPath
        glowLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.25).cgColor
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.lineWidth = 8
        glowLayer.lineCap = .round
        glowLayer.lineJoin = .round
        glowLayer.strokeEnd = 0
        layer.addSublayer(glowLayer)

        // Main line
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.8).cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        lineLayer.strokeEnd = 0
        layer.addSublayer(lineLayer)
    }

    /// Generates a jagged, erratic path across the view — sharp peaks, valleys,
    /// and random noise throughout. No smoothing, no trend — just chaos.
    private func messyPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let steps = 120
        let centerY = rect.midY
        let maxAmplitude = rect.height * 0.38

        // Use a seeded pattern so it's deterministic (same every launch)
        // but looks random. Mix of frequencies for organic messiness.
        path.move(to: CGPoint(x: rect.minX, y: centerY))

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width

            // Layer multiple sine waves at different frequencies for chaos
            let wave1 = sin(t * 7.0 * .pi) * maxAmplitude * 0.5
            let wave2 = sin(t * 13.0 * .pi + 1.2) * maxAmplitude * 0.35
            let wave3 = sin(t * 23.0 * .pi + 3.7) * maxAmplitude * 0.25

            // Sharp spikes at irregular intervals
            let spike: CGFloat
            let spikeIndex = i % 17
            if spikeIndex == 3 {
                spike = maxAmplitude * 0.4
            } else if spikeIndex == 9 {
                spike = -maxAmplitude * 0.35
            } else if spikeIndex == 14 {
                spike = maxAmplitude * 0.25
            } else {
                spike = 0
            }

            let y = centerY + wave1 + wave2 + wave3 + spike
            let clampedY = min(rect.maxY, max(rect.minY, y))
            path.addLine(to: CGPoint(x: x, y: clampedY))
        }

        return path
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            lineLayer.strokeEnd = 1
            glowLayer.strokeEnd = 1
            return
        }

        // Draw the messy line from left to right
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 2.0
        draw.beginTime = CACurrentMediaTime() + 0.2
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)

        lineLayer.strokeEnd = 1
        lineLayer.add(draw, forKey: "draw")

        glowLayer.strokeEnd = 1
        glowLayer.add(draw, forKey: "draw")

        // After drawn, pulse the line gently to emphasize the chaos
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.6
            pulse.duration = 1.2
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.glowLayer.add(pulse, forKey: "pulse")
        }
    }

    func stopAnimations() {
        lineLayer.removeAllAnimations()
        glowLayer.removeAllAnimations()
    }
}
