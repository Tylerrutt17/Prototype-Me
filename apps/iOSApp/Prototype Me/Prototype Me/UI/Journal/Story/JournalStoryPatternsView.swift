import UIKit

/// Page 3 visual: a simple rising trend line with milestone dots,
/// showing that consistent small entries reveal a big picture over time.
final class JournalStoryPatternsView: UIView, StoryAnimatable {

    private let trendLine = CAShapeLayer()
    private let glowLine = CAShapeLayer()
    private var dots: [UIView] = []
    private var hasBuilt = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        glowLine.fillColor = UIColor.clear.cgColor
        glowLine.strokeColor = DesignTokens.Colors.success.withAlphaComponent(0.12).cgColor
        glowLine.lineWidth = 14
        glowLine.lineCap = .round
        glowLine.lineJoin = .round
        glowLine.strokeEnd = 0
        layer.addSublayer(glowLine)

        trendLine.fillColor = UIColor.clear.cgColor
        trendLine.strokeColor = DesignTokens.Colors.success.cgColor
        trendLine.lineWidth = 3
        trendLine.lineCap = .round
        trendLine.lineJoin = .round
        trendLine.strokeEnd = 0
        layer.addSublayer(trendLine)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasBuilt, bounds.width > 0 else { return }
        hasBuilt = true
        buildVisual()
    }

    private func buildVisual() {
        let rect = bounds.insetBy(dx: DesignTokens.Spacing.xl, dy: DesignTokens.Spacing.xxxl)

        // Rising trend with some natural variation
        let points: [(CGFloat, CGFloat)] = [
            (0.0, 0.7), (0.1, 0.6), (0.2, 0.65), (0.3, 0.5),
            (0.4, 0.55), (0.5, 0.4), (0.6, 0.45), (0.7, 0.3),
            (0.8, 0.35), (0.9, 0.25), (1.0, 0.2),
        ]

        let path = UIBezierPath()
        var screenPoints: [CGPoint] = []

        for (i, point) in points.enumerated() {
            let p = CGPoint(
                x: rect.minX + point.0 * rect.width,
                y: rect.minY + point.1 * rect.height
            )
            screenPoints.append(p)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }

        trendLine.path = path.cgPath
        glowLine.path = path.cgPath

        // Milestone dots at key points
        let milestoneIndices = [0, 3, 6, 10]
        for i in milestoneIndices where i < screenPoints.count {
            let dot = UIView()
            dot.backgroundColor = DesignTokens.Colors.success
            dot.layer.cornerRadius = 5
            dot.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
            dot.center = screenPoints[i]
            dot.alpha = 0
            dot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            addSubview(dot)
            dots.append(dot)
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            trendLine.strokeEnd = 1
            glowLine.strokeEnd = 1
            for dot in dots { dot.alpha = 1; dot.transform = .identity }
            return
        }

        // Draw the trend line
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 1.8
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        draw.fillMode = .forwards
        draw.isRemovedOnCompletion = false
        trendLine.add(draw, forKey: "draw")
        glowLine.add(draw.copy() as! CABasicAnimation, forKey: "draw")

        // Pop in dots as line reaches them
        for (i, dot) in dots.enumerated() {
            let delay = 0.4 + Double(i) * 0.4
            UIView.animate(
                withDuration: 0.4,
                delay: delay,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.5
            ) {
                dot.alpha = 1
                dot.transform = .identity
            }
        }
    }

    func stopAnimations() {
        trendLine.removeAllAnimations()
        glowLine.removeAllAnimations()
        for dot in dots { dot.layer.removeAllAnimations() }
    }
}
