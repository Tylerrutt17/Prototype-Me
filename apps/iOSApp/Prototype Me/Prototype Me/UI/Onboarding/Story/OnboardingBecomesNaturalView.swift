import UIKit

/// Scattered dots converge into a rotating 3D sphere — a visual metaphor for
/// chaos becoming cohesive, second-nature rhythm.
final class OnboardingBecomesNaturalView: UIView, StoryAnimatable {

    // MARK: - Config

    private let dotCount = 52
    private let baseDotSize: CGFloat = 9
    private let sphereRadius: CGFloat = 100

    // MARK: - State

    private var dots: [UIView] = []
    /// Spherical coordinates for each dot (theta 0…π, phi 0…2π).
    private var sphereCoords: [(theta: CGFloat, phi: CGFloat)] = []
    /// Random scatter positions (offsets from center).
    private var scatterOffsets: [(x: CGFloat, y: CGFloat)] = []
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var hasPlayed = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        generateCoordinates()
        buildDots()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { displayLink?.invalidate() }

    // MARK: - Setup

    /// Distribute dots evenly on a sphere using the golden-angle method —
    /// gives the most natural, uniform-looking coverage without visible seams
    /// or ring patterns.
    private func generateCoordinates() {
        let goldenAngle = CGFloat.pi * (3.0 - sqrt(5.0))

        for i in 0..<dotCount {
            let t = CGFloat(i) / CGFloat(dotCount - 1) // 0…1
            let theta = acos(1 - 2 * t)                // polar angle, 0…π
            let phi = goldenAngle * CGFloat(i)          // azimuth, wraps around
            sphereCoords.append((theta, phi))

            let sx = CGFloat.random(in: -160...160)
            let sy = CGFloat.random(in: -160...160)
            scatterOffsets.append((sx, sy))
        }
    }

    private func buildDots() {
        for _ in 0..<dotCount {
            let dot = UIView()
            dot.backgroundColor = DesignTokens.Colors.accent
            dot.layer.cornerRadius = baseDotSize / 2
            dot.alpha = 0
            addSubview(dot)
            dots.append(dot)
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        // Always reset so this works cleanly on re-entry (swipe back,
        // foreground return, etc.).
        stopAnimations()

        guard !UIAccessibility.isReduceMotionEnabled else {
            positionDotsOnSphere(rotation: 0, blend: 1)
            dots.forEach { $0.alpha = 1 }
            return
        }

        // Regenerate scatter offsets so re-entry looks fresh, not identical.
        scatterOffsets = (0..<dotCount).map { _ in
            (CGFloat.random(in: -160...160), CGFloat.random(in: -160...160))
        }

        // Place dots at scatter positions, fade them in.
        let cx = bounds.midX
        let cy = bounds.midY
        for (i, dot) in dots.enumerated() {
            let (sx, sy) = scatterOffsets[i]
            dot.frame = CGRect(
                x: cx + sx - baseDotSize / 2,
                y: cy + sy - baseDotSize / 2,
                width: baseDotSize,
                height: baseDotSize
            )
            dot.alpha = 0
            UIView.animate(
                withDuration: 0.3,
                delay: Double(i) * 0.02,
                options: .curveEaseOut
            ) {
                dot.alpha = 0.8
            }
        }

        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimations() {
        displayLink?.invalidate()
        displayLink = nil
        dots.forEach {
            $0.layer.removeAllAnimations()
            $0.alpha = 0
        }
    }

    // MARK: - Animation

    @objc private func tick() {
        let t = CACurrentMediaTime() - startTime

        // Phase 1 (0–1.8s): blend from scatter → sphere, sphere begins rotating.
        // Phase 2 (1.8s+): pure sphere rotation.
        let convergeDuration: Double = 1.8
        let rawBlend = min(1.0, t / convergeDuration)
        // Smoothstep for a nice ease.
        let blend = CGFloat(rawBlend * rawBlend * (3 - 2 * rawBlend))

        // Rotation angle increases over time. Start slow, reach steady speed.
        let steadySpeed: Double = 0.35 // radians per second
        let rampDuration: Double = 2.5
        let speedFactor = min(1.0, t / rampDuration)
        let rotation = CGFloat(steadySpeed * t * speedFactor)

        positionDotsOnSphere(rotation: rotation, blend: blend)
    }

    /// Position each dot by blending between its scatter offset and its
    /// projected sphere position (with the given Y-axis rotation applied).
    private func positionDotsOnSphere(rotation: CGFloat, blend: CGFloat) {
        let cx = bounds.midX
        let cy = bounds.midY
        let perspective: CGFloat = 300
        let mutedGray = DesignTokens.Colors.textTertiary.withAlphaComponent(0.35)

        // Compute z-depths first so we can sort subviews back-to-front.
        // This is the single most important depth cue: front dots occlude
        // back dots, which locks in the rotation direction.
        var zDepths: [(index: Int, z: CGFloat)] = []

        for (i, _) in dots.enumerated() {
            let (theta, phi) = sphereCoords[i]
            let rotatedPhi = phi + rotation
            let z3d = sphereRadius * sin(theta) * sin(rotatedPhi)
            zDepths.append((i, z3d))
        }

        // Sort: back (negative z) first → front (positive z) last (on top).
        zDepths.sort { $0.z < $1.z }
        for order in zDepths {
            let dot = dots[order.index]
            // insertSubview is a no-op if already in the right spot; calling
            // it for every dot each frame is cheap for ~44 views.
            insertSubview(dot, at: subviews.count - 1)
        }

        for (i, dot) in dots.enumerated() {
            let (theta, phi) = sphereCoords[i]
            let rotatedPhi = phi + rotation

            // 3D position on sphere.
            let x3d = sphereRadius * sin(theta) * cos(rotatedPhi)
            let y3d = sphereRadius * cos(theta)
            let z3d = sphereRadius * sin(theta) * sin(rotatedPhi)

            // Perspective projection.
            let scale = perspective / (perspective + z3d)
            let projX = x3d * scale
            let projY = y3d * scale

            // Blend scatter → sphere.
            let (sx, sy) = scatterOffsets[i]
            let finalX = sx * (1 - blend) + projX * blend
            let finalY = sy * (1 - blend) + projY * blend

            // Depth cues: size, opacity, and color.
            let depthNorm = (z3d + sphereRadius) / (2 * sphereRadius) // 0 (back) … 1 (front)
            // Front dots scale up to 1.5× base size; back dots shrink to 0.45×.
            let dotScale = (0.45 + 1.05 * depthNorm) * scale
            // Back dots at 40% opacity, front dots at full 100%.
            let dotAlpha = 0.4 + 0.6 * depthNorm

            let size = baseDotSize * dotScale
            dot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            dot.layer.cornerRadius = size / 2
            dot.center = CGPoint(x: cx + finalX, y: cy + finalY)
            dot.alpha = dotAlpha * blend + (1 - blend) * 0.8

            // Color shifts by depth: accent in front, muted gray in back.
            let colorBlend = depthNorm * blend
            dot.backgroundColor = interpolateColor(from: mutedGray, to: DesignTokens.Colors.accent, t: colorBlend)
        }
    }

    /// Simple RGBA lerp between two colors.
    private func interpolateColor(from: UIColor, to: UIColor, t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = max(0, min(1, t))
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}
