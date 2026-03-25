import UIKit

/// Page 7: Animated wavy line that starts jagged and smooths out over time.
/// Feature icons pop in at key inflection points along the line.
final class OnboardingWavyLineView: UIView, StoryAnimatable {

    private let lineLayer = CAShapeLayer()
    private var iconViews: [UIImageView] = []
    private var hasBuilt = false

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        let path = UIBezierPath()
        let steps = 100
        let centerY = rect.midY

        path.move(to: CGPoint(x: rect.minX, y: centerY))

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width

            // Amplitude decreases as we go right (chaotic → smooth)
            let maxAmplitude: CGFloat = rect.height * 0.4
            let amplitude = maxAmplitude * (1.0 - t * 0.85)

            // Frequency also decreases slightly
            let frequency: CGFloat = 8 + (1.0 - t) * 6

            // Add some noise to early parts for extra chaos
            let noise: CGFloat = t < 0.3 ? CGFloat.random(in: -10...10) * (1.0 - t * 3) : 0

            let y = centerY + sin(t * frequency * .pi) * amplitude + noise
            path.addLine(to: CGPoint(x: x, y: y))
        }

        lineLayer.path = path.cgPath
        lineLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.8).cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        lineLayer.strokeEnd = 0
        layer.addSublayer(lineLayer)

        // Feature icons at key points along the line
        let iconData: [(xFrac: CGFloat, icon: String, color: UIColor)] = [
            (0.25, "arrow.right.circle.fill", DesignTokens.Colors.accent),       // Directives
            (0.50, "bolt.fill", NoteKind.mode.color),                             // Modes
            (0.75, "balloon.fill", DesignTokens.Colors.success),                  // Balloons
        ]

        for data in iconData {
            let x = rect.minX + data.xFrac * rect.width
            // Calculate Y at this point on the line
            let amplitude = rect.height * 0.4 * (1.0 - data.xFrac * 0.85)
            let frequency: CGFloat = 8 + (1.0 - data.xFrac) * 6
            let y = centerY + sin(data.xFrac * frequency * .pi) * amplitude

            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            let iv = UIImageView(image: UIImage(systemName: data.icon, withConfiguration: config))
            iv.tintColor = data.color
            iv.contentMode = .scaleAspectFit
            iv.frame = CGRect(x: x - 14, y: y - 28, width: 28, height: 28)
            iv.alpha = 0
            iv.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            addSubview(iv)
            iconViews.append(iv)
        }
    }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            lineLayer.strokeEnd = 1
            for iv in iconViews { iv.alpha = 1; iv.transform = .identity }
            return
        }

        // Draw the line
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 2.5
        draw.beginTime = CACurrentMediaTime() + 0.2
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lineLayer.strokeEnd = 1
        lineLayer.add(draw, forKey: "draw")

        // Icons pop in as the line reaches them
        for (i, iv) in iconViews.enumerated() {
            let delay = 0.2 + Double(i + 1) * 0.6 // Timed to when the line reaches each point
            UIView.animate(
                withDuration: 0.4,
                delay: delay,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.5
            ) {
                iv.alpha = 1
                iv.transform = .identity
            }
        }
    }

    func stopAnimations() {
        lineLayer.removeAllAnimations()
    }
}
