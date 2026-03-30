import UIKit

/// Screen 2: A line that draws itself showing the rise-and-fall cycle of trying to build a habit.
/// Annotated with text callouts that appear at key moments, telling the user's inner monologue.
final class OnboardingBuildFadeView: UIView, StoryAnimatable {

    private let lineLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
    private var annotationBubbles: [UIView] = []
    private var annotationLabels: [UILabel] = []
    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0  // Incremented each cycle so stale dispatches are ignored

    // Annotations: (fraction along the line where it appears, text, position, momentum direction)
    private struct Annotation {
        let t: CGFloat           // 0-1 position along the line
        let text: String
        let above: Bool          // true = above the line, false = below
        let color: UIColor
        let rising: Bool         // true = line is rising here (slide up), false = falling (slide down)
    }

    private let annotations: [Annotation] = [
        Annotation(t: 0.05,  text: "Start a new habit",     above: false, color: DesignTokens.Colors.textSecondary, rising: true),
        Annotation(t: 0.17,  text: "It's working!",         above: true,  color: DesignTokens.Colors.success,       rising: true),
        Annotation(t: 0.30,  text: "Life gets busy...",      above: true,  color: DesignTokens.Colors.textTertiary,  rising: false),
        Annotation(t: 0.44,  text: "...what habit?",         above: true,  color: DesignTokens.Colors.warning,       rising: false),
        Annotation(t: 0.58,  text: "Oh right. That thing.",  above: false, color: DesignTokens.Colors.textSecondary, rising: true),
        Annotation(t: 0.72,  text: "Ok I'm back",           above: true,  color: DesignTokens.Colors.success,       rising: true),
        Annotation(t: 0.88,  text: "...not again",           above: true,  color: DesignTokens.Colors.warning,       rising: false),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    private func buildVisual() {
        let rect = bounds.insetBy(dx: DesignTokens.Spacing.lg, dy: DesignTokens.Spacing.xxxl)
        let path = buildRiseFallPath(in: rect)

        // Soft glow
        glowLayer.path = path.cgPath
        glowLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.15).cgColor
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.lineWidth = 10
        glowLayer.lineCap = .round
        glowLayer.lineJoin = .round
        glowLayer.strokeEnd = 0
        layer.addSublayer(glowLayer)

        // Main line
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.85).cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineCap = .round
        lineLayer.lineJoin = .round
        lineLayer.strokeEnd = 0
        layer.addSublayer(lineLayer)

        // Build annotation bubbles
        let padH: CGFloat = 10
        let padV: CGFloat = 6

        for annotation in annotations {
            let lineY = yPosition(at: annotation.t, in: rect)
            let x = rect.minX + annotation.t * rect.width

            // Label
            let label = UILabel()
            label.text = annotation.text
            label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            label.textColor = annotation.color
            label.textAlignment = .center
            label.sizeToFit()

            // Bubble container
            let bubble = UIView()
            bubble.backgroundColor = DesignTokens.Colors.surfacePrimary.withAlphaComponent(0.9)
            bubble.layer.cornerRadius = (label.frame.height + padV * 2) / 2
            bubble.layer.borderWidth = 1
            bubble.layer.borderColor = annotation.color.withAlphaComponent(0.2).cgColor

            let bubbleWidth = label.frame.width + padH * 2
            let bubbleHeight = label.frame.height + padV * 2

            label.frame = CGRect(x: padH, y: padV, width: label.frame.width, height: label.frame.height)
            bubble.addSubview(label)

            let bubbleY: CGFloat
            if annotation.above {
                bubbleY = lineY - bubbleHeight - 8
            } else {
                bubbleY = lineY + 8
            }

            bubble.frame = CGRect(
                x: max(rect.minX, min(rect.maxX - bubbleWidth, x - bubbleWidth / 2)),
                y: bubbleY,
                width: bubbleWidth,
                height: bubbleHeight
            )

            bubble.alpha = 0
            bubble.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)

