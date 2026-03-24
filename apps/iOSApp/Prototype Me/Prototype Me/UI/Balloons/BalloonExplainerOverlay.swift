import UIKit

/// Full-screen overlay with animated mini-balloons that explains the Balloons feature.
final class BalloonExplainerOverlay: UIView {

    private let dimView = UIView()
    private let panel = GlassPanelView(cornerRadius: DesignTokens.Radii.xl)
    private let balloonCanvas = UIView()
    private var miniBalloons: [CAShapeLayer] = []
    private var stringLayers: [CAShapeLayer] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setup() {
        // Dim background
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        dimView.addGestureRecognizer(tap)

        // Panel
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -DesignTokens.Spacing.xl),
        ])

        // Balloon canvas (above text, inside panel)
        balloonCanvas.translatesAutoresizingMaskIntoConstraints = false
        balloonCanvas.clipsToBounds = false
        panel.addSubview(balloonCanvas)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "What are Balloons?"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center

        // Body text — multi-step explanation
        let steps: [(icon: String, text: String)] = [
            ("timer", "Each balloon is a countdown timer attached to a directive."),
            ("arrow.down.circle", "Over time, balloons slowly deflate — losing air as the clock ticks down."),
            ("arrow.clockwise", "Tap \"Pump\" to refill a balloon and reset its timer."),
            ("circle.fill", "Colors show urgency: green is healthy, yellow needs attention, red is critical."),
        ]

        let stepsStack = UIStackView()
        stepsStack.axis = .vertical
        stepsStack.spacing = DesignTokens.Spacing.md

        for step in steps {
            let row = makeStepRow(icon: step.icon, text: step.text)
            stepsStack.addArrangedSubview(row)
        }

        // Dismiss button
        let dismissButton = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Got it!"
        config.baseBackgroundColor = DesignTokens.Colors.accent
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.sm,
            leading: DesignTokens.Spacing.xxl,
            bottom: DesignTokens.Spacing.sm,
            trailing: DesignTokens.Spacing.xxl
        )
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            return outgoing
        }
        dismissButton.configuration = config
        dismissButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        // Content stack
        let contentStack = UIStackView(arrangedSubviews: [balloonCanvas, titleLabel, stepsStack, dismissButton])
        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.lg
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(contentStack)

        let pad = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            balloonCanvas.heightAnchor.constraint(equalToConstant: 90),
            balloonCanvas.widthAnchor.constraint(equalTo: contentStack.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: panel.topAnchor, constant: pad),
            contentStack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: pad),
            contentStack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -pad),
            contentStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -pad),

            stepsStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            stepsStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])
    }

    private func makeStepRow(icon: String, text: String) -> UIView {
        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = DesignTokens.Colors.accent
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .regular)
        label.textColor = DesignTokens.Colors.textSecondary
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [imageView, label])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .top
        return row
    }

    // MARK: - Animated Mini Balloons

    override func layoutSubviews() {
        super.layoutSubviews()
        if miniBalloons.isEmpty && balloonCanvas.bounds.width > 0 {
            spawnMiniBalloons()
        }
    }

    private func spawnMiniBalloons() {
        let colors: [UIColor] = [
            DesignTokens.Colors.success,
            DesignTokens.Colors.warning,
            DesignTokens.Colors.destructive,
            DesignTokens.Colors.accent,
            DesignTokens.Colors.accentSecondary,
        ]

        let count = 5
        let canvasW = balloonCanvas.bounds.width
        let canvasH = balloonCanvas.bounds.height

        for i in 0..<count {
            let balloonW: CGFloat = CGFloat.random(in: 24...36)
            let balloonH: CGFloat = balloonW * 1.25
            let x = (canvasW / CGFloat(count + 1)) * CGFloat(i + 1)
            let y = canvasH * CGFloat.random(in: 0.2...0.6)

            // Balloon body
            let balloon = CAShapeLayer()
            balloon.path = UIBezierPath(ovalIn: CGRect(x: -balloonW / 2, y: -balloonH / 2, width: balloonW, height: balloonH)).cgPath
            balloon.fillColor = colors[i % colors.count].withAlphaComponent(0.85).cgColor
            balloon.position = CGPoint(x: x, y: y)
            balloon.opacity = 0
            balloonCanvas.layer.addSublayer(balloon)
            miniBalloons.append(balloon)

            // Highlight
            let highlight = CAShapeLayer()
            let hlW = balloonW * 0.25
            let hlH = balloonH * 0.2
            highlight.path = UIBezierPath(ovalIn: CGRect(x: -balloonW * 0.15, y: -balloonH * 0.3, width: hlW, height: hlH)).cgPath
            highlight.fillColor = UIColor.white.withAlphaComponent(0.35).cgColor
            balloon.addSublayer(highlight)

            // Knot
            let knot = UIBezierPath()
            let knotY = balloonH / 2
            knot.move(to: CGPoint(x: -3, y: knotY))
            knot.addLine(to: CGPoint(x: 0, y: knotY + 5))
            knot.addLine(to: CGPoint(x: 3, y: knotY))
            knot.close()
            let knotLayer = CAShapeLayer()
            knotLayer.path = knot.cgPath
            knotLayer.fillColor = colors[i % colors.count].withAlphaComponent(0.7).cgColor
            balloon.addSublayer(knotLayer)

            // String
            let stringPath = UIBezierPath()
            let stringStart = CGPoint(x: 0, y: knotY + 5)
            stringPath.move(to: stringStart)
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
            stringLayers.append(stringLayer)
        }
    }

    private func animateEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for balloon in miniBalloons { balloon.opacity = 1 }
            return
        }

        // Balloons rise in from below with staggered timing
        for (i, balloon) in miniBalloons.enumerated() {
            let delay = Double(i) * 0.1
            let originalPos = balloon.position

            // Start below canvas
            balloon.position = CGPoint(x: originalPos.x, y: balloonCanvas.bounds.height + 40)

            // Rise up
            let rise = CASpringAnimation(keyPath: "position.y")
            rise.fromValue = balloonCanvas.bounds.height + 40
            rise.toValue = originalPos.y
            rise.mass = 1.0
            rise.stiffness = 80
            rise.damping = 10
            rise.initialVelocity = 0
            rise.duration = rise.settlingDuration
            rise.beginTime = CACurrentMediaTime() + delay
            rise.fillMode = .backwards
            balloon.add(rise, forKey: "rise")

            // Fade in
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.3
            fade.beginTime = CACurrentMediaTime() + delay
            fade.fillMode = .backwards
            balloon.opacity = 1
            balloon.add(fade, forKey: "fadeIn")

            // Continuous gentle float after entrance
            let float = CABasicAnimation(keyPath: "position.y")
            float.fromValue = originalPos.y - 4
            float.toValue = originalPos.y + 4
            float.duration = Double.random(in: 2.0...3.5)
            float.autoreverses = true
            float.repeatCount = .infinity
            float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            float.beginTime = CACurrentMediaTime() + delay + 0.8
            float.fillMode = .backwards
            balloon.add(float, forKey: "float")

            // Gentle horizontal sway
            let sway = CABasicAnimation(keyPath: "position.x")
            sway.fromValue = originalPos.x - 3
            sway.toValue = originalPos.x + 3
            sway.duration = Double.random(in: 2.5...4.0)
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sway.beginTime = CACurrentMediaTime() + delay + 1.0
            sway.fillMode = .backwards
            balloon.add(sway, forKey: "sway")
        }
    }

    // MARK: - Present / Dismiss

    func showAnimated(in parentView: UIView) {
        alpha = 0
        parentView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
        ])

        parentView.layoutIfNeeded()

        // Scale-in panel
        panel.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.panel.transform = .identity
        } completion: { _ in
            self.animateEntrance()
        }

        Haptics.light()
    }

    @objc private func dismiss() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.panel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}
