import UIKit

/// Full-screen sky canvas that positions BalloonNode views at heights based on remaining time.
final class BalloonSkyView: UIView {

    // MARK: - Callbacks

    var onBalloonTapped: ((UUID) -> Void)?

    // MARK: - Layout Constants

    private let topInset: CGFloat = 20
    private let bottomInset: CGFloat = 120
    private let balloonWidth: CGFloat = 80

    // MARK: - State

    private var nodes: [UUID: BalloonNode] = [:]
    private var currentItems: [DirectiveRowData] = []
    private var hasPerformedEntrance = false
    private var repositionTimer: Timer?

    // MARK: - Layers

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.locations = [0.0, 0.3, 0.65, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    private let celestialBody = CAShapeLayer()
    private let celestialGlow = CAGradientLayer()
    private let sunRaysLayer = CAShapeLayer()
    private let moonCrescentMask = CAShapeLayer()

    private let groundLine: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor(white: 0.25, alpha: 0.4).cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 1
        layer.lineDashPattern = [6, 4]
        return layer
    }()

    // Small decorative star dots
    private var starLayers: [CAShapeLayer] = []

    // Environment
    private let grassLayer = CAShapeLayer()
    private let grassHighlightLayer = CAShapeLayer()
    private var cloudLayers: [CAShapeLayer] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startRepositionTimer()
        } else {
            repositionTimer?.invalidate()
            repositionTimer = nil
        }
    }

    private func startRepositionTimer() {
        guard repositionTimer == nil else { return }
        repositionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self, !self.currentItems.isEmpty else { return }
            UIView.animate(withDuration: 1.0) {
                self.repositionNodes()
            }
        }
    }

    // MARK: - Setup

    private func setupView() {
        clipsToBounds = true
        layer.addSublayer(gradientLayer)

        // Celestial body (sun or moon)
        celestialGlow.type = .radial
        celestialGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        celestialGlow.endPoint = CGPoint(x: 1.0, y: 1.0)
        layer.addSublayer(celestialGlow)
        layer.addSublayer(sunRaysLayer)
        layer.addSublayer(celestialBody)

        // Add some subtle star dots in the upper portion
        for _ in 0..<15 {
            let star = CAShapeLayer()
            let size: CGFloat = CGFloat.random(in: 1...2.5)
            star.path = UIBezierPath(
                ovalIn: CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
            ).cgPath
            star.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.05...0.2)).cgColor
            starLayers.append(star)
            layer.addSublayer(star)
        }

        layer.addSublayer(groundLine)

        // Grass hills
        grassLayer.fillColor = UIColor(red: 0.08, green: 0.18, blue: 0.08, alpha: 1.0).cgColor
        layer.addSublayer(grassLayer)

        grassHighlightLayer.fillColor = UIColor(red: 0.10, green: 0.22, blue: 0.10, alpha: 0.6).cgColor
        layer.addSublayer(grassHighlightLayer)

        // Clouds
        for _ in 0..<4 {
            let cloud = CAShapeLayer()
            cloud.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.03...0.08)).cgColor
            cloudLayers.append(cloud)
            layer.insertSublayer(cloud, above: gradientLayer)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds

        // Update sky based on time of day
        updateSkyForTimeOfDay()

        // Position star dots randomly in the upper 40% of the view
        let starZoneHeight = bounds.height * 0.4
        for star in starLayers {
            star.position = CGPoint(
                x: CGFloat.random(in: 0...bounds.width),
                y: CGFloat.random(in: 0...starZoneHeight)
            )
        }

        // Ground line — at the bottom boundary where balloon text ends
        let groundY = bounds.height - bottomInset
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: DesignTokens.Spacing.lg, y: groundY))
        linePath.addLine(to: CGPoint(x: bounds.width - DesignTokens.Spacing.lg, y: groundY))
        groundLine.path = linePath.cgPath

        // Grass hills — rolling hills at the bottom
        let w = bounds.width
        let h = bounds.height
        let grassTop = h - bottomInset + 10

        let grassPath = UIBezierPath()
        grassPath.move(to: CGPoint(x: 0, y: h))
        grassPath.addLine(to: CGPoint(x: 0, y: grassTop + 15))
        grassPath.addCurve(to: CGPoint(x: w * 0.25, y: grassTop), controlPoint1: CGPoint(x: w * 0.08, y: grassTop + 5), controlPoint2: CGPoint(x: w * 0.18, y: grassTop - 8))
        grassPath.addCurve(to: CGPoint(x: w * 0.55, y: grassTop + 8), controlPoint1: CGPoint(x: w * 0.35, y: grassTop + 10), controlPoint2: CGPoint(x: w * 0.45, y: grassTop + 12))
        grassPath.addCurve(to: CGPoint(x: w * 0.8, y: grassTop - 5), controlPoint1: CGPoint(x: w * 0.65, y: grassTop + 2), controlPoint2: CGPoint(x: w * 0.72, y: grassTop - 10))
        grassPath.addCurve(to: CGPoint(x: w, y: grassTop + 10), controlPoint1: CGPoint(x: w * 0.9, y: grassTop + 2), controlPoint2: CGPoint(x: w * 0.95, y: grassTop + 8))
        grassPath.addLine(to: CGPoint(x: w, y: h))
        grassPath.close()
        grassLayer.path = grassPath.cgPath

        // Highlight hill (slightly offset for depth)
        let hlPath = UIBezierPath()
        hlPath.move(to: CGPoint(x: 0, y: h))
        hlPath.addLine(to: CGPoint(x: 0, y: grassTop + 25))
        hlPath.addCurve(to: CGPoint(x: w * 0.3, y: grassTop + 12), controlPoint1: CGPoint(x: w * 0.1, y: grassTop + 20), controlPoint2: CGPoint(x: w * 0.2, y: grassTop + 8))
        hlPath.addCurve(to: CGPoint(x: w * 0.6, y: grassTop + 20), controlPoint1: CGPoint(x: w * 0.4, y: grassTop + 18), controlPoint2: CGPoint(x: w * 0.5, y: grassTop + 22))
        hlPath.addCurve(to: CGPoint(x: w, y: grassTop + 15), controlPoint1: CGPoint(x: w * 0.8, y: grassTop + 16), controlPoint2: CGPoint(x: w * 0.9, y: grassTop + 18))
        hlPath.addLine(to: CGPoint(x: w, y: h))
        hlPath.close()
        grassHighlightLayer.path = hlPath.cgPath

        // Clouds — position and animate drift
        for (i, cloud) in cloudLayers.enumerated() {
            let cloudY = CGFloat(30 + i * 50) + CGFloat.random(in: -10...10)
            let cloudW = CGFloat.random(in: 80...140)
            let cloudH = CGFloat.random(in: 25...40)
            let cloudX = CGFloat(i) * (w / CGFloat(cloudLayers.count))

            let cloudPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: cloudW, height: cloudH), cornerRadius: cloudH / 2)
            cloud.path = cloudPath.cgPath
            cloud.position = CGPoint(x: cloudX, y: cloudY)

            // Drift animation
            if cloud.animation(forKey: "drift") == nil {
                let drift = CABasicAnimation(keyPath: "position.x")
                drift.fromValue = -cloudW
                drift.toValue = w + cloudW
                drift.duration = Double.random(in: 40...70)
                drift.repeatCount = .infinity
                drift.timeOffset = Double.random(in: 0...drift.duration)
                cloud.add(drift, forKey: "drift")
            }
        }

        CATransaction.commit()

        // Reposition balloons
        repositionNodes()
    }

    // MARK: - Public

    /// Resets the entrance state so next layout triggers the rise-from-ground animation.
    // MARK: - Time-of-Day Sky

    /// Set to override the hour (0-23) for debugging. nil = use real time.
    var debugHour: Int?

    private func updateSkyForTimeOfDay() {
        let hour = debugHour ?? Calendar.current.component(.hour, from: Date())

        let isNight = hour < 6 || hour >= 20
        let isDusk = hour >= 18 && hour < 20
        let isDawn = hour >= 6 && hour < 8
        let isDay = hour >= 8 && hour < 18

        // Sky gradient
        if isNight {
            gradientLayer.colors = [
                UIColor(red: 0.03, green: 0.05, blue: 0.15, alpha: 1.0).cgColor,
                UIColor(red: 0.06, green: 0.04, blue: 0.18, alpha: 1.0).cgColor,
                UIColor(red: 0.08, green: 0.06, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0).cgColor,
            ]
        } else if isDusk || isDawn {
            gradientLayer.colors = [
                UIColor(red: 0.12, green: 0.10, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.35, green: 0.15, blue: 0.25, alpha: 1.0).cgColor,
                UIColor(red: 0.45, green: 0.25, blue: 0.15, alpha: 1.0).cgColor,
                UIColor(red: 0.10, green: 0.08, blue: 0.10, alpha: 1.0).cgColor,
            ]
        } else {
            gradientLayer.colors = [
                UIColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1.0).cgColor,
                UIColor(red: 0.25, green: 0.50, blue: 0.75, alpha: 1.0).cgColor,
                UIColor(red: 0.40, green: 0.60, blue: 0.80, alpha: 1.0).cgColor,
                UIColor(red: 0.12, green: 0.15, blue: 0.18, alpha: 1.0).cgColor,
            ]
        }

        // Stars — visible at night and dusk/dawn, hidden during day
        let starAlpha: Float = isNight ? 1.0 : (isDusk || isDawn) ? 0.4 : 0.0
        for star in starLayers {
            star.opacity = starAlpha
        }

        // Grass color adjusts
        if isDay {
            grassLayer.fillColor = UIColor(red: 0.12, green: 0.28, blue: 0.10, alpha: 1.0).cgColor
            grassHighlightLayer.fillColor = UIColor(red: 0.15, green: 0.35, blue: 0.12, alpha: 0.6).cgColor
        } else if isDusk || isDawn {
            grassLayer.fillColor = UIColor(red: 0.10, green: 0.18, blue: 0.08, alpha: 1.0).cgColor
            grassHighlightLayer.fillColor = UIColor(red: 0.12, green: 0.22, blue: 0.10, alpha: 0.5).cgColor
        } else {
            grassLayer.fillColor = UIColor(red: 0.06, green: 0.12, blue: 0.06, alpha: 1.0).cgColor
            grassHighlightLayer.fillColor = UIColor(red: 0.08, green: 0.16, blue: 0.08, alpha: 0.5).cgColor
        }

        // Cloud opacity — more visible during day
        let cloudAlpha: CGFloat = isDay ? 0.12 : (isDusk || isDawn) ? 0.08 : 0.04
        for cloud in cloudLayers {
            cloud.fillColor = UIColor.white.withAlphaComponent(cloudAlpha).cgColor
        }

        // Celestial body — sun during day, moon at night
        let bodyRadius: CGFloat = 24
        let bodyX = bounds.width * 0.8
        let bodyY: CGFloat = 60
        let glowSize: CGFloat = bodyRadius * 5

        // Glow — radial gradient behind the body
        celestialGlow.frame = CGRect(x: bodyX - glowSize, y: bodyY - glowSize, width: glowSize * 2, height: glowSize * 2)
        celestialGlow.cornerRadius = glowSize

        // Body
        let bodyPath = UIBezierPath(arcCenter: .zero, radius: bodyRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        celestialBody.path = bodyPath.cgPath
        celestialBody.position = CGPoint(x: bodyX, y: bodyY)

        if isDay {
            // Sun — warm yellow with radial glow and rotating rays
            celestialBody.fillColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0).cgColor
            celestialBody.shadowColor = UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0).cgColor
            celestialBody.shadowRadius = 12
            celestialBody.shadowOpacity = 0.6
            celestialBody.shadowOffset = .zero
            celestialBody.mask = nil

            celestialGlow.colors = [
                UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.2).cgColor,
                UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 0.05).cgColor,
                UIColor.clear.cgColor,
            ]
            celestialGlow.isHidden = false

            // Sun rays
            sunRaysLayer.isHidden = false
            sunRaysLayer.position = CGPoint(x: bodyX, y: bodyY)
            let raysPath = UIBezierPath()
            let rayCount = 12
            for i in 0..<rayCount {
                let angle = (CGFloat(i) / CGFloat(rayCount)) * .pi * 2
                let inner = bodyRadius + 4
                let outer = bodyRadius + CGFloat(i % 2 == 0 ? 16 : 10)
                raysPath.move(to: CGPoint(x: cos(angle) * inner, y: sin(angle) * inner))
                raysPath.addLine(to: CGPoint(x: cos(angle) * outer, y: sin(angle) * outer))
            }
            sunRaysLayer.path = raysPath.cgPath
            sunRaysLayer.strokeColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.5).cgColor
            sunRaysLayer.lineWidth = 2
            sunRaysLayer.lineCap = .round
            sunRaysLayer.fillColor = nil

            // Slow rotation
            if sunRaysLayer.animation(forKey: "spin") == nil {
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = CGFloat.pi * 2
                spin.duration = 60
                spin.repeatCount = .infinity
                sunRaysLayer.add(spin, forKey: "spin")
            }

        } else if isDusk || isDawn {
            // Sunset/sunrise sun — larger, orange, no rays
            celestialBody.fillColor = UIColor(red: 1.0, green: 0.5, blue: 0.15, alpha: 0.95).cgColor
            celestialBody.shadowColor = UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1.0).cgColor
            celestialBody.shadowRadius = 20
            celestialBody.shadowOpacity = 0.5
            celestialBody.shadowOffset = .zero
            celestialBody.mask = nil

            celestialGlow.colors = [
                UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 0.15).cgColor,
                UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 0.03).cgColor,
                UIColor.clear.cgColor,
            ]
            celestialGlow.isHidden = false

            sunRaysLayer.isHidden = true
            sunRaysLayer.removeAnimation(forKey: "spin")

        } else {
            // Moon — crescent shape
            let moonColor = UIColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 1.0)
            celestialBody.fillColor = moonColor.cgColor
            celestialBody.shadowOpacity = 0  // No shadow — it bleeds past the mask

            // Crescent mask — a circle offset to carve out part of the moon
            let crescentPath = UIBezierPath(arcCenter: .zero, radius: bodyRadius + 1, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            let cutout = UIBezierPath(arcCenter: CGPoint(x: bodyRadius * 0.5, y: -bodyRadius * 0.3), radius: bodyRadius * 0.8, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            crescentPath.append(cutout.reversing())
            moonCrescentMask.path = crescentPath.cgPath
            moonCrescentMask.fillRule = .evenOdd
            moonCrescentMask.fillColor = UIColor.white.cgColor
            celestialBody.mask = moonCrescentMask

            celestialGlow.colors = [
                UIColor(red: 0.7, green: 0.75, blue: 0.95, alpha: 0.1).cgColor,
                UIColor(red: 0.6, green: 0.65, blue: 0.85, alpha: 0.02).cgColor,
                UIColor.clear.cgColor,
            ]
            celestialGlow.isHidden = false

            sunRaysLayer.isHidden = true
            sunRaysLayer.removeAnimation(forKey: "spin")
        }
    }

    func resetEntrance() {
        hasPerformedEntrance = false

        // Reset all animations so they restart fresh
        for cloud in cloudLayers {
            cloud.removeAllAnimations()
        }
        sunRaysLayer.removeAllAnimations()

        // Reset balloon node animations
        for (_, node) in nodes {
            node.layer.removeAllAnimations()
        }

        // Force re-layout which re-adds cloud drift animations and repositions everything
        setNeedsLayout()
    }

    func update(with items: [DirectiveRowData]) {
        currentItems = items

        let incomingIds = Set(items.map { $0.directive.id })
        let existingIds = Set(nodes.keys)

        // Remove stale nodes
        for id in existingIds.subtracting(incomingIds) {
            nodes[id]?.removeFromSuperview()
            nodes[id] = nil
        }

        // Add or update nodes
        for item in items {
            let id = item.directive.id

            if let existing = nodes[id] {
                existing.configure(with: item)
            } else {
                let node = BalloonNode()
                node.configure(with: item)
                node.onTap = { [weak self] in
                    self?.onBalloonTapped?(id)
                }
                addSubview(node)
                nodes[id] = node

                // Add floating animation
                addFloatingAnimation(to: node, seed: id.hashValue)
            }
        }

        repositionNodes()
    }

    // MARK: - Positioning

    private func repositionNodes() {
        guard bounds.height > 0 else { return }

        let nodeHeight = balloonWidth * 1.1 + 40 // body + string + title space
        let halfNode = nodeHeight / 2

        // Usable range for the node CENTER so edges stay within insets
        let minCenterY = topInset + halfNode
        let maxCenterY = bounds.height - bottomInset - halfNode
        let usableHeight = maxCenterY - minCenterY
        guard usableHeight > 0, !currentItems.isEmpty else { return }

        let count = currentItems.count
        let isEntrance = !hasPerformedEntrance

        // Sort by remaining time to determine relative positions
        let sortedTimes = currentItems.map(\.directive.liveRemainingSec).sorted()
        let minRemaining = sortedTimes.first ?? 0
        let maxRemaining = sortedTimes.last ?? 0
        let range = maxRemaining - minRemaining

        struct BalloonPosition {
            let id: UUID
            let x: CGFloat
            let y: CGFloat
        }

        // Step 1: Compute Y positions — hybrid of rank + time
        // 50% rank-based (even spacing) + 50% time-based (log scale)
        // This prevents outlier compression while keeping time relationships visible
        var yPositions: [(index: Int, y: CGFloat)] = []

        if count == 1 {
            yPositions.append((index: 0, y: minCenterY + usableHeight * 0.5))
        } else {
            let ranked = currentItems.enumerated()
                .sorted { $0.element.directive.liveRemainingSec < $1.element.directive.liveRemainingSec }

            // Log-scale the times to compress outliers
            let logTimes = ranked.map { log(max($0.element.directive.liveRemainingSec, 1) + 1) }
            let logMin = logTimes.first ?? 0
            let logMax = logTimes.last ?? 1
            let logRange = logMax - logMin

            for (rank, pair) in ranked.enumerated() {
                let rankRatio = CGFloat(rank) / CGFloat(count - 1)
                let timeRatio: CGFloat = logRange > 0
                    ? CGFloat((logTimes[rank] - logMin) / logRange)
                    : rankRatio

                // Blend: 40% rank (even) + 60% log-time (natural grouping)
                let ratio = rankRatio * 0.4 + timeRatio * 0.6
                let y = minCenterY + usableHeight * (1.0 - ratio)
                yPositions.append((index: pair.offset, y: y))
            }
        }

        // Step 2: Compute X positions — greedy placement that maximizes distance from existing balloons
        let halfBalloon = balloonWidth / 2
        let minX = halfBalloon + DesignTokens.Spacing.sm
        let maxX = bounds.width - halfBalloon - DesignTokens.Spacing.sm

        var placedPositions: [CGPoint] = []
        var finalPositions: [BalloonPosition] = Array(repeating: BalloonPosition(id: UUID(), x: 0, y: 0), count: count)

        // Sort items by Y position to place them from top to bottom — this gives
        // higher balloons first pick of X, and lower ones adapt around them
        let sortedByY = yPositions.sorted { $0.y < $1.y }

        for entry in sortedByY {
            let idx = entry.index
            let y = entry.y
            let id = currentItems[idx].directive.id

            let x: CGFloat
            if placedPositions.isEmpty {
                // First balloon: center it
                x = bounds.midX
            } else {
                // Try candidate X positions and pick the one farthest from all placed balloons
                let candidates = stride(from: minX, through: maxX, by: 12).map { $0 }
                x = candidates.max(by: { a, b in
                    minDistanceToPlaced(CGPoint(x: a, y: y), placed: placedPositions)
                    < minDistanceToPlaced(CGPoint(x: b, y: y), placed: placedPositions)
                }) ?? bounds.midX
            }

            // Apply small deterministic jitter so positions feel organic
            let jitterSeed = abs(id.hashValue % 10)
            let jitter = CGFloat(jitterSeed) - 5.0
            let finalX = min(max(x + jitter, minX), maxX)

            placedPositions.append(CGPoint(x: finalX, y: y))
            finalPositions[idx] = BalloonPosition(id: id, x: finalX, y: y)
        }

        // Step 3: Animate nodes to their positions
        if isEntrance {
            hasPerformedEntrance = true

            // Start all balloons at the ground, then animate up with staggered delays
            // Higher balloons rise faster; lower balloons drift up lazily
            let groundY = bounds.height - bottomInset + halfNode
            let maxTravel = Double(groundY - (topInset + halfNode)) // full height travel
            
            for (index, pos) in finalPositions.enumerated() {
                guard let node = nodes[pos.id] else { continue }
                let size = CGSize(width: balloonWidth, height: nodeHeight)

                // Set initial position at ground
                node.bounds = CGRect(origin: .zero, size: size)
                node.center = CGPoint(x: pos.x, y: groundY)
                node.alpha = 0.3

                // Scale duration by travel distance:
                // Higher balloons travel more → shorter duration (faster)
                // Lower balloons travel less → longer duration (slower)
                let travel = Double(groundY - pos.y)
                let travelRatio = maxTravel > 0 ? travel / maxTravel : 0.5
                // Range: 1.4s (highest) to 2.2s (lowest)
                let duration = 2.2 - (travelRatio * 0.8)

                let delay = 0.06 * Double(index)

                UIView.animate(
                    withDuration: duration,
                    delay: delay,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 0.15,
                    options: []
                ) {
                    node.center = CGPoint(x: pos.x, y: pos.y)
                    node.alpha = 1.0
                }
            }
        } else {
            // Normal repositioning — smooth spring
            for pos in finalPositions {
                guard let node = nodes[pos.id] else { continue }

                UIView.animate(
                    withDuration: 0.6,
                    delay: 0,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 0,
                    options: []
                ) {
                    node.bounds = CGRect(origin: .zero, size: CGSize(width: self.balloonWidth, height: nodeHeight))
                    node.center = CGPoint(x: pos.x, y: pos.y)
                }
            }
        }
    }

    /// Returns the minimum distance from `point` to any point in `placed`.
    private func minDistanceToPlaced(_ point: CGPoint, placed: [CGPoint]) -> CGFloat {
        placed.map { existing in
            hypot(point.x - existing.x, point.y - existing.y)
        }.min() ?? .greatestFiniteMagnitude
    }

    // MARK: - Animation

    private func addFloatingAnimation(to node: BalloonNode, seed: Int) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let anim = CABasicAnimation(keyPath: "transform.translation.y")
        anim.fromValue = -3.0
        anim.toValue = 3.0
        anim.duration = 2.0 + Double(abs(seed) % 10) * 0.15
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.layer.add(anim, forKey: "floating")
    }
}