            addSubview(bubble)
            annotationBubbles.append(bubble)
            annotationLabels.append(label)
        }
    }

    // MARK: - Path

    private func buildRiseFallPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let steps = 200

        path.move(to: CGPoint(x: rect.minX, y: yPosition(at: 0, in: rect)))

        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width
            let y = yPosition(at: t, in: rect)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }

    /// Y position at a given t (0-1). Two rise-and-fall humps with a long flatline between them.
    private func yPosition(at t: CGFloat, in rect: CGRect) -> CGFloat {
        let baseY = rect.maxY - rect.height * 0.1
        let maxRise = rect.height * 0.7

        // Hump 1: strong start (0.02 - 0.34)
        // Flatline: completely forgot (0.34 - 0.58)
        // Hump 2: try again, lower peak (0.58 - 0.88)
        // Trailing flatline (0.88 - 1.0)
        let cycles: [(start: CGFloat, width: CGFloat, peak: CGFloat)] = [
            (0.02, 0.32, 0.85),   // First attempt — strong
            (0.58, 0.30, 0.65),   // Second attempt — doesn't get as high
        ]

        for cycle in cycles {
            let end = cycle.start + cycle.width
            if t >= cycle.start && t <= end {
                let localT = (t - cycle.start) / cycle.width
                let shape = sin(localT * .pi)
                let skewed = pow(shape, 0.75)
                return baseY - skewed * maxRise * cycle.peak
            }
        }

        return baseY
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            lineLayer.strokeEnd = 1
            glowLayer.strokeEnd = 1
            for bubble in annotationBubbles { bubble.alpha = 1; bubble.transform = .identity }
            return
        }

        playOneCycle()
    }

    private func playOneCycle() {
        guard !isStopped else { return }

        cycleID += 1
        let currentCycle = cycleID
        let drawDuration: Double = 8.0

        // Draw the line
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = drawDuration
        draw.beginTime = CACurrentMediaTime() + 0.2
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(name: .linear)

        lineLayer.strokeEnd = 1
        lineLayer.add(draw, forKey: "draw")
        glowLayer.strokeEnd = 1
        glowLayer.add(draw, forKey: "draw")

        // Show bubbles one at a time: scale up + fade in → hold → scale down + fade out
        for (i, annotation) in annotations.enumerated() {
            guard i < annotationBubbles.count else { break }
            let bubble = annotationBubbles[i]
            let appearDelay = 0.2 + Double(annotation.t) * drawDuration

            // Appear
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
                    bubble.alpha = 1
                    bubble.transform = .identity
                }
            }

            // Disappear (separate dispatch so it can't conflict)
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay + 1.1) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
                    bubble.alpha = 0
                    bubble.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                }
            }
        }

        // After the full cycle, retract the line right-to-left, then loop
        let retractDelay = 0.2 + drawDuration + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + retractDelay) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.retractLine {
                guard !self.isStopped, self.cycleID == currentCycle else { return }
                self.resetState()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                    self.playOneCycle()
                }
            }
        }
    }

    /// Animates strokeStart from 0→1 so the line "erases" left to right quickly.
    private func retractLine(completion: @escaping () -> Void) {
        let retractDuration: CFTimeInterval = 0.6

        let retract = CABasicAnimation(keyPath: "strokeStart")
        retract.fromValue = 0
        retract.toValue = 1
        retract.duration = retractDuration
        retract.timingFunction = CAMediaTimingFunction(name: .easeIn)
        retract.fillMode = .forwards
        retract.isRemovedOnCompletion = false

        lineLayer.add(retract, forKey: "retract")
        glowLayer.add(retract, forKey: "retract")

        DispatchQueue.main.asyncAfter(deadline: .now() + retractDuration) {
            completion()
        }
    }

    /// Resets all visual state so the animation can replay cleanly.
    private func resetState() {
        lineLayer.removeAllAnimations()
        glowLayer.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lineLayer.strokeStart = 0
        lineLayer.strokeEnd = 0
        glowLayer.strokeStart = 0
        glowLayer.strokeEnd = 0
        CATransaction.commit()

        for bubble in annotationBubbles {
            bubble.layer.removeAllAnimations()
            UIView.performWithoutAnimation {
                bubble.alpha = 0
                bubble.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                bubble.layoutIfNeeded()
            }
        }
    }

    func stopAnimations() {
        isStopped = true
        resetState()
    }
}
