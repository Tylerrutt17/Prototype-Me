import UIKit

/// Page 6: Condensed balloon lifecycle — balloons rise, one deflates, then pumps back up.
/// Includes "Built on Cognitive Science" badge.
final class OnboardingBalloonDemoView: UIView, StoryAnimatable {

    private var balloonLayers: [(body: CAShapeLayer, origin: CGPoint)] = []
    private var hasSpawned = false
    private var badge: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        buildBadge()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasSpawned && bounds.width > 0 {
            hasSpawned = true
            spawnBalloons()
        }
    }

    private func spawnBalloons() {
        let colors: [UIColor] = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.accent,
            DesignTokens.Colors.accentTertiary,
        ]
        let count = 3
        let canvasW = bounds.width
        let canvasH = bounds.height - 50 // leave room for badge

        for i in 0..<count {
            let w: CGFloat = CGFloat.random(in: 30...40)
            let h = w * 1.25
            let x = (canvasW / CGFloat(count + 1)) * CGFloat(i + 1)
            let y = canvasH * CGFloat.random(in: 0.2...0.5)

            let balloon = CAShapeLayer()
            balloon.path = UIBezierPath(ovalIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)).cgPath
            balloon.fillColor = colors[i].withAlphaComponent(0.85).cgColor
            balloon.position = CGPoint(x: x, y: y)
            balloon.opacity = 0

            // Highlight
            let hl = CAShapeLayer()
            hl.path = UIBezierPath(ovalIn: CGRect(x: -w * 0.15, y: -h * 0.3, width: w * 0.25, height: h * 0.2)).cgPath
            hl.fillColor = UIColor.white.withAlphaComponent(0.35).cgColor
            balloon.addSublayer(hl)

            // Knot
            let knot = UIBezierPath()
            knot.move(to: CGPoint(x: -3, y: h / 2))
            knot.addLine(to: CGPoint(x: 0, y: h / 2 + 5))
            knot.addLine(to: CGPoint(x: 3, y: h / 2))
            knot.close()
            let knotLayer = CAShapeLayer()
            knotLayer.path = knot.cgPath
            knotLayer.fillColor = colors[i].withAlphaComponent(0.7).cgColor
            balloon.addSublayer(knotLayer)

            layer.addSublayer(balloon)
            balloonLayers.append((body: balloon, origin: CGPoint(x: x, y: y)))
        }
    }

    private func buildBadge() {
        let pill = UIView()
        pill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        pill.layer.cornerRadius = DesignTokens.Radii.pill
        pill.layer.borderWidth = 1
        pill.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.25).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "flask.fill"))
        icon.tintColor = DesignTokens.Colors.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Built on Cognitive Science"
        label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        label.textColor = DesignTokens.Colors.accent

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        addSubview(pill)
        badge = pill

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: DesignTokens.Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -DesignTokens.Spacing.md),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.sm),
        ])

        pill.alpha = 0
        pill.transform = CGAffineTransform(translationX: 0, y: 10)
    }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for entry in balloonLayers { entry.body.opacity = 1 }
            badge?.alpha = 1; badge?.transform = .identity
            return
        }

        // Rise balloons in
        for (i, entry) in balloonLayers.enumerated() {
            let delay = Double(i) * 0.12
            let balloon = entry.body
            let targetY = entry.origin.y

            balloon.position = CGPoint(x: entry.origin.x, y: bounds.height + 40)

            let rise = CASpringAnimation(keyPath: "position.y")
            rise.fromValue = bounds.height + 40
            rise.toValue = targetY
            rise.mass = 1.0
            rise.stiffness = 80
            rise.damping = 10
            rise.duration = rise.settlingDuration
            rise.beginTime = CACurrentMediaTime() + delay
            rise.fillMode = .backwards
            balloon.add(rise, forKey: "rise")
            balloon.position = CGPoint(x: entry.origin.x, y: targetY)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.3
            fade.beginTime = CACurrentMediaTime() + delay
            fade.fillMode = .backwards
            balloon.opacity = 1
            balloon.add(fade, forKey: "fadeIn")

            // Float
            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = targetY - 4
            float.toValue = targetY + 4
            float.duration = Double.random(in: 2.0...3.0)
            float.autoreverses = true
            float.repeatCount = .infinity
            float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            float.beginTime = CACurrentMediaTime() + delay + 0.8
            float.fillMode = .backwards
            balloon.add(float, forKey: "float")
        }

        // After balloons settle, deflate the middle one then pump it back
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.playDeflateAndPump()
        }

        // Badge
        if let badge {
            UIView.animate(withDuration: 0.4, delay: 0.7, options: .curveEaseOut) {
                badge.alpha = 1
                badge.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for entry in balloonLayers { entry.body.removeAllAnimations() }
    }

    // MARK: - Deflate & Pump Sequence

    private func playDeflateAndPump() {
        guard balloonLayers.count > 1 else { return }
        let balloon = balloonLayers[1].body

        // Deflate: shrink + color to red
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1.0
        shrink.toValue = 0.6
        shrink.duration = 1.5
        shrink.fillMode = .forwards
        shrink.isRemovedOnCompletion = false
        balloon.add(shrink, forKey: "shrink")

        let colorMorph = CABasicAnimation(keyPath: "fillColor")
        colorMorph.toValue = DesignTokens.Colors.destructive.withAlphaComponent(0.85).cgColor
        colorMorph.duration = 1.5
        colorMorph.fillMode = .forwards
        colorMorph.isRemovedOnCompletion = false
        balloon.add(colorMorph, forKey: "deflateColor")

        // After deflate, pump back up
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let inflate = CASpringAnimation(keyPath: "transform.scale")
            inflate.fromValue = 0.6
            inflate.toValue = 1.0
            inflate.mass = 1.0
            inflate.stiffness = 300
            inflate.damping = 8
            inflate.initialVelocity = 18
            inflate.duration = inflate.settlingDuration
            inflate.fillMode = .forwards
            inflate.isRemovedOnCompletion = false
            balloon.add(inflate, forKey: "inflate")

            let pumpColor = CABasicAnimation(keyPath: "fillColor")
            pumpColor.toValue = DesignTokens.Colors.success.withAlphaComponent(0.85).cgColor
            pumpColor.duration = 0.5
            pumpColor.fillMode = .forwards
            pumpColor.isRemovedOnCompletion = false
            balloon.add(pumpColor, forKey: "pumpColor")

            Haptics.heavy()
        }
    }
}
