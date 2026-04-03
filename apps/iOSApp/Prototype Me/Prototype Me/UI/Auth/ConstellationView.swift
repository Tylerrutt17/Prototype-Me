import UIKit

/// Animated particle constellation — dots drift slowly with glowing lines
/// connecting nearby ones. Creates a living network effect.
final class ConstellationView: UIView {

    private struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var radius: CGFloat
        var alpha: CGFloat
    }

    private var particles: [Particle] = []
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var lastTime: CFTimeInterval = 0

    private let particleCount = 25
    private let connectionDistance: CGFloat = 100
    private let particleLayer = CALayer()
    private let lineLayer = CAShapeLayer()

    // Colors
    private let dotColors: [UIColor] = [
        DesignTokens.Colors.accent,
        DesignTokens.Colors.accentSecondary,
        DesignTokens.Colors.accentTertiary,
    ]
    private let lineColor = UIColor.white

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true

        lineLayer.fillColor = nil
        lineLayer.lineWidth = 0.8
        lineLayer.lineCap = .round
        layer.addSublayer(lineLayer)
        layer.addSublayer(particleLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        displayLink?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if particles.isEmpty && bounds.width > 0 {
            spawnParticles()
        }
    }

    private func spawnParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0...bounds.width),
                y: CGFloat.random(in: 0...bounds.height),
                vx: CGFloat.random(in: -12...12),
                vy: CGFloat.random(in: -12...12),
                radius: CGFloat.random(in: 1.5...3.0),
                alpha: CGFloat.random(in: 0.15...0.5)
            )
        }
    }

    func startAnimating() {
        stopAnimating()
        guard !UIAccessibility.isReduceMotionEnabled else {
            renderFrame()
            return
        }
        startTime = CACurrentMediaTime()
        lastTime = startTime
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 15)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(min(now - lastTime, 1.0 / 15.0)) // cap delta for tab switches
        lastTime = now
        updateParticles(dt: dt)
        renderFrame()
    }

    private func updateParticles(dt: CGFloat) {
        let w = bounds.width
        let h = bounds.height
        guard w > 0 else { return }

        for i in 0..<particles.count {
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt

            // Soft bounce off edges
            if particles[i].x < 0 { particles[i].x = 0; particles[i].vx = abs(particles[i].vx) }
            if particles[i].x > w { particles[i].x = w; particles[i].vx = -abs(particles[i].vx) }
            if particles[i].y < 0 { particles[i].y = 0; particles[i].vy = abs(particles[i].vy) }
            if particles[i].y > h { particles[i].y = h; particles[i].vy = -abs(particles[i].vy) }

            // Gentle drift variation
            let t = CGFloat(CACurrentMediaTime()) * 0.3
            particles[i].vx += sin(t + CGFloat(i)) * 0.3 * dt
            particles[i].vy += cos(t + CGFloat(i) * 1.3) * 0.3 * dt

            // Clamp speed
            let maxSpeed: CGFloat = 18
            let speed = sqrt(particles[i].vx * particles[i].vx + particles[i].vy * particles[i].vy)
            if speed > maxSpeed {
                let scale = maxSpeed / speed
                particles[i].vx *= scale
                particles[i].vy *= scale
            }
        }
    }

    private func renderFrame() {
        let w = bounds.width
        let h = bounds.height
        guard w > 0 else { return }

        // Center exclusion zone — dim particles and lines near content
        let centerX = w * 0.5
        let centerY = h * 0.45
        let deadRadius: CGFloat = min(w, h) * 0.22
        let fadeRadius: CGFloat = min(w, h) * 0.18

        // Draw lines
        let linePath = UIBezierPath()
        let connDist = connectionDistance

        // Use UIGraphicsImageRenderer for efficient line + dot rendering
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            let context = ctx.cgContext

            // Draw connection lines
            for i in 0..<particles.count {
                for j in (i + 1)..<particles.count {
                    let dx = particles[i].x - particles[j].x
                    let dy = particles[i].y - particles[j].y
                    let dist = sqrt(dx * dx + dy * dy)
                    if dist < connDist {
                        let strength = 1.0 - (dist / connDist)

                        // Midpoint mask for center exclusion
                        let mx = (particles[i].x + particles[j].x) * 0.5
                        let my = (particles[i].y + particles[j].y) * 0.5
                        let mDist = sqrt((mx - centerX) * (mx - centerX) + (my - centerY) * (my - centerY))
                        let mask = centerMask(dist: mDist, deadRadius: deadRadius, fadeRadius: fadeRadius)

                        let alpha = strength * 0.12 * mask
                        if alpha < 0.005 { continue }

                        context.setStrokeColor(lineColor.withAlphaComponent(alpha).cgColor)
                        context.setLineWidth(0.8)
                        context.move(to: CGPoint(x: particles[i].x, y: particles[i].y))
                        context.addLine(to: CGPoint(x: particles[j].x, y: particles[j].y))
                        context.strokePath()
                    }
                }
            }

            // Draw particles
            for (idx, p) in particles.enumerated() {
                let pDist = sqrt((p.x - centerX) * (p.x - centerX) + (p.y - centerY) * (p.y - centerY))
                let mask = centerMask(dist: pDist, deadRadius: deadRadius, fadeRadius: fadeRadius)

                let color = dotColors[idx % dotColors.count]
                let alpha = p.alpha * mask
                if alpha < 0.005 { continue }

                // Core dot
                context.setFillColor(color.withAlphaComponent(alpha).cgColor)
                context.fillEllipse(in: CGRect(
                    x: p.x - p.radius, y: p.y - p.radius,
                    width: p.radius * 2, height: p.radius * 2
                ))
            }
        }

        // Apply to a single backing layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if particleLayer.contents == nil {
            particleLayer.frame = bounds
            particleLayer.contentsScale = UIScreen.main.scale
        }
        particleLayer.frame = bounds
        particleLayer.contents = image.cgImage
        lineLayer.isHidden = true // we draw lines in the image now
        CATransaction.commit()
    }

    private func centerMask(dist: CGFloat, deadRadius: CGFloat, fadeRadius: CGFloat) -> CGFloat {
        if dist < deadRadius { return 0 }
        if dist < deadRadius + fadeRadius { return (dist - deadRadius) / fadeRadius }
        return 1
    }
}
