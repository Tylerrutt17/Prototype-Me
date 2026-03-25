import UIKit

/// Pages 1 & 3: Dots that start chaotic and coalesce into a rotating 3D sphere.
/// Page 1: chaos → sphere. Page 3: starts already as sphere (organized system).
final class OnboardingChaoticParticlesView: UIView, StoryAnimatable {

    enum Mode { case chaotic, organizing }

    private let mode: Mode
    private var dotLayers: [CAShapeLayer] = []
    private var hasBuilt = false

    // 3D sphere state
    private struct Dot3D {
        let theta: CGFloat
        let phi: CGFloat
        let baseRadius: CGFloat
    }
    private var dots3D: [Dot3D] = []
    private var displayLink: CADisplayLink?
    private var rotationAngle: CGFloat = 0
    private let sphereRadius: CGFloat = 90
    private let perspective: CGFloat = 400
    private var depthBlend: CGFloat = 0  // 0 = no depth effects, 1 = full depth
    private var rotationStartTime: CFTimeInterval = 0
    private let dotCount = 60
    private var isSphereMode = false

    // Chaotic starting positions
    private var chaoticPositions: [CGPoint] = []

    private let colors: [UIColor] = [
        DesignTokens.Colors.accent,
        DesignTokens.Colors.accentSecondary,
        DesignTokens.Colors.accentTertiary,
        DesignTokens.Colors.success,
        DesignTokens.Colors.warning,
    ]

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildDots()
        }
    }

    private func buildDots() {
        let goldenRatio = (1.0 + sqrt(5.0)) / 2.0

        for i in 0..<dotCount {
            let t = CGFloat(i) / CGFloat(dotCount - 1)
            let theta = acos(1.0 - 2.0 * t)
            let phi = 2.0 * .pi * CGFloat(i) / CGFloat(goldenRatio)
            let radius: CGFloat = CGFloat.random(in: 3...6)

            let dot = CAShapeLayer()
            dot.path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)).cgPath
            dot.fillColor = colors[i % colors.count].withAlphaComponent(0.8).cgColor
            dot.opacity = 0
            layer.addSublayer(dot)
            dotLayers.append(dot)

            dots3D.append(Dot3D(theta: theta, phi: phi, baseRadius: radius))

            // Random starting position for chaotic mode
            chaoticPositions.append(CGPoint(
                x: CGFloat.random(in: 0...bounds.width),
                y: CGFloat.random(in: 0...bounds.height)
            ))
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for dot in dotLayers { dot.opacity = 1 }
            isSphereMode = true
            updateSpherePositions()
            return
        }

        switch mode {
        case .chaotic:
            // Just chaotic dots bouncing around
            for (i, dot) in dotLayers.enumerated() {
                dot.position = chaoticPositions[i]
                let delay = Double(i) * 0.02
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0
                fade.toValue = 1
                fade.duration = 0.3
                fade.beginTime = CACurrentMediaTime() + delay
                fade.fillMode = .backwards
                dot.opacity = 1
                dot.add(fade, forKey: "fadeIn")
                addRandomDrift(to: dot)
            }

        case .organizing:
            // Start chaotic, then coalesce into the 3D sphere
            for (i, dot) in dotLayers.enumerated() {
                dot.position = chaoticPositions[i]
                let delay = Double(i) * 0.02
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0
                fade.toValue = 1
                fade.duration = 0.3
                fade.beginTime = CACurrentMediaTime() + delay
                fade.fillMode = .backwards
                dot.opacity = 1
                dot.add(fade, forKey: "fadeIn")
                addRandomDrift(to: dot)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.coalesceToSphere()
            }
        }
    }

    func stopAnimations() {
        stopRotation()
        for dot in dotLayers { dot.removeAllAnimations() }
    }

    // MARK: - Chaotic Drift

    private func addRandomDrift(to dot: CAShapeLayer) {
        let dx = CGFloat.random(in: -50...50)
        let dy = CGFloat.random(in: -50...50)
        let duration = Double.random(in: 1.0...2.5)

        let drift = CABasicAnimation(keyPath: "position")
        drift.fromValue = dot.position
        drift.toValue = CGPoint(
            x: max(10, min(bounds.width - 10, dot.position.x + dx)),
            y: max(10, min(bounds.height - 10, dot.position.y + dy))
        )
        drift.duration = duration
        drift.autoreverses = true
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dot.add(drift, forKey: "drift")
    }

    // MARK: - Coalesce to Sphere

    private func coalesceToSphere() {
        // Freeze dots at their current visual position before removing drift
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for dot in dotLayers {
            if let presentationPos = dot.presentation()?.position {
                dot.position = presentationPos
            }
            dot.removeAnimation(forKey: "drift")
        }
        CATransaction.commit()

        let cx = bounds.midX
        let cy = bounds.midY

        // Animate each dot from its current position to its sphere position
        for (i, dot) in dotLayers.enumerated() {
            guard i < dots3D.count else { break }
            let d = dots3D[i]

            // Calculate target sphere position at current rotation
            let x = sphereRadius * sin(d.theta) * cos(d.phi)
            let y = sphereRadius * cos(d.theta)
            let z = sphereRadius * sin(d.theta) * sin(d.phi)

            let tiltAngle: CGFloat = 0.3
            let y2 = y * cos(tiltAngle) - z * sin(tiltAngle)
            let z2 = y * sin(tiltAngle) + z * cos(tiltAngle)

            let scale = perspective / (perspective + z2)
            let targetX = cx + x * scale
            let targetY = cy + y2 * scale

            let currentPos = dot.presentation()?.position ?? dot.position

            let move = CASpringAnimation(keyPath: "position")
            move.fromValue = currentPos
            move.toValue = CGPoint(x: targetX, y: targetY)
            move.mass = 1.0
            move.stiffness = 50
            move.damping = 10
            move.initialVelocity = 0
            move.duration = move.settlingDuration
            move.beginTime = CACurrentMediaTime() + Double(i) * 0.015
            move.fillMode = .forwards
            move.isRemovedOnCompletion = false
            dot.add(move, forKey: "coalesce")
        }

        // Start sphere rotation after dots have mostly settled.
        // The display link will immediately set correct sphere positions on first tick,
        // so we just need to clear animations and hand off.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.isSphereMode = true
            // Set rotation to 0 so first tick places dots exactly where
            // the coalesce targeted (phi + 0 = same positions)
            self.rotationAngle = 0
            // Remove coalesce animations — display link takes over immediately
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for dot in self.dotLayers { dot.removeAllAnimations() }
            // Set positions to exact sphere coordinates so there's no gap
            self.updateSpherePositions()
            CATransaction.commit()
            self.startRotation()
            Haptics.light()
        }
    }

    // MARK: - 3D Sphere Rotation

    private func startRotation() {
        guard displayLink == nil else { return }
        depthBlend = 0
        rotationStartTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopRotation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        rotationAngle += 0.008
        // Ramp depth effects in over 1 second
        let elapsed = CACurrentMediaTime() - rotationStartTime
        depthBlend = min(1.0, CGFloat(elapsed / 1.0))
        updateSpherePositions()
    }

    private func updateSpherePositions() {
        let cx = bounds.midX
        let cy = bounds.midY

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, d) in dots3D.enumerated() {
            guard i < dotLayers.count else { break }
            let dot = dotLayers[i]

            let x = sphereRadius * sin(d.theta) * cos(d.phi + rotationAngle)
            let y = sphereRadius * cos(d.theta)
            let z = sphereRadius * sin(d.theta) * sin(d.phi + rotationAngle)

            let tiltAngle: CGFloat = 0.3
            let y2 = y * cos(tiltAngle) - z * sin(tiltAngle)
            let z2 = y * sin(tiltAngle) + z * cos(tiltAngle)

            let scale = perspective / (perspective + z2)
            let screenX = cx + x * scale
            let screenY = cy + y2 * scale

            dot.position = CGPoint(x: screenX, y: screenY)

            // Blend depth effects in gradually (depthBlend goes 0 → 1)
            let depthScale = scale * 0.8
            let blendedScale = 1.0 + (depthScale - 1.0) * depthBlend
            dot.transform = CATransform3DMakeScale(blendedScale, blendedScale, 1)

            let depthOpacity = 0.3 + 0.7 * ((z2 + sphereRadius) / (2 * sphereRadius))
            let blendedOpacity = 1.0 + (depthOpacity - 1.0) * depthBlend
            dot.opacity = Float(blendedOpacity)
        }

        CATransaction.commit()
    }

    @MainActor deinit {
        stopRotation()
    }
}
