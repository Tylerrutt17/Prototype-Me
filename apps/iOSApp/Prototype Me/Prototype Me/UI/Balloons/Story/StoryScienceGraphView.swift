import UIKit

/// Science slides: animated graphs showing the forgetting curve and spaced repetition.
final class StoryScienceGraphView: UIView, StoryAnimatable {

    enum GraphType { case forgettingCurve, spacedRepetition }

    private let graphType: GraphType
    private let graphLayer = CAShapeLayer()
    private var boostLayers: [CAShapeLayer] = []
    private var axisLabels: [UILabel] = []
    private var hasBuilt = false

    // Graph area insets (left bigger for % labels)
    private let graphInset = UIEdgeInsets(top: 20, left: 52, bottom: 36, right: 20)

    init(graphType: GraphType) {
        self.graphType = graphType
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildGraph()
        }
    }

    private var graphRect: CGRect {
        CGRect(
            x: graphInset.left,
            y: graphInset.top,
            width: bounds.width - graphInset.left - graphInset.right,
            height: bounds.height - graphInset.top - graphInset.bottom
        )
    }

    /// Convert a 0–1 value to a Y coordinate (0 = bottom, 1 = top).
    private func yForValue(_ value: CGFloat, in rect: CGRect) -> CGFloat {
        rect.maxY - value * rect.height
    }

    // MARK: - Build

    private func buildGraph() {
        let rect = graphRect

        // Axes
        let axes = CAShapeLayer()
        let axisPath = UIBezierPath()
        axisPath.move(to: CGPoint(x: rect.minX, y: rect.minY))
        axisPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        axisPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        axes.path = axisPath.cgPath
        axes.strokeColor = DesignTokens.Colors.textTertiary.cgColor
        axes.fillColor = UIColor.clear.cgColor
        axes.lineWidth = 1
        layer.addSublayer(axes)

        // Percentage tick marks on Y axis
        let percentages: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
        let percentLabels = ["0%", "25%", "50%", "75%", "100%"]
        for (i, pct) in percentages.enumerated() {
            let y = yForValue(pct, in: rect)

            // Tick line
            let tick = CAShapeLayer()
            let tickPath = UIBezierPath()
            tickPath.move(to: CGPoint(x: rect.minX - 4, y: y))
            tickPath.addLine(to: CGPoint(x: rect.minX, y: y))
            tick.path = tickPath.cgPath
            tick.strokeColor = DesignTokens.Colors.textTertiary.cgColor
            tick.lineWidth = 1
            layer.addSublayer(tick)

            // Grid line (subtle)
            if pct > 0 && pct < 1 {
                let grid = CAShapeLayer()
                let gridPath = UIBezierPath()
                gridPath.move(to: CGPoint(x: rect.minX, y: y))
                gridPath.addLine(to: CGPoint(x: rect.maxX, y: y))
                grid.path = gridPath.cgPath
                grid.strokeColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.15).cgColor
                grid.lineWidth = 0.5
                layer.addSublayer(grid)
            }

            // Label
            let label = makeAxisLabel(percentLabels[i])
            label.textAlignment = .right
            label.frame = CGRect(x: 0, y: y - 7, width: rect.minX - 8, height: 14)
            addSubview(label)
        }

        // X axis label
        let xLabel = makeAxisLabel("Time")
        xLabel.frame = CGRect(x: rect.midX - 20, y: rect.maxY + 10, width: 60, height: 14)
        addSubview(xLabel)

        // Citation
        if graphType == .forgettingCurve {
            let citation = makeAxisLabel("Ebbinghaus, 1885")
            citation.frame = CGRect(x: rect.maxX - 120, y: rect.maxY + 10, width: 130, height: 14)
            citation.textAlignment = .right
            citation.font = DesignTokens.Typography.rounded(style: .caption2, weight: .regular)
            citation.textColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.5)
            addSubview(citation)
        }

        switch graphType {
        case .forgettingCurve:
            buildForgettingCurve(in: rect)
        case .spacedRepetition:
            buildSpacedRepetition(in: rect)
        }
    }

    // MARK: - Forgetting Curve

    private func buildForgettingCurve(in rect: CGRect) {
        let path = UIBezierPath()
        let steps = 80

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width
            // Steep exponential decay: 100% → near 0%
            let value = exp(-5.0 * t)
            let y = yForValue(value, in: rect)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        graphLayer.path = path.cgPath
        graphLayer.strokeColor = DesignTokens.Colors.destructive.withAlphaComponent(0.9).cgColor
        graphLayer.fillColor = UIColor.clear.cgColor
        graphLayer.lineWidth = 3
        graphLayer.lineCap = .round
        graphLayer.lineJoin = .round
        graphLayer.strokeEnd = 0
        layer.addSublayer(graphLayer)

        // Fill under curve
        let fillPath = UIBezierPath(cgPath: path.cgPath)
        fillPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        fillPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        fillPath.close()

        let fillLayer = CAShapeLayer()
        let gradient = CAGradientLayer()
        gradient.frame = rect
        gradient.colors = [
            DesignTokens.Colors.destructive.withAlphaComponent(0.15).cgColor,
            DesignTokens.Colors.destructive.withAlphaComponent(0.02).cgColor,
        ]
        fillLayer.frame = CGRect(origin: .zero, size: rect.size)
        let offsetTransform = CGAffineTransform(translationX: -rect.minX, y: -rect.minY)
        fillLayer.path = fillPath.cgPath.copy(using: [offsetTransform])
        gradient.mask = fillLayer
        gradient.opacity = 0
        layer.addSublayer(gradient)

        // "Without review" label
        let noReviewLabel = UILabel()
        noReviewLabel.text = "Without reminder"
        noReviewLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        noReviewLabel.textColor = DesignTokens.Colors.destructive.withAlphaComponent(0.8)
        noReviewLabel.sizeToFit()
        noReviewLabel.center = CGPoint(x: rect.midX + 30, y: yForValue(0.15, in: rect))
        noReviewLabel.alpha = 0
        addSubview(noReviewLabel)

        // "Discovered by" attribution tucked in the flat area of the curve
        let discoveredLabel = UILabel()
        discoveredLabel.text = "Discovered by Hermann Ebbinghaus, 1885"
        discoveredLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        discoveredLabel.textColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.7)
        discoveredLabel.sizeToFit()
        discoveredLabel.center = CGPoint(x: rect.midX + 20, y: rect.minY - 6)
        discoveredLabel.alpha = 0
        addSubview(discoveredLabel)

        axisLabels.append(contentsOf: [noReviewLabel, discoveredLabel])
        objc_setAssociatedObject(self, &AssociatedKeys.fillGradient, gradient, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Spaced Repetition

    private func buildSpacedRepetition(in rect: CGRect) {
        // Gentler curves matching the classic spaced repetition diagram:
        // Each pump resets near 100%, decay gets progressively slower
        let segments: [(startX: CGFloat, endX: CGFloat, decayRate: CGFloat)] = [
            (0.0,  0.20, 2.5),   // Initial — moderate decay
            (0.20, 0.45, 1.5),   // After 1st pump — slower
            (0.45, 0.72, 0.9),   // After 2nd pump — even slower
            (0.72, 1.0,  0.5),   // After 3rd pump — very gradual
        ]

        let path = UIBezierPath()
        let steps = 100

        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)

            // Find segment
            var seg = segments[0]
            for s in segments {
                if t >= s.startX { seg = s }
            }

            let localT = (t - seg.startX) / (seg.endX - seg.startX)
            // Each segment starts at ~100% and decays
            let value = exp(-seg.decayRate * localT)
            // Don't let it drop below ~20%
            let clampedValue = max(0.15, value)

            let x = rect.minX + t * rect.width
            let y = yForValue(clampedValue, in: rect)

            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }

        graphLayer.path = path.cgPath
        graphLayer.strokeColor = DesignTokens.Colors.success.withAlphaComponent(0.9).cgColor
        graphLayer.fillColor = UIColor.clear.cgColor
        graphLayer.lineWidth = 3
        graphLayer.lineCap = .round
        graphLayer.lineJoin = .round
        graphLayer.strokeEnd = 0
        layer.addSublayer(graphLayer)

        // Also draw the "without review" decay as a faint comparison line
        let compPath = UIBezierPath()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = rect.minX + t * rect.width
            let value = exp(-5.0 * t)
            let y = yForValue(value, in: rect)
            if i == 0 { compPath.move(to: CGPoint(x: x, y: y)) }
            else { compPath.addLine(to: CGPoint(x: x, y: y)) }
        }
        let compLayer = CAShapeLayer()
        compLayer.path = compPath.cgPath
        compLayer.strokeColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.3).cgColor
        compLayer.fillColor = UIColor.clear.cgColor
        compLayer.lineWidth = 1.5
        compLayer.lineDashPattern = [6, 4]
        compLayer.lineCap = .round
        layer.insertSublayer(compLayer, below: graphLayer)

        // Pump markers at each reset point
        for i in 1..<segments.count {
            let xFrac = segments[i].startX
            let x = rect.minX + xFrac * rect.width

            // Dashed vertical line
            let dash = CAShapeLayer()
            let dashPath = UIBezierPath()
            dashPath.move(to: CGPoint(x: x, y: rect.minY))
            dashPath.addLine(to: CGPoint(x: x, y: rect.maxY))
            dash.path = dashPath.cgPath
            dash.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor
            dash.fillColor = UIColor.clear.cgColor
            dash.lineWidth = 1
            dash.lineDashPattern = [4, 4]
            dash.opacity = 0
            layer.addSublayer(dash)
            boostLayers.append(dash)

            // "pump" label
            let pumpLabel = UILabel()
            pumpLabel.text = "↑ reminder"
            pumpLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            pumpLabel.textColor = DesignTokens.Colors.accent
            pumpLabel.sizeToFit()
            pumpLabel.center = CGPoint(x: x, y: rect.maxY - 16)
            pumpLabel.alpha = 0
            addSubview(pumpLabel)
            axisLabels.append(pumpLabel)
        }

        // Annotation
        let annotation = UILabel()
        annotation.text = "Each reminder → slower decay"
        annotation.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        annotation.textColor = DesignTokens.Colors.success.withAlphaComponent(0.8)
        annotation.sizeToFit()
        annotation.center = CGPoint(x: rect.midX + 20, y: rect.minY - 6)
        annotation.alpha = 0
        addSubview(annotation)
        axisLabels.append(annotation)
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            graphLayer.strokeEnd = 1
            for label in axisLabels { label.alpha = 1 }
            for boost in boostLayers { boost.opacity = 1 }
            if let gradient = objc_getAssociatedObject(self, &AssociatedKeys.fillGradient) as? CAGradientLayer {
                gradient.opacity = 1
            }
            return
        }

        // Draw the curve
        let drawAnim = CABasicAnimation(keyPath: "strokeEnd")
        drawAnim.fromValue = 0
        drawAnim.toValue = 1
        drawAnim.duration = 2.0
        drawAnim.beginTime = CACurrentMediaTime() + 0.3
        drawAnim.fillMode = .backwards
        drawAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        graphLayer.strokeEnd = 1
        graphLayer.add(drawAnim, forKey: "draw")

        // Fade in fill gradient (forgetting curve only)
        if let gradient = objc_getAssociatedObject(self, &AssociatedKeys.fillGradient) as? CAGradientLayer {
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0
            fadeIn.toValue = 1
            fadeIn.duration = 1.0
            fadeIn.beginTime = CACurrentMediaTime() + 1.5
            fadeIn.fillMode = .backwards
            gradient.opacity = 1
            gradient.add(fadeIn, forKey: "fadeIn")
        }

        // Staggered pump markers
        for (i, dash) in boostLayers.enumerated() {
            let delay = 0.5 + Double(i) * 0.5
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.3
            fade.beginTime = CACurrentMediaTime() + delay
            fade.fillMode = .backwards
            dash.opacity = 1
            dash.add(fade, forKey: "fadeIn")
        }

        // Labels fade in
        for (i, label) in axisLabels.enumerated() {
            let delay = 1.0 + Double(i) * 0.3
            UIView.animate(withDuration: 0.4, delay: delay, options: .curveEaseOut) {
                label.alpha = 1
            }
        }

    }

    func stopAnimations() {
        graphLayer.removeAllAnimations()
        for boost in boostLayers { boost.removeAllAnimations() }
    }

    // MARK: - Helpers

    private func makeAxisLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        label.textColor = DesignTokens.Colors.textTertiary
        label.textAlignment = .center
        label.sizeToFit()
        return label
    }

    private enum AssociatedKeys {
        nonisolated(unsafe) static var fillGradient: UInt8 = 0
    }
}
