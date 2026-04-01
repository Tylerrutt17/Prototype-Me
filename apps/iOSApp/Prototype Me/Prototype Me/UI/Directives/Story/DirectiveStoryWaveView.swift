import UIKit

/// Page 1 visual: an erratic wave line that smooths into a consistent wave,
/// representing inconsistency becoming consistency.
final class DirectiveStoryWaveView: UIView, StoryAnimatable {

    private let waveLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(glowLayer)
        layer.addSublayer(waveLayer)
        waveLayer.fillColor = UIColor.clear.cgColor
        waveLayer.strokeColor = DesignTokens.Colors.accent.cgColor
        waveLayer.lineWidth = 3
        waveLayer.lineCap = .round
        waveLayer.lineJoin = .round
        waveLayer.strokeEnd = 0

        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.15).cgColor
        glowLayer.lineWidth = 12
        glowLayer.lineCap = .round
        glowLayer.lineJoin = .round
        glowLayer.strokeEnd = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = makeWavePath()
        waveLayer.path = path.cgPath
        glowLayer.path = path.cgPath
    }

    private func makeWavePath() -> UIBezierPath {
        let w = bounds.width
        let h = bounds.height
        let midY = h * 0.5
        let path = UIBezierPath()

        guard w > 0 else { return path }

        // Left side: erratic/jagged, right side: smooth wave
        let segments = 40
        let segW = w / CGFloat(segments)

        path.move(to: CGPoint(x: 0, y: midY))

        for i in 1...segments {
            let x = segW * CGFloat(i)
            let progress = CGFloat(i) / CGFloat(segments) // 0→1

            // Amplitude: large and erratic on left, smooth sine on right
            let erraticAmp = CGFloat.random(in: -50...50) * (1.0 - progress)
            let smoothAmp = sin(CGFloat(i) * .pi / 5) * 30 * progress

            let y = midY + erraticAmp + smoothAmp
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            waveLayer.strokeEnd = 1
            glowLayer.strokeEnd = 1
            return
        }

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = 2.0
        draw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        draw.fillMode = .forwards
        draw.isRemovedOnCompletion = false
        waveLayer.add(draw, forKey: "draw")

        let glowDraw = draw.copy() as! CABasicAnimation
        glowDraw.duration = 2.0
        glowLayer.add(glowDraw, forKey: "glowDraw")
    }

    func stopAnimations() {
        waveLayer.removeAllAnimations()
        glowLayer.removeAllAnimations()
    }
}
