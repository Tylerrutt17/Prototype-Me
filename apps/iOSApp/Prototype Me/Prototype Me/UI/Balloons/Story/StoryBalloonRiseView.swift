import UIKit

/// Pages 2 & 5 visual: mini-balloons rising from the bottom with staggered spring animations.
/// In celebration mode (page 5), all balloons are green and a white flash plays on entrance.
final class StoryBalloonRiseView: UIView, StoryAnimatable {

    private let isCelebration: Bool
    private var balloonLayers: [(body: CAShapeLayer, origin: CGPoint)] = []
    private var hasSpawned = false
    private var badge: UIView?

    init(isCelebration: Bool) {
        self.isCelebration = isCelebration
        super.init(frame: .zero)
        clipsToBounds = false
        if !isCelebration { buildBadge() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasSpawned && bounds.width > 0 {
            hasSpawned = true
            spawnBalloons()
        }
    }

    private func spawnBalloons() {
        let normalColors: [UIColor] = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.warning,
            DesignTokens.Colors.accent,
            DesignTokens.Colors.accentSecondary,
        ]
        let celebrationColor = DesignTokens.Colors.success

        let count = 4
        let canvasW = bounds.width
        let canvasH = bounds.height

        for i in 0..<count {
            let balloonW: CGFloat = CGFloat.random(in: 30...44)
            let balloonH: CGFloat = balloonW * 1.25
            let x = (canvasW / CGFloat(count + 1)) * CGFloat(i + 1)
            let y = canvasH * CGFloat.random(in: 0.15...0.55)
            let color = isCelebration ? celebrationColor : normalColors[i % normalColors.count]

            let balloon = makeBalloonLayer(width: balloonW, height: balloonH, color: color)
            balloon.position = CGPoint(x: x, y: y)
            balloon.opacity = 0
            layer.addSublayer(balloon)
            balloonLayers.append((body: balloon, origin: CGPoint(x: x, y: y)))
        }
    }

    private func makeBalloonLayer(width w: CGFloat, height h: CGFloat, color: UIColor) -> CAShapeLayer {
        let balloon = CAShapeLayer()
        balloon.path = UIBezierPath(ovalIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h)).cgPath
        balloon.fillColor = color.withAlphaComponent(0.85).cgColor

        // Highlight
        let highlight = CAShapeLayer()
        let hlW = w * 0.25, hlH = h * 0.2
        highlight.path = UIBezierPath(ovalIn: CGRect(x: -w * 0.15, y: -h * 0.3, width: hlW, height: hlH)).cgPath
        highlight.fillColor = UIColor.white.withAlphaComponent(0.35).cgColor
        balloon.addSublayer(highlight)

        // Knot
        let knot = UIBezierPath()
        let knotY = h / 2
        knot.move(to: CGPoint(x: -3, y: knotY))
        knot.addLine(to: CGPoint(x: 0, y: knotY + 5))
        knot.addLine(to: CGPoint(x: 3, y: knotY))
        knot.close()
        let knotLayer = CAShapeLayer()
        knotLayer.path = knot.cgPath
        knotLayer.fillColor = color.withAlphaComponent(0.7).cgColor
        balloon.addSublayer(knotLayer)

        // String
        let stringPath = UIBezierPath()
        stringPath.move(to: CGPoint(x: 0, y: knotY + 5))
        stringPath.addQuadCurve(
            to: CGPoint(x: CGFloat.random(in: -6...6), y: knotY + 28),
            controlPoint: CGPoint(x: CGFloat.random(in: -10...10), y: knotY + 16)
        )
        let stringLayer = CAShapeLayer()
        stringLayer.path = stringPath.cgPath
        stringLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        stringLayer.fillColor = UIColor.clear.cgColor
        stringLayer.lineWidth = 1
        balloon.addSublayer(stringLayer)

        return balloon
    }

    // MARK: - Badge

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

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for entry in balloonLayers { entry.body.opacity = 1 }
            badge?.alpha = 1; badge?.transform = .identity
            return
        }

        for (i, entry) in balloonLayers.enumerated() {
            let delay = Double(i) * 0.12
            let balloon = entry.body
            let targetY = entry.origin.y

            // Start below
            balloon.position = CGPoint(x: entry.origin.x, y: bounds.height + 50)

            // Rise with spring
            let rise = CASpringAnimation(keyPath: "position.y")
            rise.fromValue = bounds.height + 50
            rise.toValue = targetY
            rise.mass = 1.0
            rise.stiffness = 80
            rise.damping = 10
            rise.initialVelocity = 0
            rise.duration = rise.settlingDuration
            rise.beginTime = CACurrentMediaTime() + delay
            rise.fillMode = .backwards
            balloon.add(rise, forKey: "rise")
            balloon.position = CGPoint(x: entry.origin.x, y: targetY)

            // Fade in
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.3
            fade.beginTime = CACurrentMediaTime() + delay
            fade.fillMode = .backwards
            balloon.opacity = 1
            balloon.add(fade, forKey: "fadeIn")

            // Continuous float after entrance settles
            let floatDelay = delay + 0.9

            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = targetY - 5
            float.toValue = targetY + 5
            float.duration = Double.random(in: 2.0...3.5)
            float.autoreverses = true
            float.repeatCount = .infinity
            float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            float.beginTime = CACurrentMediaTime() + floatDelay
            float.fillMode = .backwards
            balloon.add(float, forKey: "float")

            let sway = CABasicAnimation(keyPath: "position.x")
            sway.fromValue = entry.origin.x - 4
            sway.toValue = entry.origin.x + 4
            sway.duration = Double.random(in: 2.5...4.0)
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sway.beginTime = CACurrentMediaTime() + floatDelay + 0.3
            sway.fillMode = .backwards
            balloon.add(sway, forKey: "sway")
        }

        // Badge fades in after balloons settle
        if let badge {
            UIView.animate(withDuration: 0.4, delay: 0.7, options: .curveEaseOut) {
                badge.alpha = 1
                badge.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for entry in balloonLayers {
            entry.body.removeAllAnimations()
        }
    }

}
