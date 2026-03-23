import UIKit
import GRDB

/// Card-style cell showing a balloon directive with pressure + countdown + pump button.
final class BalloonCard: InteractiveCell {

    static let reuseID = "BalloonCard"

    private let titleLabel = UILabel()
    private let pressureIndicator = PressureIndicator()
    private let timerLabel = UILabel()
    private let pumpButton = UIButton(type: .system)
    private var displayLink: CADisplayLink?
    private var currentDirective: Directive?

    /// Set by the VC so the cell can write the pump reset directly.
    var dbQueue: DatabaseQueue?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        // Allow particles to escape card bounds
        clipsToBounds = false
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .medium)

        titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 2

        pressureIndicator.size = 20

        timerLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        timerLabel.textColor = DesignTokens.Colors.textPrimary
        timerLabel.textAlignment = .center

        var config = UIButton.Configuration.filled()
        config.title = "Pump"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePadding = DesignTokens.Spacing.xs
        config.cornerStyle = .capsule
        config.baseBackgroundColor = DesignTokens.Colors.accent
        config.baseForegroundColor = DesignTokens.Colors.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.sm,
            leading: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.sm,
            trailing: DesignTokens.Spacing.lg
        )
        pumpButton.configuration = config
        pumpButton.addTarget(self, action: #selector(pumpTapped), for: .touchUpInside)

        // Top row: pressure dot + title
        let topRow = UIStackView(arrangedSubviews: [pressureIndicator, titleLabel])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.sm
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, timerLabel, pumpButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            pressureIndicator.widthAnchor.constraint(equalToConstant: 20),
            pressureIndicator.heightAnchor.constraint(equalToConstant: 20),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with data: DirectiveRowData) {
        titleLabel.text = data.directive.title
        currentDirective = data.directive

        // Gray out pump button during cooldown
        let elapsed = Date.now.timeIntervalSince(data.directive.updatedAt)
        let ready = elapsed >= Self.pumpCooldown
        pumpButton.isEnabled = ready

        updateTimerDisplay()
        startDisplayTimer()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopDisplayTimer()
        currentDirective = nil
    }

    // MARK: - Live Timer

    private func startDisplayTimer() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(updateTick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 1, preferred: 1)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateTick() {
        updateTimerDisplay()
    }

    /// Minimum seconds since last pump before the button reappears.
    private static let pumpCooldown: TimeInterval = 60

    private func updateTimerDisplay() {
        guard let dir = currentDirective else { return }
        let remaining = dir.liveRemainingSec

        if remaining <= 0 {
            timerLabel.text = "Expired"
            timerLabel.textColor = DesignTokens.Colors.destructive
            pressureIndicator.configure(level: .red)
        } else {
            timerLabel.text = formatTime(remaining)
            if let level = dir.pressureLevel {
                switch level {
                case .green:  timerLabel.textColor = DesignTokens.Colors.success
                case .yellow: timerLabel.textColor = DesignTokens.Colors.warning
                case .red:    timerLabel.textColor = DesignTokens.Colors.destructive
                }
            }
            pressureIndicator.configure(level: dir.pressureLevel)
        }

        // Gray out pump button during cooldown, re-enable when ready
        let elapsed = Date.now.timeIntervalSince(dir.updatedAt)
        let ready = elapsed >= Self.pumpCooldown
        if pumpButton.isEnabled != ready {
            UIView.animate(withDuration: 0.3) {
                self.pumpButton.isEnabled = ready
            }
        }
    }

    // MARK: - Pump

    @objc private func pumpTapped() {
        guard let dir = currentDirective, let dbQueue else { return }

        let oldTimeText = timerLabel.text ?? ""

        // Build the pumped directive locally (don't write to DB yet)
        var pumped = dir
        pumped.balloonSnapshotSec = dir.balloonDurationSec
        pumped.updatedAt = Date()
        pumped.version += 1

        let newTimeText = formatTime(pumped.balloonDurationSec)

        // Animate first, write to DB when animation completes
        playPumpAnimation(oldTime: oldTimeText, newTime: newTimeText, newDirective: pumped) {
            do {
                try dbQueue.write { db in
                    guard var directive = try Directive.fetchOne(db, key: dir.id) else { return }
                    directive.balloonSnapshotSec = directive.balloonDurationSec
                    directive.updatedAt = Date()
                    directive.version += 1
                    try directive.update(db)
                }
            } catch {
                Haptics.error()
            }
        }
        Haptics.success()
    }

    // MARK: - Pump Animation

    private func playPumpAnimation(oldTime: String, newTime: String, newDirective: Directive, onComplete: (() -> Void)? = nil) {
        // Disable pump button during animation to prevent stacking
        pumpButton.isUserInteractionEnabled = false

        // 1) Card inflate + spring bounce
        let inflate = CASpringAnimation(keyPath: "transform.scale")
        inflate.fromValue = 1.0
        inflate.toValue = 1.0
        inflate.mass = 1.0
        inflate.stiffness = 300
        inflate.damping = 8
        inflate.initialVelocity = 18
        inflate.duration = inflate.settlingDuration
        layer.add(inflate, forKey: "pumpInflate")

        // 2) Fill-up whoosh — gradient band sweeps bottom → top
        let whoosh = CAGradientLayer()
        whoosh.frame = contentView.bounds
        whoosh.cornerRadius = DesignTokens.Radii.lg
        whoosh.masksToBounds = true
        let fillColor = DesignTokens.Colors.success.withAlphaComponent(0.3).cgColor
        let clearColor = UIColor.clear.cgColor
        whoosh.colors = [clearColor, fillColor, fillColor, clearColor]
        whoosh.locations = [0.0, 0.3, 0.7, 1.0]
        whoosh.startPoint = CGPoint(x: 0.5, y: 0.0)
        whoosh.endPoint = CGPoint(x: 0.5, y: 1.0)
        whoosh.transform = CATransform3DMakeTranslation(0, contentView.bounds.height, 0)
        contentView.layer.addSublayer(whoosh)

        let sweep = CABasicAnimation(keyPath: "transform.translation.y")
        sweep.fromValue = contentView.bounds.height
        sweep.toValue = -contentView.bounds.height
        sweep.duration = 0.45
        sweep.timingFunction = CAMediaTimingFunction(name: .easeIn)

        let whooshFade = CAKeyframeAnimation(keyPath: "opacity")
        whooshFade.values = [0.0, 1.0, 1.0, 0.0]
        whooshFade.keyTimes = [0.0, 0.1, 0.7, 1.0]
        whooshFade.duration = 0.45

        let whooshGroup = CAAnimationGroup()
        whooshGroup.animations = [sweep, whooshFade]
        whooshGroup.duration = 0.45
        whooshGroup.isRemovedOnCompletion = true
        whoosh.add(whooshGroup, forKey: "whoosh")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            whoosh.removeFromSuperlayer()
        }

        // 3) Timer text: scale up (old time) → rewind spin → slam down (new time) → shockwave
        timerLabel.textColor = DesignTokens.Colors.success
        timerLabel.text = oldTime  // keep old time visible

        // Phase 1: Scale up with old time
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
            self.timerLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        } completion: { _ in
            // Phase 2: Rewind spin — 360° counter-clockwise rotation while held big
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = -CGFloat.pi * 2
            spin.duration = 0.25
            spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.timerLabel.layer.add(spin, forKey: "rewindSpin")

            // Swap text to new time midway through the spin (when it's upside down / blurred by motion)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.timerLabel.text = newTime
            }

            // Phase 3: After spin completes, slam down
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                // Update the directive now so live timer takes over with correct data
                self.currentDirective = newDirective
                self.pressureIndicator.configure(level: newDirective.pressureLevel)

                UIView.animate(withDuration: 0.06, delay: 0, options: .curveEaseIn) {
                    self.timerLabel.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                } completion: { _ in
                    // Phase 4: Bounce settle
                    UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 8) {
                        self.timerLabel.transform = .identity
                    }

                    // Phase 5: Shockwave on impact
                    let timerCenter = self.timerLabel.superview!.convert(self.timerLabel.center, to: self.contentView)
                    self.emitShockwave(from: timerCenter)

                    // Heavier haptic on impact
                    Haptics.heavy()

                    // Re-enable pump + write to DB
                    self.pumpButton.isUserInteractionEnabled = true
                    onComplete?()
                }
            }
        }

        // 4) Air burst particles radiating from pump button
        let buttonCenter = pumpButton.superview!.convert(pumpButton.center, to: self)
        emitAirBurst(from: buttonCenter)

        // 5) Pump button mini-press
        UIView.animate(withDuration: 0.08) {
            self.pumpButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0) {
                self.pumpButton.transform = .identity
            }
        }
    }

    private func emitShockwave(from center: CGPoint) {
        // Radial gradient ring that expands outward from impact point
        let ring = CAShapeLayer()
        let startRadius: CGFloat = 8
        ring.path = UIBezierPath(
            arcCenter: center,
            radius: startRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = DesignTokens.Colors.success.withAlphaComponent(0.6).cgColor
        ring.lineWidth = 6
        ring.opacity = 0
        contentView.layer.addSublayer(ring)

        let maxRadius: CGFloat = max(contentView.bounds.width, contentView.bounds.height) * 0.7
        let duration: CFTimeInterval = 0.45

        // Expand the ring
        let expand = CABasicAnimation(keyPath: "path")
        expand.fromValue = UIBezierPath(
            arcCenter: center, radius: startRadius,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath
        expand.toValue = UIBezierPath(
            arcCenter: center, radius: maxRadius,
            startAngle: 0, endAngle: .pi * 2, clockwise: true
        ).cgPath
        expand.duration = duration
        expand.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // Thin out the stroke as it expands
        let thin = CABasicAnimation(keyPath: "lineWidth")
        thin.fromValue = 6.0
        thin.toValue = 1.0
        thin.duration = duration

        // Fade out
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.7, 0.0]
        fade.keyTimes = [0.0, 0.15, 1.0]
        fade.duration = duration

        let group = CAAnimationGroup()
        group.animations = [expand, thin, fade]
        group.duration = duration
        group.isRemovedOnCompletion = true
        ring.add(group, forKey: "shockwave")

        // Second, fainter ring slightly delayed for depth
        let ring2 = CAShapeLayer()
        ring2.path = ring.path
        ring2.fillColor = UIColor.clear.cgColor
        ring2.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor
        ring2.lineWidth = 3
        ring2.opacity = 0
        contentView.layer.addSublayer(ring2)

        let group2 = CAAnimationGroup()
        let expand2 = expand.copy() as! CABasicAnimation
        let thin2 = thin.copy() as! CABasicAnimation
        let fade2 = fade.copy() as! CAKeyframeAnimation
        group2.animations = [expand2, thin2, fade2]
        group2.duration = duration
        group2.beginTime = CACurrentMediaTime() + 0.06
        group2.isRemovedOnCompletion = true
        ring2.add(group2, forKey: "shockwave2")

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            ring.removeFromSuperlayer()
            ring2.removeFromSuperlayer()
        }
    }

    private func emitAirBurst(from center: CGPoint) {
        let particleCount = 10
        let colors: [UIColor] = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.accent,
            DesignTokens.Colors.success.withAlphaComponent(0.6),
        ]

        for i in 0..<particleCount {
            let dot = CAShapeLayer()
            let radius: CGFloat = CGFloat.random(in: 3...6)
            dot.path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)).cgPath
            dot.fillColor = colors[i % colors.count].cgColor
            dot.position = center
            dot.opacity = 0
            layer.addSublayer(dot)

            // Radial direction
            let angle = (CGFloat(i) / CGFloat(particleCount)) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance: CGFloat = CGFloat.random(in: 35...65)
            let endPoint = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance
            )

            // Position animation
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(cgPoint: center)
            move.toValue = NSValue(cgPoint: endPoint)
            move.duration = Double.random(in: 0.3...0.5)
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)

            // Fade + shrink
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

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    @MainActor deinit {
        stopDisplayTimer()
    }
}
