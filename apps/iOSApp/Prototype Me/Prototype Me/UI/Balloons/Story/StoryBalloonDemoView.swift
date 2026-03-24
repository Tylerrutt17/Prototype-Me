import UIKit

/// Pages 3 & 4 visual: a single large demo balloon that plays either a deflation or pump animation.
final class StoryBalloonDemoView: UIView, StoryAnimatable {

    enum Mode { case deflate, pump }

    private let mode: Mode

    // Balloon shape layers
    private let balloonBody = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let knotLayer = CAShapeLayer()
    private let stringLayer = CAShapeLayer()
    private let balloonGroup = CALayer()

    private let balloonW: CGFloat = 90
    private var balloonH: CGFloat { balloonW * 1.25 }
    private var hasBuilt = false

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildBalloon()
        }
    }

    private func buildBalloon() {
        let cx = bounds.midX
        let cy = bounds.midY

        // Group layer to hold all balloon parts — we animate this as a unit
        balloonGroup.position = CGPoint(x: cx, y: cy)
        layer.addSublayer(balloonGroup)

        // Body
        balloonBody.path = UIBezierPath(ovalIn: CGRect(x: -balloonW / 2, y: -balloonH / 2, width: balloonW, height: balloonH)).cgPath
        balloonGroup.addSublayer(balloonBody)

        // Highlight
        let hlW = balloonW * 0.25, hlH = balloonH * 0.2
        highlightLayer.path = UIBezierPath(ovalIn: CGRect(x: -balloonW * 0.15, y: -balloonH * 0.3, width: hlW, height: hlH)).cgPath
        balloonGroup.addSublayer(highlightLayer)

        // Knot
        let knotY = balloonH / 2
        let knotPath = UIBezierPath()
        knotPath.move(to: CGPoint(x: -4, y: knotY))
        knotPath.addLine(to: CGPoint(x: 0, y: knotY + 7))
        knotPath.addLine(to: CGPoint(x: 4, y: knotY))
        knotPath.close()
        knotLayer.path = knotPath.cgPath
        balloonGroup.addSublayer(knotLayer)

        // String
        let stringPath = UIBezierPath()
        stringPath.move(to: CGPoint(x: 0, y: knotY + 7))
        stringPath.addQuadCurve(
            to: CGPoint(x: -4, y: knotY + 35),
            controlPoint: CGPoint(x: 8, y: knotY + 20)
        )
        stringLayer.path = stringPath.cgPath
        stringLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        stringLayer.fillColor = UIColor.clear.cgColor
        stringLayer.lineWidth = 1.5
        balloonGroup.addSublayer(stringLayer)

        // Set initial state based on mode
        switch mode {
        case .deflate:
            applyColor(.green)
            highlightLayer.opacity = 0.35
            balloonGroup.transform = CATransform3DIdentity
        case .pump:
            applyColor(.red)
            highlightLayer.opacity = 0.08
            balloonGroup.transform = CATransform3DMakeScale(0.6, 0.6, 1.0)
            balloonGroup.position = CGPoint(x: cx, y: cy + 50)
        }
    }

    private enum BalloonColor { case green, yellow, red }

    private func applyColor(_ color: BalloonColor) {
        let (fill, knot, highlight): (UIColor, UIColor, Float) = switch color {
        case .green:
            (DesignTokens.Colors.success, DesignTokens.Colors.success.withAlphaComponent(0.7), 0.35)
        case .yellow:
            (DesignTokens.Colors.warning, DesignTokens.Colors.warning.withAlphaComponent(0.7), 0.2)
        case .red:
            (DesignTokens.Colors.destructive, DesignTokens.Colors.destructive.withAlphaComponent(0.7), 0.08)
        }
        balloonBody.fillColor = fill.withAlphaComponent(0.85).cgColor
        knotLayer.fillColor = knot.cgColor
        highlightLayer.fillColor = UIColor.white.withAlphaComponent(CGFloat(highlight)).cgColor
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            switch mode {
            case .deflate: applyColor(.red); balloonGroup.transform = CATransform3DMakeScale(0.6, 0.6, 1.0)
            case .pump: applyColor(.green); balloonGroup.transform = CATransform3DIdentity
            }
            return
        }

        switch mode {
        case .deflate: playDeflation()
        case .pump: playPump()
        }
    }

    func stopAnimations() {
        balloonGroup.removeAllAnimations()
        balloonBody.removeAllAnimations()
        knotLayer.removeAllAnimations()
        highlightLayer.removeAllAnimations()
    }

    // MARK: - Deflation Animation (Page 3)

    private func playDeflation() {
        let duration: CFTimeInterval = 3.0
        let delay: CFTimeInterval = 0.6
        let startTime = CACurrentMediaTime() + delay

        // Shrink
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1.0
        shrink.toValue = 0.6
        shrink.duration = duration
        shrink.beginTime = startTime
        shrink.fillMode = .forwards
        shrink.isRemovedOnCompletion = false
        shrink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        balloonGroup.add(shrink, forKey: "shrink")

        // Descend
        let descend = CABasicAnimation(keyPath: "position.y")
        descend.fromValue = balloonGroup.position.y
        descend.toValue = balloonGroup.position.y + 50
        descend.duration = duration
        descend.beginTime = startTime
        descend.fillMode = .forwards
        descend.isRemovedOnCompletion = false
        descend.timingFunction = CAMediaTimingFunction(name: .easeIn)
        balloonGroup.add(descend, forKey: "descend")

        // Color morph: green → yellow → red
        let bodyColorMorph = CAKeyframeAnimation(keyPath: "fillColor")
        bodyColorMorph.values = [
            DesignTokens.Colors.success.withAlphaComponent(0.85).cgColor,
            DesignTokens.Colors.success.withAlphaComponent(0.85).cgColor,
            DesignTokens.Colors.warning.withAlphaComponent(0.85).cgColor,
            DesignTokens.Colors.destructive.withAlphaComponent(0.85).cgColor,
        ]
        bodyColorMorph.keyTimes = [0, 0.25, 0.6, 1.0]
        bodyColorMorph.duration = duration
        bodyColorMorph.beginTime = startTime
        bodyColorMorph.fillMode = .forwards
        bodyColorMorph.isRemovedOnCompletion = false
        balloonBody.add(bodyColorMorph, forKey: "colorMorph")

        // Knot color morph
        let knotColorMorph = CAKeyframeAnimation(keyPath: "fillColor")
        knotColorMorph.values = [
            DesignTokens.Colors.success.withAlphaComponent(0.7).cgColor,
            DesignTokens.Colors.success.withAlphaComponent(0.7).cgColor,
            DesignTokens.Colors.warning.withAlphaComponent(0.7).cgColor,
            DesignTokens.Colors.destructive.withAlphaComponent(0.7).cgColor,
        ]
        knotColorMorph.keyTimes = [0, 0.25, 0.6, 1.0]
        knotColorMorph.duration = duration
        knotColorMorph.beginTime = startTime
        knotColorMorph.fillMode = .forwards
        knotColorMorph.isRemovedOnCompletion = false
        knotLayer.add(knotColorMorph, forKey: "knotColorMorph")

        // Highlight fades (balloon looks less glossy as it deflates)
        let hlFade = CABasicAnimation(keyPath: "opacity")
        hlFade.fromValue = 0.35
        hlFade.toValue = 0.08
        hlFade.duration = duration
        hlFade.beginTime = startTime
        hlFade.fillMode = .forwards
        hlFade.isRemovedOnCompletion = false
        highlightLayer.add(hlFade, forKey: "hlFade")

        // Wobble at the end to suggest instability
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration) { [weak self] in
            guard let self else { return }
            let wobble = CABasicAnimation(keyPath: "transform.rotation.z")
            wobble.fromValue = -0.05
            wobble.toValue = 0.05
            wobble.duration = 0.4
            wobble.autoreverses = true
            wobble.repeatCount = .infinity
            wobble.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.balloonGroup.add(wobble, forKey: "wobble")
        }
    }

    // MARK: - Pump Animation (Page 4)

    private func playPump() {
        let delay: CFTimeInterval = 0.6
        let startTime = CACurrentMediaTime() + delay
        let cx = bounds.midX
        let cy = bounds.midY

        // Spring inflate: 0.6 → 1.0
        let inflate = CASpringAnimation(keyPath: "transform.scale")
        inflate.fromValue = 0.6
        inflate.toValue = 1.0
        inflate.mass = 1.0
        inflate.stiffness = 300
        inflate.damping = 8
        inflate.initialVelocity = 18
        inflate.duration = inflate.settlingDuration
        inflate.beginTime = startTime
        inflate.fillMode = .forwards
        inflate.isRemovedOnCompletion = false
        balloonGroup.add(inflate, forKey: "inflate")

        // Rise up
        let rise = CASpringAnimation(keyPath: "position.y")
        rise.fromValue = cy + 50
        rise.toValue = cy
        rise.mass = 1.0
        rise.stiffness = 100
        rise.damping = 12
        rise.initialVelocity = 5
        rise.duration = rise.settlingDuration
        rise.beginTime = startTime
        rise.fillMode = .forwards
        rise.isRemovedOnCompletion = false
        balloonGroup.add(rise, forKey: "rise")

        // Color morph: red → yellow → green
        let bodyColorMorph = CAKeyframeAnimation(keyPath: "fillColor")
        bodyColorMorph.values = [
            DesignTokens.Colors.destructive.withAlphaComponent(0.85).cgColor,
            DesignTokens.Colors.warning.withAlphaComponent(0.85).cgColor,
            DesignTokens.Colors.success.withAlphaComponent(0.85).cgColor,
        ]
        bodyColorMorph.keyTimes = [0, 0.3, 1.0]
        bodyColorMorph.duration = 0.8
        bodyColorMorph.beginTime = startTime
        bodyColorMorph.fillMode = .forwards
        bodyColorMorph.isRemovedOnCompletion = false
        balloonBody.add(bodyColorMorph, forKey: "colorMorph")

        // Knot color morph
        let knotColorMorph = CAKeyframeAnimation(keyPath: "fillColor")
        knotColorMorph.values = [
            DesignTokens.Colors.destructive.withAlphaComponent(0.7).cgColor,
            DesignTokens.Colors.warning.withAlphaComponent(0.7).cgColor,
            DesignTokens.Colors.success.withAlphaComponent(0.7).cgColor,
        ]
        knotColorMorph.keyTimes = [0, 0.3, 1.0]
        knotColorMorph.duration = 0.8
        knotColorMorph.beginTime = startTime
        knotColorMorph.fillMode = .forwards
        knotColorMorph.isRemovedOnCompletion = false
        knotLayer.add(knotColorMorph, forKey: "knotColorMorph")

        // Highlight restores
        let hlRestore = CABasicAnimation(keyPath: "opacity")
        hlRestore.fromValue = 0.08
        hlRestore.toValue = 0.35
        hlRestore.duration = 0.6
        hlRestore.beginTime = startTime
        hlRestore.fillMode = .forwards
        hlRestore.isRemovedOnCompletion = false
        highlightLayer.add(hlRestore, forKey: "hlRestore")

        // Air burst particles + shockwave after the inflate peaks
        let impactDelay = delay + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + impactDelay) { [weak self] in
            guard let self else { return }
            let center = CGPoint(x: cx, y: cy)
            self.emitAirBurst(from: center)
            Haptics.heavy()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + impactDelay + 0.15) { [weak self] in
            guard let self else { return }
            let center = CGPoint(x: cx, y: cy)
            self.emitShockwave(from: center)
        }

        // Gentle float after settle
        let floatDelay = delay + 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + floatDelay) { [weak self] in
            guard let self else { return }
            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = cy - 4
            float.toValue = cy + 4
            float.duration = 2.5
            float.autoreverses = true
            float.repeatCount = .infinity
            float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.balloonGroup.add(float, forKey: "float")
        }
    }

    // MARK: - Particle Effects (Ported from BalloonCard)

    private func emitAirBurst(from center: CGPoint) {
        let particleCount = 10
        let colors: [UIColor] = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.accent,
            DesignTokens.Colors.success.withAlphaComponent(0.6),
        ]

        for i in 0..<particleCount {
            let dot = CAShapeLayer()
            let radius: CGFloat = CGFloat.random(in: 3...7)
            dot.path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)).cgPath
            dot.fillColor = colors[i % colors.count].cgColor
            dot.position = center
            dot.opacity = 0
            layer.addSublayer(dot)

            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance: CGFloat = CGFloat.random(in: 40...80)
            let endPoint = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )

            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(cgPoint: center)
            move.toValue = NSValue(cgPoint: endPoint)
            move.duration = Double.random(in: 0.3...0.5)
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.0, 0.9, 0.0]
            fade.keyTimes = [0.0, 0.2, 1.0]
            fade.duration = move.duration

            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = 1.0
            shrink.toValue = 0.1
            shrink.duration = move.duration

            let group = CAAnimationGroup()
            group.animations = [move, fade, shrink]
            group.duration = move.duration
            group.isRemovedOnCompletion = true
            dot.add(group, forKey: "burst_\(i)")

            let capturedDot = dot
            DispatchQueue.main.asyncAfter(deadline: .now() + move.duration) {
                capturedDot.removeFromSuperlayer()
            }
        }
    }

    private func emitShockwave(from center: CGPoint) {
        let ring = CAShapeLayer()
        let startRadius: CGFloat = 10
        ring.path = UIBezierPath(
            arcCenter: center, radius: startRadius,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = DesignTokens.Colors.success.withAlphaComponent(0.6).cgColor
        ring.lineWidth = 5
        ring.opacity = 0
        layer.addSublayer(ring)

        let maxRadius: CGFloat = 100
        let duration: CFTimeInterval = 0.5

        let expand = CABasicAnimation(keyPath: "path")
        expand.fromValue = UIBezierPath(arcCenter: center, radius: startRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        expand.toValue = UIBezierPath(arcCenter: center, radius: maxRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        expand.duration = duration
        expand.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let thin = CABasicAnimation(keyPath: "lineWidth")
        thin.fromValue = 5.0
        thin.toValue = 1.0
        thin.duration = duration

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.7, 0.0]
        fade.keyTimes = [0.0, 0.15, 1.0]
        fade.duration = duration

        let group = CAAnimationGroup()
        group.animations = [expand, thin, fade]
        group.duration = duration
        group.isRemovedOnCompletion = true
        ring.add(group, forKey: "shockwave")

        // Second fainter ring
        let ring2 = CAShapeLayer()
        ring2.path = ring.path
        ring2.fillColor = UIColor.clear.cgColor
        ring2.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor
        ring2.lineWidth = 3
        ring2.opacity = 0
        layer.addSublayer(ring2)

        let group2 = CAAnimationGroup()
        let expand2 = expand.copy() as! CABasicAnimation
        let thin2 = thin.copy() as! CABasicAnimation
        let fade2 = fade.copy() as! CAKeyframeAnimation
        group2.animations = [expand2, thin2, fade2]
        group2.duration = duration
        group2.beginTime = CACurrentMediaTime() + 0.06
        group2.isRemovedOnCompletion = true
        ring2.add(group2, forKey: "shockwave2")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.15) {
            ring.removeFromSuperlayer()
            ring2.removeFromSuperlayer()
        }
    }
}
