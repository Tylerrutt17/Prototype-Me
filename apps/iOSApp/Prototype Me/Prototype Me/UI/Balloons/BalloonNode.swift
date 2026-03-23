import UIKit

/// A single balloon shape for the sky view — oval body, string, title, and timer.
final class BalloonNode: UIView {

    // MARK: - Callbacks

    var onTap: (() -> Void)?

    // MARK: - Layers

    private let balloonShapeLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let knotLayer = CAShapeLayer()
    private let stringLayer = CAShapeLayer()

    // MARK: - Subviews

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        lbl.textColor = DesignTokens.Colors.textPrimary
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.lineBreakMode = .byTruncatingTail
        return lbl
    }()

    private let timerLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        lbl.textColor = DesignTokens.Colors.textPrimary
        lbl.textAlignment = .center
        lbl.backgroundColor = DesignTokens.Colors.surfacePrimary.withAlphaComponent(0.8)
        lbl.layer.cornerRadius = 4
        lbl.clipsToBounds = true
        return lbl
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupNode()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNode()
    }

    // MARK: - Setup

    private func setupNode() {
        // String layer (behind balloon)
        stringLayer.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        stringLayer.fillColor = UIColor.clear.cgColor
        stringLayer.lineWidth = 1.5
        layer.addSublayer(stringLayer)

        // Balloon body
        balloonShapeLayer.strokeColor = nil
        layer.addSublayer(balloonShapeLayer)

        // Highlight
        highlightLayer.fillColor = UIColor.white.withAlphaComponent(0.15).cgColor
        highlightLayer.strokeColor = nil
        layer.addSublayer(highlightLayer)

        // Knot
        knotLayer.strokeColor = nil
        layer.addSublayer(knotLayer)

        // Timer badge
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timerLabel)

        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Tap to open directive detail
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width
        let bodyHeight = w * 1.1
        let bodyRect = CGRect(x: 0, y: 0, width: w, height: bodyHeight)

        // Balloon body (oval)
        balloonShapeLayer.path = UIBezierPath(ovalIn: bodyRect).cgPath

        // Highlight (glossy spot in upper-left)
        let hlRect = CGRect(
            x: bodyRect.minX + w * 0.2,
            y: bodyRect.minY + bodyHeight * 0.15,
            width: w * 0.25,
            height: bodyHeight * 0.2
        )
        highlightLayer.path = UIBezierPath(ovalIn: hlRect).cgPath

        // Knot (small triangle at bottom)
        let knotW: CGFloat = 8
        let knotH: CGFloat = 8
        let bottomCenter = CGPoint(x: bodyRect.midX, y: bodyRect.maxY)
        let knotPath = UIBezierPath()
        knotPath.move(to: CGPoint(x: bottomCenter.x - knotW / 2, y: bottomCenter.y - 2))
        knotPath.addLine(to: CGPoint(x: bottomCenter.x, y: bottomCenter.y + knotH))
        knotPath.addLine(to: CGPoint(x: bottomCenter.x + knotW / 2, y: bottomCenter.y - 2))
        knotPath.close()
        knotLayer.path = knotPath.cgPath

        // String (slight curve hanging down from knot)
        let stringTop = CGPoint(x: bottomCenter.x, y: bottomCenter.y + knotH)
        let stringBottom = CGPoint(x: bottomCenter.x + 3, y: bottomCenter.y + knotH + 20)
        let stringPath = UIBezierPath()
        stringPath.move(to: stringTop)
        stringPath.addQuadCurve(
            to: stringBottom,
            controlPoint: CGPoint(x: bottomCenter.x - 6, y: stringTop.y + 12)
        )
        stringLayer.path = stringPath.cgPath

        // Timer badge — centered on balloon body
        let timerSize = timerLabel.intrinsicContentSize
        let timerW = timerSize.width + 8
        let timerH = timerSize.height + 4
        timerLabel.frame = CGRect(
            x: (w - timerW) / 2,
            y: bodyRect.midY - timerH / 2,
            width: timerW,
            height: timerH
        )

        // Title label — below string
        let titleY = stringBottom.y + 4
        let titleH = titleLabel.sizeThatFits(CGSize(width: w + 20, height: .greatestFiniteMagnitude)).height
        titleLabel.frame = CGRect(
            x: -10,
            y: titleY,
            width: w + 20,
            height: titleH
        )
    }

    // MARK: - Configure

    private var currentDirective: Directive?
    private var displayLink: CADisplayLink?

    func configure(with data: DirectiveRowData) {
        titleLabel.text = data.directive.title
        currentDirective = data.directive
        updateTimerDisplay()

        let color = balloonColor(for: data.pressureLevel).withAlphaComponent(0.85)
        balloonShapeLayer.fillColor = color.cgColor
        knotLayer.fillColor = color.cgColor

        setNeedsLayout()
        startDisplayTimer()
    }

    private func startDisplayTimer() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tickTimer))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 1, preferred: 1)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopDisplayTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tickTimer() {
        updateTimerDisplay()
    }

    private func updateTimerDisplay() {
        guard let dir = currentDirective else { return }
        timerLabel.text = " \(formatTime(dir.liveRemainingSec)) "

        let color = balloonColor(for: dir.pressureLevel).withAlphaComponent(0.85)
        balloonShapeLayer.fillColor = color.cgColor
        knotLayer.fillColor = color.cgColor
    }

    // MARK: - Helpers

    private func balloonColor(for level: PressureLevel?) -> UIColor {
        guard let level else { return DesignTokens.Colors.accent }
        switch level {
        case .green:  return DesignTokens.Colors.success
        case .yellow: return DesignTokens.Colors.warning
        case .red:    return DesignTokens.Colors.destructive
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return "\(s)s"
    }

    // MARK: - Gestures

    @objc private func handleTap() {
        Haptics.light()
        onTap?()
    }

    deinit {
        stopDisplayTimer()
    }
}
