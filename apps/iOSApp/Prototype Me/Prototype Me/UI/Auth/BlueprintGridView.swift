import UIKit

/// Animated blueprint grid background — faint grid lines with measurement marks
/// that slowly drift, like you're building something.
final class BlueprintGridView: UIView {

    private let gridLayer = CAShapeLayer()
    private let accentLayer = CAShapeLayer()
    private let markingsLayer = CAShapeLayer()
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    private let gridSpacing: CGFloat = 32
    private let majorEvery = 4  // every 4th line is a major line

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true

        layer.addSublayer(gridLayer)
        layer.addSublayer(accentLayer)
        layer.addSublayer(markingsLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        displayLink?.invalidate()
    }

    func startAnimating() {
        stopAnimating()
        guard !UIAccessibility.isReduceMotionEnabled else {
            drawGrid(offsetX: 0, offsetY: 0)
            return
        }
        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 12)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let t = CACurrentMediaTime() - startTime

        // Slow diagonal drift
        let speed: CGFloat = 6
        let ox = CGFloat(t) * speed
        let oy = CGFloat(t) * speed * 0.6
        drawGrid(offsetX: ox.truncatingRemainder(dividingBy: gridSpacing * CGFloat(majorEvery)),
                 offsetY: oy.truncatingRemainder(dividingBy: gridSpacing * CGFloat(majorEvery)))
    }

    private func drawGrid(offsetX: CGFloat, offsetY: CGFloat) {
        let w = bounds.width
        let h = bounds.height
        guard w > 0 else { return }

        let minor = UIBezierPath()
        let major = UIBezierPath()
        let marks = UIBezierPath()

        let sp = gridSpacing
        let pad: CGFloat = sp * CGFloat(majorEvery)  // extra padding for seamless scroll

        // Vertical lines
        var col = 0
        var x = -pad + offsetX.truncatingRemainder(dividingBy: sp)
        while x <= w + pad {
            let path = (col % majorEvery == 0) ? major : minor
            path.move(to: CGPoint(x: x, y: -pad))
            path.addLine(to: CGPoint(x: x, y: h + pad))

            // Small tick marks on major lines
            if col % majorEvery == 0 {
                for tickY in stride(from: -pad, through: h + pad, by: sp) {
                    marks.move(to: CGPoint(x: x - 3, y: tickY + offsetY.truncatingRemainder(dividingBy: sp)))
                    marks.addLine(to: CGPoint(x: x + 3, y: tickY + offsetY.truncatingRemainder(dividingBy: sp)))
                }
            }

            x += sp
            col += 1
        }

        // Horizontal lines
        var row = 0
        var y = -pad + offsetY.truncatingRemainder(dividingBy: sp)
        while y <= h + pad {
            let path = (row % majorEvery == 0) ? major : minor
            path.move(to: CGPoint(x: -pad, y: y))
            path.addLine(to: CGPoint(x: w + pad, y: y))

            if row % majorEvery == 0 {
                for tickX in stride(from: -pad, through: w + pad, by: sp) {
                    marks.move(to: CGPoint(x: tickX + offsetX.truncatingRemainder(dividingBy: sp), y: y - 3))
                    marks.addLine(to: CGPoint(x: tickX + offsetX.truncatingRemainder(dividingBy: sp), y: y + 3))
                }
            }

            y += sp
            row += 1
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        gridLayer.path = minor.cgPath
        gridLayer.strokeColor = UIColor.white.withAlphaComponent(0.03).cgColor
        gridLayer.fillColor = nil
        gridLayer.lineWidth = 0.5

        accentLayer.path = major.cgPath
        accentLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.06).cgColor
        accentLayer.fillColor = nil
        accentLayer.lineWidth = 0.8

        markingsLayer.path = marks.cgPath
        markingsLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.10).cgColor
        markingsLayer.fillColor = nil
        markingsLayer.lineWidth = 0.8

        CATransaction.commit()
    }
}
