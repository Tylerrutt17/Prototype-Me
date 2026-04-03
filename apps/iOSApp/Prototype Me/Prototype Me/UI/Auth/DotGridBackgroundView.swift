import UIKit

/// Animated grid of dots with slow waves sweeping across.
final class DotGridBackgroundView: UIView {

    private var dotLayers: [[CAShapeLayer]] = []
    private var dotPositions: [[CGPoint]] = []
    private var rows = 0
    private var cols = 0
    private let dotRadius: CGFloat = 2.5
    private let spacing: CGFloat = 28
    private let baseAlpha: CGFloat = 0.08
    private var hasBuilt = false
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, !hasBuilt else { return }
        hasBuilt = true
        buildGrid()
    }

    private func buildGrid() {
        dotLayers.flatMap { $0 }.forEach { $0.removeFromSuperlayer() }
        dotLayers = []
        dotPositions = []

        cols = Int(bounds.width / spacing) + 1
        rows = Int(bounds.height / spacing) + 1

        let xOffset = (bounds.width - CGFloat(cols - 1) * spacing) / 2
        let yOffset = (bounds.height - CGFloat(rows - 1) * spacing) / 2

        for r in 0..<rows {
            var row: [CAShapeLayer] = []
            var posRow: [CGPoint] = []
            for c in 0..<cols {
                let dot = CAShapeLayer()
                let x = xOffset + CGFloat(c) * spacing
                let y = yOffset + CGFloat(r) * spacing
                dot.path = UIBezierPath(
                    ovalIn: CGRect(x: -dotRadius, y: -dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                ).cgPath
                dot.position = CGPoint(x: x, y: y)
                dot.fillColor = UIColor.white.withAlphaComponent(baseAlpha).cgColor
                layer.addSublayer(dot)
                row.append(dot)
                posRow.append(CGPoint(x: x, y: y))
            }
            dotLayers.append(row)
            dotPositions.append(posRow)
        }
    }

    func startAnimating() {
        stopAnimating()
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 20)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let t = CACurrentMediaTime() - startTime
        let w = bounds.width
        let h = bounds.height
        guard w > 0, h > 0 else { return }

        // Diagonal length for normalization
        let diag = sqrt(w * w + h * h)

        // Two slow waves moving in different diagonal directions
        let wave1Speed: Double = 0.18
        let wave1Angle: CGFloat = 0.4  // radians, slight diagonal
        let wave1Dx = cos(wave1Angle)
        let wave1Dy = sin(wave1Angle)

        let wave2Speed: Double = 0.13
        let wave2Angle: CGFloat = 2.2  // different diagonal
        let wave2Dx = cos(wave2Angle)
        let wave2Dy = sin(wave2Angle)

        let peakAlpha: CGFloat = 0.28
        let waveWidth: CGFloat = 0.15  // fraction of diagonal that the wave covers

        // Center dead zone — waves are suppressed here so text is readable
        let centerX = w * 0.5
        let centerY = h * 0.48  // roughly where the content sits
        let deadRadius: CGFloat = min(w, h) * 0.28
        let fadeRadius: CGFloat = min(w, h) * 0.15  // smooth transition band

        for r in 0..<rows {
            for c in 0..<cols {
                let pos = dotPositions[r][c]

                // Project position onto wave direction, normalized to 0...1
                let proj1 = (pos.x * wave1Dx + pos.y * wave1Dy) / diag
                let phase1 = fract(proj1 - CGFloat(t * wave1Speed))
                let brightness1 = waveIntensity(phase: phase1, width: waveWidth)

                let proj2 = (pos.x * wave2Dx + pos.y * wave2Dy) / diag
                let phase2 = fract(proj2 - CGFloat(t * wave2Speed))
                let brightness2 = waveIntensity(phase: phase2, width: waveWidth)

                let combined = max(brightness1, brightness2)

                // Suppress wave near center
                let dx = pos.x - centerX
                let dy = pos.y - centerY
                let dist = sqrt(dx * dx + dy * dy)
                let mask: CGFloat
                if dist < deadRadius {
                    mask = 0
                } else if dist < deadRadius + fadeRadius {
                    mask = (dist - deadRadius) / fadeRadius
                } else {
                    mask = 1
                }

                // Fade the base dots themselves near center, not just the wave
                let baseMask = min(mask, 1.0)
                let dimmedBase = baseAlpha * (0.3 + 0.7 * baseMask)
                let alpha = dimmedBase + (peakAlpha - dimmedBase) * combined * mask

                dotLayers[r][c].fillColor = UIColor.white.withAlphaComponent(alpha).cgColor
            }
        }
    }

    /// Smooth bell-curve intensity for a wave at a given phase position.
    private func waveIntensity(phase: CGFloat, width: CGFloat) -> CGFloat {
        // Distance from the wave center (at phase 0.5)
        let dist = abs(phase - 0.5)
        if dist > width { return 0 }
        // Smooth cosine falloff
        let t = dist / width
        return (1 + cos(t * .pi)) * 0.5
    }

    private func fract(_ x: CGFloat) -> CGFloat {
        x - floor(x)
    }
}
