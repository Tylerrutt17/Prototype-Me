import UIKit

/// Shows a central circle representing "you" with green dots (strengths)
/// and red dots (weak points) inside. Then situational clusters appear
/// outside with their own red dots.
final class OnboardingWeakPointsView: UIView, StoryAnimatable {

    private let coreCircle = UIView()
    private let coreLabel = UILabel()
    private var coreDots: [UIView] = []
    private var situationalClusters: [(container: UIView, label: UILabel, dots: [UIView])] = []
    private var hasBuilt = false

    // Core dots: true = green (strength), false = red (weak point)
    private let coreDotData: [Bool] = [
        true, true, false, true, false, true, true, false, true, true, true, false
    ]

    private let situations: [(name: String, dotCount: Int)] = [
        ("At work", 3),
        ("When exhausted", 2),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildLayout()
        }
    }

    private func buildLayout() {
        let cx = bounds.midX
        let cy = bounds.midY - 10
        let circleRadius: CGFloat = min(bounds.width, bounds.height) * 0.28

        // Core circle
        coreCircle.frame = CGRect(
            x: cx - circleRadius,
            y: cy - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        coreCircle.layer.cornerRadius = circleRadius
        coreCircle.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.3)
        coreCircle.layer.borderWidth = 1.5
        coreCircle.layer.borderColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.3).cgColor
        coreCircle.alpha = 0
        addSubview(coreCircle)

        // "You" label
        coreLabel.text = "YOU"
        coreLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        coreLabel.textColor = DesignTokens.Colors.textTertiary
        coreLabel.sizeToFit()
        coreLabel.center = CGPoint(x: cx, y: cy - circleRadius - 14)
        coreLabel.alpha = 0
        addSubview(coreLabel)

        // Core dots scattered inside the circle
        for isStrength in coreDotData {
            let dotSize: CGFloat = CGFloat.random(in: 8...13)
            let dot = UIView()
            dot.layer.cornerRadius = dotSize / 2
            dot.backgroundColor = isStrength
                ? DesignTokens.Colors.success.withAlphaComponent(0.7)
                : DesignTokens.Colors.destructive.withAlphaComponent(0.7)
            dot.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
            dot.alpha = 0

            // Random position inside circle
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 0...(circleRadius * 0.75))
            dot.center = CGPoint(
                x: cx + cos(angle) * dist,
                y: cy + sin(angle) * dist
            )

            addSubview(dot)
            coreDots.append(dot)
        }

        // Situational clusters outside the circle
        let clusterPositions: [CGPoint] = [
            CGPoint(x: cx - circleRadius - 45, y: cy + circleRadius + 35),
            CGPoint(x: cx + circleRadius + 45, y: cy + circleRadius + 35),
        ]

        for (i, situation) in situations.enumerated() where i < clusterPositions.count {
            let pos = clusterPositions[i]

            let container = UIView()
            container.alpha = 0
            addSubview(container)

            let label = UILabel()
            label.text = situation.name.uppercased()
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            label.textColor = NoteKind.mode.color
            label.sizeToFit()
            label.center = CGPoint(x: pos.x, y: pos.y - 18)
            addSubview(label)
            label.alpha = 0

            var dots: [UIView] = []
            for j in 0..<situation.dotCount {
                let dotSize: CGFloat = 10
                let dot = UIView()
                dot.layer.cornerRadius = dotSize / 2
                dot.backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.7)
                dot.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
                dot.alpha = 0
                let offset = CGFloat(j - situation.dotCount / 2) * 16
                dot.center = CGPoint(x: pos.x + offset, y: pos.y + 5)
                addSubview(dot)
                dots.append(dot)
            }

            situationalClusters.append((container, label, dots))
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            coreCircle.alpha = 1
            coreLabel.alpha = 1
            for dot in coreDots { dot.alpha = 1 }
            for cluster in situationalClusters {
                cluster.label.alpha = 1
                for dot in cluster.dots { dot.alpha = 1 }
            }
            return
        }

        // Phase 1: Core circle + label appear
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.coreCircle.alpha = 1
            self.coreLabel.alpha = 1
        }

        // Phase 2: Green dots appear (strengths)
        let greenDots = coreDots.enumerated().filter { coreDotData[$0.offset] }
        for (i, (_, dot)) in greenDots.enumerated() {
            UIView.animate(withDuration: 0.3, delay: 0.5 + Double(i) * 0.06) {
                dot.alpha = 1
            }
        }

        // Phase 3: Red dots appear among them (weak points) — with a slight pulse
        let redDots = coreDots.enumerated().filter { !coreDotData[$0.offset] }
        let redStartTime = 0.5 + Double(greenDots.count) * 0.06 + 0.4

        for (i, (_, dot)) in redDots.enumerated() {
            let delay = redStartTime + Double(i) * 0.15
            UIView.animate(withDuration: 0.2, delay: delay) {
                dot.alpha = 1
            }
            // Pulse
            UIView.animate(withDuration: 0.3, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                dot.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    dot.transform = .identity
                }
            }
        }

        // Phase 4: Situational clusters appear
        let situationalStartTime = redStartTime + Double(redDots.count) * 0.15 + 0.6

        for (i, cluster) in situationalClusters.enumerated() {
            let delay = situationalStartTime + Double(i) * 0.4

            UIView.animate(withDuration: 0.3, delay: delay) {
                cluster.label.alpha = 1
            }
            for (j, dot) in cluster.dots.enumerated() {
                let dotDelay = delay + 0.15 + Double(j) * 0.1
                UIView.animate(withDuration: 0.2, delay: dotDelay) {
                    dot.alpha = 1
                }
                UIView.animate(withDuration: 0.3, delay: dotDelay, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                    dot.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
                } completion: { _ in
                    UIView.animate(withDuration: 0.2) {
                        dot.transform = .identity
                    }
                }
            }
        }

        // Phase 5: Gentle pulse on red dots to keep attention
        let pulseStart = situationalStartTime + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + pulseStart) { [weak self] in
            guard let self else { return }
            let allRedDots = self.coreDots.enumerated().filter { !self.coreDotData[$0.offset] }.map(\.element)
                + self.situationalClusters.flatMap(\.dots)

            for dot in allRedDots {
                UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut]) {
                    dot.alpha = 0.4
                }
            }
        }
    }

    func stopAnimations() {
        for dot in coreDots { dot.layer.removeAllAnimations() }
        for cluster in situationalClusters {
            for dot in cluster.dots { dot.layer.removeAllAnimations() }
        }
        coreCircle.layer.removeAllAnimations()
    }
}
