import UIKit

/// Draws a faint grid pattern with colored electric pulse animations.
/// Pulses draw along grid lines like electricity traveling through a circuit.
final class GridBackgroundView: UIView {

    private let gridSpacing: CGFloat = 28
    private let baseAlpha: CGFloat = 0.04
    private let peakAlpha: CGFloat = 0.35
    private let lineWidth: CGFloat = 0.5
    private let litLineWidth: CGFloat = 1.2

    private var displayLink: CADisplayLink?
    private var pulseStartTime: CFTimeInterval = 0
    private let pulseDuration: CFTimeInterval = 1.6

    /// Each pulse: ordered list of (col, row) nodes it travels through
    private var pulsePaths: [[(Int, Int)]] = []
    private var pathColors: [UIColor] = []
    /// Per-node timing: when does the pulse HEAD arrive at this node (0..1)
    private var pathArrivalTimes: [[CGFloat]] = []
    /// How long the bright tail trails behind the head (fraction of duration)
    private let tailLength: CGFloat = 0.12

    private static let pulseColors: [UIColor] = [
        DesignTokens.Colors.accent,
        DesignTokens.Colors.accentSecondary,
        DesignTokens.Colors.accentTertiary,
        UIColor.systemPurple,
        UIColor.systemPink,
        UIColor.systemTeal,
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
    }

    deinit { displayLink?.invalidate() }

    func triggerWave() {
        let cols = Int(bounds.width / gridSpacing)
        let rows = Int(bounds.height / gridSpacing)
        guard cols > 2, rows > 2 else { return }

        let pathCount = Int.random(in: 4...6)
        pulsePaths = (0..<pathCount).map { _ in generatePath(cols: cols, rows: rows) }

        let shuffled = Self.pulseColors.shuffled()
        pathColors = (0..<pathCount).map { i in
            i < shuffled.count ? shuffled[i] : Self.pulseColors.randomElement()!
        }

        // Compute arrival times: evenly spaced so head reaches the top at t≈0.85
        pathArrivalTimes = pulsePaths.map { path in
            guard path.count > 1 else { return [CGFloat(0.4)] }
            return path.indices.map { i in
                CGFloat(i) / CGFloat(path.count - 1) * 0.85
            }
        }

        pulseStartTime = CACurrentMediaTime()
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    private func generatePath(cols: Int, rows: Int) -> [(Int, Int)] {
        var path: [(Int, Int)] = []
        var col = Int.random(in: 0..<cols)
        for row in stride(from: rows, to: 0, by: -1) {
            path.append((col, row))
            if Bool.random() {
                let dir = Bool.random() ? 1 : -1
                let steps = Int.random(in: 1...3)
                for s in 1...steps {
                    let nc = col + dir * s
                    if nc >= 0, nc < cols {
                        path.append((nc, row))
                        col = nc
                    }
                }
            }
        }
        return path
    }

    @objc private func tick(_ link: CADisplayLink) {
        let t = CGFloat((CACurrentMediaTime() - pulseStartTime) / pulseDuration)
        if t >= 1.2 {
            pulsePaths.removeAll()
            pathArrivalTimes.removeAll()
            pathColors.removeAll()
            displayLink?.invalidate()
            displayLink = nil
        }
        setNeedsDisplay()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let cols = Int(rect.width / gridSpacing) + 1
        let rows = Int(rect.height / gridSpacing) + 1
        let t = CGFloat((CACurrentMediaTime() - pulseStartTime) / pulseDuration)
        let isPulsing = !pulsePaths.isEmpty && t < 1.2

        // 1. Draw the full base grid in one pass
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(baseAlpha).cgColor)
        ctx.setLineWidth(lineWidth)
        for row in 0...rows {
            let y = CGFloat(row) * gridSpacing
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
        }
        for col in 0...cols {
            let x = CGFloat(col) * gridSpacing
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rect.height))
        }
        ctx.strokePath()

        // 2. Draw colored pulse trails on top
        guard isPulsing else { return }

        for (pathIdx, path) in pulsePaths.enumerated() {
            guard pathIdx < pathArrivalTimes.count, pathIdx < pathColors.count else { continue }
            let arrivals = pathArrivalTimes[pathIdx]
            let color = pathColors[pathIdx]

            for i in 0..<(path.count - 1) {
                let arriveA = arrivals[i]
                let arriveB = arrivals[i + 1]

                // The head arrives at node A at arriveA and at node B at arriveB.
                // The tail leaves node A at arriveA + tailLength.
                // We need to compute what fraction of this segment is lit.

                let headProgress = inverseLerp(t, from: arriveA, to: arriveB)
                let tailProgress = inverseLerp(t - tailLength, from: arriveA, to: arriveB)

                // headProgress: how far the bright head has drawn into this segment (0..1)
                // tailProgress: how far the tail has erased from the start (0..1)
                let drawFrom = clamp(tailProgress, 0, 1)
                let drawTo = clamp(headProgress, 0, 1)

                if drawTo <= drawFrom { continue }

                let (c1, r1) = path[i]
                let (c2, r2) = path[i + 1]
                let p1 = CGPoint(x: CGFloat(c1) * gridSpacing, y: CGFloat(r1) * gridSpacing)
                let p2 = CGPoint(x: CGFloat(c2) * gridSpacing, y: CGFloat(r2) * gridSpacing)

                // Interpolate the visible portion of the segment
                let startPt = CGPoint(
                    x: p1.x + (p2.x - p1.x) * drawFrom,
                    y: p1.y + (p2.y - p1.y) * drawFrom
                )
                let endPt = CGPoint(
                    x: p1.x + (p2.x - p1.x) * drawTo,
                    y: p1.y + (p2.y - p1.y) * drawTo
                )

                // Brightness: brightest at the head, fading toward the tail
                let brightness = clamp(headProgress, 0, 1)
                let alpha = peakAlpha * brightness

                ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
                ctx.setLineWidth(litLineWidth)
                ctx.setLineCap(.round)
                ctx.move(to: startPt)
                ctx.addLine(to: endPt)
                ctx.strokePath()
            }
        }
        ctx.setLineCap(.butt)
    }

    // MARK: - Helpers

    private func segmentKey(_ a: (Int, Int), _ b: (Int, Int)) -> String {
        let (a, b) = a < b ? (a, b) : (b, a)
        return "\(a.0),\(a.1)-\(b.0),\(b.1)"
    }

    /// Where does `value` fall between `from` and `to`? Returns <0 if before, >1 if after.
    private func inverseLerp(_ value: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        guard to != from else { return value >= from ? 1 : 0 }
        return (value - from) / (to - from)
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }
}

private func < (lhs: (Int, Int), rhs: (Int, Int)) -> Bool {
    lhs.0 != rhs.0 ? lhs.0 < rhs.0 : lhs.1 < rhs.1
}
