import UIKit

/// Slide visual: top-down brain with 6 dots (3 per hemisphere) at fixed positions.
/// Labels flash, "Life happens." pops in with a pill bg, moves up, interruptions
/// push dots to the sides (green → orange → red), balloons bring them back.
final class StoryBrainRAMView: UIView, StoryAnimatable {

    private var hasBuilt = false
    private var animationGeneration: Int = 0

    var locksNavigation: Bool { true }
    var onAnimationComplete: (() -> Void)?

    // Intro
    private var introLabel: UILabel!

    // Brain
    private let brainLayer = CAShapeLayer()
    private let fissureLayer = CAShapeLayer()
    private let foldLayers: [CAShapeLayer] = [CAShapeLayer(), CAShapeLayer(), CAShapeLayer()]
    private var brainPath: UIBezierPath!
    private var brainRect: CGRect = .zero

    // Dots + glow rings
    private var dots: [(dot: UIView, glow: UIView, home: CGPoint, side: Side)] = []

    private enum Side { case left, right }

    // "Life happens" with pill background
    private var lifeHappensPill: UIView!
    private var lifeHappensLabel: UILabel!
    private var interruptionLabel: UILabel!

    // Mini balloon card
    private var miniCard: UIView!
    private var miniCardTitle: UILabel!
    private var miniCardTimer: UILabel!
    private var miniCardFill: CAGradientLayer!
    private var miniCardDot: UIView!
    private var miniCardPumpButton: UIButton!

    // Notification
    private var notificationBadge: UIView?
    private var notifLabel: UILabel!

    // Big push notification banner (slides from top)
    private var pushBanner: UIView!

    // Tap hand cursor for pump simulation
    private var tapHand: UIImageView!

    // Replay button
    private var replayButton: UIButton!
    private let connectorLine = CAShapeLayer()
    private var displayLink: CADisplayLink?
    private var trackingDotIndex: Int = 0
    private var badgeCenterPoint: CGPoint = .zero

    // Timer countdown display link
    private var timerLink: CADisplayLink?
    private var timerStartTime: CFTimeInterval = 0
    private var timerTotalSeconds: Double = 86400 // 24h in seconds
    private var timerDrainDuration: Double = 4.0

    private let intentions = [
        "Drink more water",
        "Exercise",
        "Think positively",
        "Be present",
        "Eat healthier",
        "Read more",
    ]

    private let interruptions = [
        "Work meeting",
        "Scrolling socials",
        "Errands",
        "Texts & emails",
        "Cooking dinner",
        "Helping a friend",
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    // MARK: - Brain Path

    private func makeTopDownBrain(in rect: CGRect) -> (outline: UIBezierPath, fissure: UIBezierPath, folds: [UIBezierPath]) {
        let w = rect.width, h = rect.height, ox = rect.origin.x, oy = rect.origin.y
        let midX = ox + w * 0.5

        let outline = UIBezierPath()
        outline.move(to: CGPoint(x: midX, y: oy))
        outline.addCurve(to: CGPoint(x: ox + w * 0.95, y: oy + h * 0.4),
            controlPoint1: CGPoint(x: ox + w * 0.72, y: oy),
            controlPoint2: CGPoint(x: ox + w * 0.95, y: oy + h * 0.18))
        outline.addCurve(to: CGPoint(x: ox + w * 0.88, y: oy + h * 0.75),
            controlPoint1: CGPoint(x: ox + w * 0.97, y: oy + h * 0.55),
            controlPoint2: CGPoint(x: ox + w * 0.95, y: oy + h * 0.68))
        outline.addCurve(to: CGPoint(x: midX, y: oy + h),
            controlPoint1: CGPoint(x: ox + w * 0.78, y: oy + h * 0.90),
            controlPoint2: CGPoint(x: ox + w * 0.65, y: oy + h))
        outline.addCurve(to: CGPoint(x: ox + w * 0.12, y: oy + h * 0.75),
            controlPoint1: CGPoint(x: ox + w * 0.35, y: oy + h),
            controlPoint2: CGPoint(x: ox + w * 0.22, y: oy + h * 0.90))
        outline.addCurve(to: CGPoint(x: ox + w * 0.05, y: oy + h * 0.4),
            controlPoint1: CGPoint(x: ox + w * 0.05, y: oy + h * 0.68),
            controlPoint2: CGPoint(x: ox + w * 0.03, y: oy + h * 0.55))
        outline.addCurve(to: CGPoint(x: midX, y: oy),
            controlPoint1: CGPoint(x: ox + w * 0.05, y: oy + h * 0.18),
            controlPoint2: CGPoint(x: ox + w * 0.28, y: oy))
        outline.close()

        let fissure = UIBezierPath()
        fissure.move(to: CGPoint(x: midX, y: oy + h * 0.02))
        fissure.addCurve(to: CGPoint(x: midX, y: oy + h * 0.98),
            controlPoint1: CGPoint(x: midX - 3, y: oy + h * 0.35),
            controlPoint2: CGPoint(x: midX + 3, y: oy + h * 0.65))

        var folds: [UIBezierPath] = []
        let lf = UIBezierPath()
        lf.move(to: CGPoint(x: ox + w * 0.12, y: oy + h * 0.35))
        lf.addCurve(to: CGPoint(x: ox + w * 0.42, y: oy + h * 0.40),
            controlPoint1: CGPoint(x: ox + w * 0.22, y: oy + h * 0.30),
            controlPoint2: CGPoint(x: ox + w * 0.35, y: oy + h * 0.45))
        folds.append(lf)

        let rf = UIBezierPath()
        rf.move(to: CGPoint(x: ox + w * 0.58, y: oy + h * 0.38))
        rf.addCurve(to: CGPoint(x: ox + w * 0.88, y: oy + h * 0.33),
            controlPoint1: CGPoint(x: ox + w * 0.65, y: oy + h * 0.44),
            controlPoint2: CGPoint(x: ox + w * 0.78, y: oy + h * 0.28))
        folds.append(rf)

        let bf = UIBezierPath()
        bf.move(to: CGPoint(x: ox + w * 0.15, y: oy + h * 0.62))
        bf.addCurve(to: CGPoint(x: ox + w * 0.42, y: oy + h * 0.58),
            controlPoint1: CGPoint(x: ox + w * 0.25, y: oy + h * 0.68),
            controlPoint2: CGPoint(x: ox + w * 0.35, y: oy + h * 0.55))
        bf.move(to: CGPoint(x: ox + w * 0.58, y: oy + h * 0.60))
        bf.addCurve(to: CGPoint(x: ox + w * 0.85, y: oy + h * 0.64),
            controlPoint1: CGPoint(x: ox + w * 0.65, y: oy + h * 0.56),
            controlPoint2: CGPoint(x: ox + w * 0.78, y: oy + h * 0.70))
        folds.append(bf)

        return (outline, fissure, folds)
    }

    // MARK: - Build

    private func buildVisual() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY - 10)
        let brainW: CGFloat = 180, brainH: CGFloat = 200
        brainRect = CGRect(x: center.x - brainW / 2, y: center.y - brainH / 2, width: brainW, height: brainH)

        let (outline, fissurePath, foldPaths) = makeTopDownBrain(in: brainRect)
        brainPath = outline

        brainLayer.path = outline.cgPath
        brainLayer.fillColor = UIColor.clear.cgColor
        brainLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor
        brainLayer.lineWidth = 2
        brainLayer.opacity = 0
        layer.addSublayer(brainLayer)

        fissureLayer.path = fissurePath.cgPath
        fissureLayer.fillColor = nil
        fissureLayer.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.25).cgColor
        fissureLayer.lineWidth = 2
        fissureLayer.lineCap = .round
        fissureLayer.opacity = 0
        layer.addSublayer(fissureLayer)

        for (i, fold) in foldPaths.enumerated() {
            let fl = foldLayers[i]
            fl.path = fold.cgPath
            fl.fillColor = nil
            fl.strokeColor = DesignTokens.Colors.accent.withAlphaComponent(0.15).cgColor
            fl.lineWidth = 1.5
            fl.lineCap = .round
            fl.opacity = 0
            layer.addSublayer(fl)
        }

        // Intro label (reused: "Your brain" → "Things you're trying to remember")
        introLabel = UILabel()
        introLabel.text = "Your brain"
        introLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        introLabel.textColor = DesignTokens.Colors.warning
        introLabel.textAlignment = .center
        introLabel.frame = CGRect(x: 0, y: brainRect.maxY + 14, width: bounds.width, height: 34)
        introLabel.alpha = 0
        addSubview(introLabel)

        // Fixed dot positions: 3 left hemisphere, 3 right hemisphere
        let dotSize: CGFloat = 10
        let glowSize: CGFloat = 30
        let leftPositions: [(CGFloat, CGFloat, Side)] = [
            (0.25, 0.28, .left),   // upper-left
            (0.22, 0.50, .left),   // mid-left
            (0.30, 0.72, .left),   // lower-left
        ]
        let rightPositions: [(CGFloat, CGFloat, Side)] = [
            (0.75, 0.28, .right),  // upper-right
            (0.78, 0.50, .right),  // mid-right
            (0.70, 0.72, .right),  // lower-right
        ]

        for (px, py, side) in leftPositions + rightPositions {
            let pos = CGPoint(x: brainRect.origin.x + brainRect.width * px,
                              y: brainRect.origin.y + brainRect.height * py)

            let glow = UIView(frame: CGRect(x: 0, y: 0, width: glowSize, height: glowSize))
            glow.center = pos
            glow.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.2)
            glow.layer.cornerRadius = glowSize / 2
            glow.alpha = 0
            addSubview(glow)

            let dot = UIView(frame: CGRect(x: 0, y: 0, width: dotSize, height: dotSize))
            dot.center = pos
            dot.backgroundColor = DesignTokens.Colors.success
            dot.layer.cornerRadius = dotSize / 2
            dot.alpha = 0
            dot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            addSubview(dot)

            dots.append((dot: dot, glow: glow, home: pos, side: side))
        }

        // "Life happens." pill — starts centered over brain
        lifeHappensPill = UIView()
        lifeHappensPill.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.9)
        lifeHappensPill.layer.cornerRadius = 20
        lifeHappensPill.alpha = 0
        addSubview(lifeHappensPill)

        lifeHappensLabel = UILabel()
        lifeHappensLabel.text = "Life happens."
        lifeHappensLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        lifeHappensLabel.textColor = DesignTokens.Colors.textPrimary
        lifeHappensLabel.textAlignment = .center
        lifeHappensLabel.numberOfLines = 0
        lifeHappensLabel.alpha = 0
        // Full width so text is never clipped
        lifeHappensLabel.frame = CGRect(x: 0, y: brainRect.midY - 20, width: bounds.width, height: 40)
        addSubview(lifeHappensLabel)

        // Pill sized to fit the text, centered over brain
        let pillPadH: CGFloat = 24, pillPadV: CGFloat = 12
        let textSize = lifeHappensLabel.intrinsicContentSize
        let pillW = textSize.width + pillPadH * 2
        let pillH = textSize.height + pillPadV * 2
        lifeHappensPill.frame = CGRect(x: bounds.midX - pillW / 2, y: brainRect.midY - pillH / 2, width: pillW, height: pillH)

        // Interruption sub-label (will be positioned when pill moves up)
        interruptionLabel = UILabel()
        interruptionLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .medium)
        interruptionLabel.textColor = DesignTokens.Colors.textSecondary
        interruptionLabel.textAlignment = .center
        interruptionLabel.alpha = 0
        interruptionLabel.frame = CGRect(x: 0, y: brainRect.minY - 24, width: bounds.width, height: 24)
        addSubview(interruptionLabel)

        // Notification badge
        let badge = buildNotificationBadge()
        badge.alpha = 0
        badge.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.9, y: 0.9)
        addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: centerXAnchor),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: brainRect.maxY + DesignTokens.Spacing.lg),
        ])
        notificationBadge = badge

        // Connector line (disabled for now)
        connectorLine.opacity = 0
        layer.addSublayer(connectorLine)

        // Mini balloon card (reused for first 2 return animations)
        let cardW: CGFloat = 200
        let cardH: CGFloat = 130
        miniCard = UIView(frame: CGRect(x: bounds.midX - cardW / 2, y: brainRect.midY - cardH / 2, width: cardW, height: cardH))
        miniCard.backgroundColor = DesignTokens.Colors.surfaceSecondary
        miniCard.layer.cornerRadius = DesignTokens.Radii.lg
        miniCard.clipsToBounds = true
        miniCard.alpha = 0
        DesignTokens.Shadows.apply(to: miniCard.layer, elevation: .medium)

        // Fill gauge
        miniCardFill = CAGradientLayer()
        miniCardFill.colors = [UIColor.clear.cgColor, DesignTokens.Colors.success.withAlphaComponent(0.15).cgColor]
        miniCardFill.locations = [0.0, 1.0]
        miniCardFill.startPoint = CGPoint(x: 0.5, y: 0.0)
        miniCardFill.endPoint = CGPoint(x: 0.5, y: 1.0)
        miniCardFill.frame = CGRect(x: 0, y: 0, width: cardW, height: cardH)
        miniCard.layer.insertSublayer(miniCardFill, at: 0)

        // Pressure dot
        miniCardDot = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
        miniCardDot.backgroundColor = DesignTokens.Colors.success
        miniCardDot.layer.cornerRadius = 6

        // Title
        miniCardTitle = UILabel()
        miniCardTitle.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        miniCardTitle.textColor = DesignTokens.Colors.textPrimary

        let topRow = UIStackView(arrangedSubviews: [miniCardDot, miniCardTitle])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.sm
        topRow.alignment = .center

        // Timer
        miniCardTimer = UILabel()
        miniCardTimer.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        miniCardTimer.textColor = DesignTokens.Colors.success
        miniCardTimer.textAlignment = .center
        miniCardTimer.text = "24h 00m"

        // Pump button
        miniCardPumpButton = UIButton(type: .system)
        var pumpConfig = UIButton.Configuration.filled()
        pumpConfig.title = "Pump"
        pumpConfig.image = UIImage(systemName: "arrow.clockwise")
        pumpConfig.imagePadding = 4
        pumpConfig.cornerStyle = .capsule
        pumpConfig.baseBackgroundColor = DesignTokens.Colors.accent
        pumpConfig.baseForegroundColor = DesignTokens.Colors.textPrimary
        pumpConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        miniCardPumpButton.configuration = pumpConfig
        miniCardPumpButton.isUserInteractionEnabled = false
        miniCardPumpButton.alpha = 0.5

        let stack = UIStackView(arrangedSubviews: [topRow, miniCardTimer, miniCardPumpButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        miniCard.addSubview(stack)

        NSLayoutConstraint.activate([
            miniCardDot.widthAnchor.constraint(equalToConstant: 12),
            miniCardDot.heightAnchor.constraint(equalToConstant: 12),
            stack.centerYAnchor.constraint(equalTo: miniCard.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: miniCard.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: miniCard.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        addSubview(miniCard)

        // Big push notification banner (iOS-style, slides from top)
        let bannerH: CGFloat = 70
        pushBanner = UIView(frame: CGRect(x: 16, y: -bannerH - 10, width: bounds.width - 32, height: bannerH))
        pushBanner.backgroundColor = DesignTokens.Colors.surfaceSecondary
        pushBanner.layer.cornerRadius = 16
        DesignTokens.Shadows.apply(to: pushBanner.layer, elevation: .high)

        let appIcon = UIView(frame: CGRect(x: 14, y: 14, width: 28, height: 28))
        appIcon.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
        appIcon.layer.cornerRadius = 7
        let balloonIcon = UIImageView(image: UIImage(systemName: "balloon.fill"))
        balloonIcon.tintColor = DesignTokens.Colors.success
        balloonIcon.contentMode = .scaleAspectFit
        balloonIcon.frame = CGRect(x: 4, y: 4, width: 20, height: 20)
        appIcon.addSubview(balloonIcon)
        pushBanner.addSubview(appIcon)

        let bannerAppLabel = UILabel()
        bannerAppLabel.text = "PROTOTYPE ME"
        bannerAppLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        bannerAppLabel.textColor = DesignTokens.Colors.textTertiary
        bannerAppLabel.frame = CGRect(x: 50, y: 12, width: 200, height: 14)
        pushBanner.addSubview(bannerAppLabel)

        let bannerTitle = UILabel()
        bannerTitle.text = "Balloon Expired"
        bannerTitle.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .bold)
        bannerTitle.textColor = DesignTokens.Colors.textPrimary
        bannerTitle.frame = CGRect(x: 50, y: 28, width: 250, height: 18)
        pushBanner.addSubview(bannerTitle)

        let bannerBody = UILabel()
        bannerBody.text = "\"Drink more water\" needs a pump!"
        bannerBody.font = DesignTokens.Typography.rounded(style: .caption1, weight: .regular)
        bannerBody.textColor = DesignTokens.Colors.textSecondary
        bannerBody.frame = CGRect(x: 50, y: 47, width: 250, height: 16)
        pushBanner.addSubview(bannerBody)

        pushBanner.alpha = 0
        addSubview(pushBanner)

        // Tap hand cursor
        let handConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        tapHand = UIImageView(image: UIImage(systemName: "hand.tap.fill", withConfiguration: handConfig))
        tapHand.tintColor = DesignTokens.Colors.textPrimary
        tapHand.alpha = 0
        tapHand.sizeToFit()
        addSubview(tapHand)

        // Replay button (shown after animation completes)
        replayButton = UIButton(type: .system)
        var replayConfig = UIButton.Configuration.plain()
        replayConfig.title = "Replay"
        replayConfig.image = UIImage(systemName: "arrow.counterclockwise")
        replayConfig.imagePadding = 6
        replayConfig.baseForegroundColor = DesignTokens.Colors.textSecondary
        replayButton.configuration = replayConfig
        replayButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        replayButton.alpha = 0
        replayButton.addTarget(self, action: #selector(replayTapped), for: .touchUpInside)
        replayButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(replayButton)
        NSLayoutConstraint.activate([
            replayButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            replayButton.topAnchor.constraint(equalTo: topAnchor, constant: brainRect.maxY + 20),
        ])
    }

    @objc private func replayTapped() {
        UIView.animate(withDuration: 0.2) {
            self.replayButton.alpha = 0
        } completion: { _ in
            self.stopAnimations()
            self.playEntrance()
        }
    }

    private func buildNotificationBadge() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let bg = UIView()
        bg.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.9)
        bg.layer.cornerRadius = 14
        bg.layer.borderWidth = 1
        bg.layer.borderColor = DesignTokens.Colors.separator.cgColor
        bg.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bg)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let bellIcon = UIImageView(image: UIImage(systemName: "bell.fill", withConfiguration: iconConfig))
        bellIcon.tintColor = DesignTokens.Colors.success
        bellIcon.translatesAutoresizingMaskIntoConstraints = false

        notifLabel = UILabel()
        notifLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        notifLabel.textColor = DesignTokens.Colors.textPrimary

        let stack = UIStackView(arrangedSubviews: [bellIcon, notifLabel])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(stack)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: container.topAnchor),
            bg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bg.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),
            bellIcon.widthAnchor.constraint(equalToConstant: 14),
            bellIcon.heightAnchor.constraint(equalToConstant: 14),
        ])
        return container
    }

    // MARK: - StoryAnimatable

    /// Schedule a delayed block that auto-cancels if the animation generation changes.
    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let gen = animationGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.animationGeneration == gen else { return }
            block()
        }
    }

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            brainLayer.opacity = 1
            fissureLayer.opacity = 1
            for fl in foldLayers { fl.opacity = 1 }
            for d in dots { d.dot.alpha = 1; d.dot.transform = .identity }
            return
        }

        animationGeneration += 1

        // ── Phase 1: Brain draws in ──
        brainLayer.strokeEnd = 0
        brainLayer.opacity = 1

        let drawOutline = CABasicAnimation(keyPath: "strokeEnd")
        drawOutline.fromValue = 0; drawOutline.toValue = 1
        drawOutline.duration = 1.0
        drawOutline.timingFunction = CAMediaTimingFunction(name: .easeOut)
        drawOutline.fillMode = .forwards; drawOutline.isRemovedOnCompletion = false
        brainLayer.add(drawOutline, forKey: "drawOutline")

        let fillFade = CABasicAnimation(keyPath: "fillColor")
        fillFade.fromValue = UIColor.clear.cgColor
        fillFade.toValue = DesignTokens.Colors.accent.withAlphaComponent(0.08).cgColor
        fillFade.duration = 0.5; fillFade.beginTime = CACurrentMediaTime() + 0.6
        fillFade.fillMode = .forwards; fillFade.isRemovedOnCompletion = false
        brainLayer.add(fillFade, forKey: "fillFade")

        for (i, fl) in ([fissureLayer] + foldLayers).enumerated() {
            fl.opacity = 1
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.4
            fade.beginTime = CACurrentMediaTime() + 0.8 + Double(i) * 0.1
            fade.fillMode = .backwards
            fl.add(fade, forKey: "fade")
        }

        // ── Phase 1.5: "Your brain" → swap to "Things you're trying to remember" ──
        UIView.animate(withDuration: 0.5, delay: 0.9, options: .curveEaseOut) {
            self.introLabel.alpha = 1
        }
        // Fade out "Your brain", swap to "Things you're trying to remember", dots pop in, then fade label
        schedule(after: 2.4) {
            UIView.animate(withDuration: 0.25) {
                self.introLabel.alpha = 0
            } completion: { _ in
                self.introLabel.text = "Things you're trying to remember"
                self.introLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
                self.introLabel.textColor = DesignTokens.Colors.success
                UIView.animate(withDuration: 0.4) {
                    self.introLabel.alpha = 1
                }
            }
        }

        // ── Phase 2: Dots pop in (1.5s after "remember" label appears) ──
        let dotsStart = 4.5
        for (i, entry) in dots.enumerated() {
            UIView.animate(
                withDuration: 0.3,
                delay: dotsStart + Double(i) * 0.1,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.5
            ) {
                entry.dot.alpha = 1
                entry.dot.transform = .identity
            }
        }

        // Fade "remember" label out once all dots are in
        let allDotsIn = dotsStart + Double(dots.count) * 0.1 + 0.3
        UIView.animate(withDuration: 0.3, delay: allDotsIn) {
            self.introLabel.alpha = 0
        }

        // ── Phase 3: Flash labels with glow highlight (first ones slower) ──
        let labelStart = allDotsIn + 1.5
        // First = 1.6s, second = 1.2s, rest = 0.85s
        let labelDurations: [Double] = intentions.indices.map { i in
            switch i {
            case 0: return 1.6
            case 1: return 1.2
            default: return 0.85
            }
        }

        var cumulativeDelay = labelStart
        for (i, intention) in intentions.enumerated() {
            let showDelay = cumulativeDelay
            let duration = labelDurations[i]
            cumulativeDelay += duration

            self.schedule(after: showDelay) { [self] in
                guard i < self.dots.count else { return }
                let entry = self.dots[i]

                entry.glow.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                    entry.glow.alpha = 1
                    entry.glow.transform = .identity
                    entry.dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }
                self.introLabel.text = intention
                self.introLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .semibold)
                self.introLabel.textColor = DesignTokens.Colors.textPrimary
                self.introLabel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                    self.introLabel.alpha = 1
                    self.introLabel.transform = .identity
                } completion: { _ in
                    UIView.animate(withDuration: 0.2, delay: duration - 0.5) {
                        self.introLabel.alpha = 0
                        entry.glow.alpha = 0
                        entry.dot.transform = .identity
                    }
                }
            }
        }

        // ── Phase 4: "Life happens." with 1.5s gap ──
        let labelsEnd = cumulativeDelay
        let lifeHappensTime = labelsEnd + 1.5
        let interruptStart = lifeHappensTime + 4.2
        let interruptInterval = 1.2

        // Pop in pill + "Life happens." centered, then swap to "You forget.", then move up
        schedule(after: lifeHappensTime) {

            self.lifeHappensPill.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                self.lifeHappensPill.alpha = 1
                self.lifeHappensPill.transform = .identity
                self.lifeHappensLabel.alpha = 1
            }

            // Swap to "You forget." after a longer beat
            UIView.animate(withDuration: 0.2, delay: 1.5) {
                self.lifeHappensLabel.alpha = 0
            } completion: { _ in
                self.lifeHappensLabel.text = "You forget."
                self.lifeHappensLabel.textColor = DesignTokens.Colors.destructive
                UIView.animate(withDuration: 0.3) {
                    self.lifeHappensLabel.alpha = 1
                }
            }

            // Move up, pill fades, then swap to "You're busy with..."
            UIView.animate(withDuration: 0.6, delay: 2.5, options: .curveEaseInOut) {
                self.lifeHappensLabel.frame = CGRect(x: 0, y: self.brainRect.minY - 55, width: self.bounds.width, height: 40)
                self.lifeHappensLabel.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
                self.lifeHappensPill.alpha = 0
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self.lifeHappensLabel.alpha = 0
                } completion: { _ in
                    self.lifeHappensLabel.text = "You're busy with..."
                    self.lifeHappensLabel.textColor = DesignTokens.Colors.textPrimary
                    UIView.animate(withDuration: 0.3) {
                        self.lifeHappensLabel.alpha = 1
                    }
                }
            }
        }

        // Interruptions push dots out — left dots go left, right dots go right
        for (i, interruption) in interruptions.prefix(dots.count).enumerated() {
            let delay = interruptStart + Double(i) * interruptInterval
            self.schedule(after: delay) { [self] in
                let entry = self.dots[i]

                // Sub-label
                self.interruptionLabel.text = interruption
                self.interruptionLabel.alpha = 0
                self.interruptionLabel.transform = CGAffineTransform(translationX: 0, y: 6)
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                    self.interruptionLabel.alpha = 0.8
                    self.interruptionLabel.transform = .identity
                } completion: { _ in
                    UIView.animate(withDuration: 0.25, delay: 0.4) {
                        self.interruptionLabel.alpha = 0
                        self.interruptionLabel.transform = CGAffineTransform(translationX: 0, y: -6)
                    }
                }

                // Push dot to the side (left dots go left, right go right)
                let sideX: CGFloat = entry.side == .left
                    ? self.brainRect.minX - 30
                    : self.brainRect.maxX + 30
                let targetY = entry.home.y

                UIView.animate(withDuration: 0.4, delay: 0.2) {
                    entry.dot.backgroundColor = DesignTokens.Colors.warning
                }
                UIView.animate(withDuration: 0.8, delay: 0.5, options: .curveEaseOut) {
                    entry.dot.backgroundColor = DesignTokens.Colors.destructive
                    entry.dot.center = CGPoint(x: sideX, y: targetY)
                    entry.dot.alpha = 0.5
                }
                UIView.animate(withDuration: 0.8, delay: 0.5) {
                    entry.glow.center = CGPoint(x: sideX, y: targetY)
                }
            }
        }

        // Dim brain
        let dimTime = interruptStart + Double(dots.count) * interruptInterval * 0.4
        schedule(after: dimTime) { [self] in
            let dim = CABasicAnimation(keyPath: "opacity")
            dim.toValue = 0.4; dim.duration = 1.5
            dim.fillMode = .forwards; dim.isRemovedOnCompletion = false
            self.brainLayer.add(dim, forKey: "dim")
        }

        // Fade "You forget." header after all dots are out
        let headerFadeTime = interruptStart + Double(dots.count) * interruptInterval
        UIView.animate(withDuration: 0.4, delay: headerFadeTime) {
            self.lifeHappensLabel.alpha = 0
        }

        // ── Phase 5: "Notifications & Reminders" header, then bring dots back ──
        // Wait for "You forget" to fully fade before showing
        let allOutTime = interruptStart + Double(dots.count) * interruptInterval + 1.5
        let returnInterval = 1.0

        // Show "Notifications & Reminders" with pill background
        schedule(after: allOutTime) {

            // Fully reset label state
            self.lifeHappensLabel.layer.removeAllAnimations()
            self.lifeHappensLabel.transform = .identity
            self.lifeHappensLabel.text = "Balloon Notifications"
            self.lifeHappensLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
            self.lifeHappensLabel.textColor = DesignTokens.Colors.textPrimary
            self.lifeHappensLabel.textAlignment = .center
            self.lifeHappensLabel.bounds = CGRect(x: 0, y: 0, width: self.bounds.width, height: 40)
            self.lifeHappensLabel.center = CGPoint(x: self.bounds.midX, y: self.brainRect.midY)
            self.lifeHappensLabel.alpha = 0

            // Reposition pill centered
            let textSize = self.lifeHappensLabel.intrinsicContentSize
            let pillPadH: CGFloat = 24, pillPadV: CGFloat = 12
            let pillW = textSize.width + pillPadH * 2
            let pillH = textSize.height + pillPadV * 2
            self.lifeHappensPill.frame = CGRect(
                x: self.bounds.midX - pillW / 2,
                y: self.brainRect.midY - pillH / 2,
                width: pillW, height: pillH
            )
            self.lifeHappensPill.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)

            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
                self.lifeHappensLabel.alpha = 1
                self.lifeHappensPill.alpha = 1
                self.lifeHappensPill.transform = .identity
            }

            // After a beat, move label up, pill fades
            UIView.animate(withDuration: 0.5, delay: 1.2, options: .curveEaseInOut) {
                self.lifeHappensLabel.center = CGPoint(x: self.bounds.midX, y: self.brainRect.minY - 35)
                self.lifeHappensLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                self.lifeHappensPill.alpha = 0
            }
        }

        // Start after header settles
        let notifStartTime = allOutTime + 2.0

        // ── First dot: card drains → expired → simulated pump press → refill → card hides → dot returns ──
        schedule(after: notifStartTime) { [self] in
            guard !self.dots.isEmpty else { return }
            let entry = self.dots[0]

            // Configure card
            self.miniCardTitle.text = self.intentions[0]
            self.miniCardTimer.text = "24h 00m"
            self.miniCardTimer.textColor = DesignTokens.Colors.success
            self.miniCardDot.backgroundColor = DesignTokens.Colors.success
            self.miniCardFill.removeAllAnimations()

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.miniCardFill.colors = [
                UIColor.clear.cgColor, UIColor.clear.cgColor,
                DesignTokens.Colors.success.withAlphaComponent(0.15).cgColor,
                DesignTokens.Colors.success.withAlphaComponent(0.15).cgColor,
            ]
            self.miniCardFill.locations = [0.0, 0.0, 0.001, 1.0]
            CATransaction.commit()

            // Highlight the dot with glow ring to show which one is selected
            entry.glow.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                entry.glow.alpha = 1
                entry.glow.transform = .identity
                entry.dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
            }

            // Show pump button
            self.miniCardPumpButton.alpha = 0.5
            self.miniCardPumpButton.isHidden = false

            // Pop card in (0.7s delay so the dot highlight registers first)
            self.miniCard.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            UIView.animate(withDuration: 0.35, delay: 0.7, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4) {
                self.miniCard.alpha = 1
                self.miniCard.transform = .identity
            }

            // One smooth drain animation: fill goes from full to empty over 4s
            let drainDuration: CFTimeInterval = 4.0

            let locDrain = CABasicAnimation(keyPath: "locations")
            locDrain.fromValue = [0.0, 0.0, 0.001, 1.0]
            locDrain.toValue = [0.0, 0.999, 1.0, 1.0]
            locDrain.duration = drainDuration
            locDrain.fillMode = .forwards; locDrain.isRemovedOnCompletion = false
            self.miniCardFill.add(locDrain, forKey: "drain")

            // Color shifts: green → yellow → red over the drain
            let colDrain = CAKeyframeAnimation(keyPath: "colors")
            let green = DesignTokens.Colors.success.withAlphaComponent(0.15).cgColor
            let yellow = DesignTokens.Colors.warning.withAlphaComponent(0.15).cgColor
            let red = DesignTokens.Colors.destructive.withAlphaComponent(0.15).cgColor
            let clear = UIColor.clear.cgColor
            colDrain.values = [
                [clear, clear, green, green],
                [clear, clear, yellow, yellow],
                [clear, clear, red, red],
            ]
            colDrain.keyTimes = [0.0, 0.5, 0.85]
            colDrain.duration = drainDuration
            colDrain.fillMode = .forwards; colDrain.isRemovedOnCompletion = false
            self.miniCardFill.add(colDrain, forKey: "drainColor")

            // Smooth timer countdown via display link
            self.timerStartTime = CACurrentMediaTime()
            self.timerDrainDuration = drainDuration
            self.timerTotalSeconds = 86400 // 24h
            self.startTimerCountdown()

            // t+4.3: Timer expired — slide big push notification banner down, slowly grows
            self.schedule(after: 4.3) {
                Haptics.medium()
                let bannerH: CGFloat = 70
                self.pushBanner.frame.origin.y = -bannerH - 10
                self.pushBanner.alpha = 1
                self.pushBanner.transform = .identity

                // Slide down
                UIView.animate(
                    withDuration: 0.5,
                    delay: 0,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 0.3
                ) {
                    self.pushBanner.frame.origin.y = 8
                }

                // Slowly grow while visible (3s)
                UIView.animate(withDuration: 3.0, delay: 0.3, options: .curveLinear) {
                    self.pushBanner.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                }
            }

            // t+7.3: Slide banner back up (3s hold)
            self.schedule(after: 7.3) {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
                    self.pushBanner.frame.origin.y = -80
                    self.pushBanner.alpha = 0
                    self.pushBanner.transform = .identity
                }
            }

            // t+7.8: Hand cursor slides in toward pump button, then taps
            self.schedule(after: 7.8) {
                self.stopTimerCountdown()

                // Position hand to the right of the pump button
                let buttonCenter = self.miniCardPumpButton.superview!.convert(self.miniCardPumpButton.center, to: self)
                self.tapHand.center = CGPoint(x: buttonCenter.x + 40, y: buttonCenter.y + 30)
                self.tapHand.alpha = 0

                // Fade hand in + slide toward button
                UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                    self.tapHand.alpha = 0.9
                    self.tapHand.center = CGPoint(x: buttonCenter.x + 8, y: buttonCenter.y + 8)
                } completion: { _ in
                    // Tap: hand presses down
                    UIView.animate(withDuration: 0.08) {
                        self.tapHand.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
                        self.miniCardPumpButton.alpha = 1.0
                        self.miniCardPumpButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                    } completion: { _ in
                        Haptics.heavy()

                        // Dot turns green + pulse + ring burst
                        UIView.animate(withDuration: 0.15) {
                            entry.dot.backgroundColor = DesignTokens.Colors.success
                            entry.dot.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
                        } completion: { _ in
                            UIView.animate(withDuration: 0.15) {
                                entry.dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5) // stays highlighted
                            }
                        }

                        // Ring burst from the dot
                        let dotCenter = entry.dot.center
                        let ring = CAShapeLayer()
                        ring.path = UIBezierPath(arcCenter: dotCenter, radius: 5, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
                        ring.fillColor = UIColor.clear.cgColor
                        ring.strokeColor = DesignTokens.Colors.success.withAlphaComponent(0.5).cgColor
                        ring.lineWidth = 2
                        ring.opacity = 0
                        self.layer.addSublayer(ring)

                        let expand = CABasicAnimation(keyPath: "path")
                        expand.toValue = UIBezierPath(arcCenter: dotCenter, radius: 20, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
                        expand.duration = 0.4
                        let ringFade = CAKeyframeAnimation(keyPath: "opacity")
                        ringFade.values = [0.0, 0.6, 0.0]
                        ringFade.keyTimes = [0.0, 0.2, 1.0]
                        ringFade.duration = 0.4
                        let thin = CABasicAnimation(keyPath: "lineWidth")
                        thin.fromValue = 2.0; thin.toValue = 0.5; thin.duration = 0.4
                        let group = CAAnimationGroup()
                        group.animations = [expand, ringFade, thin]
                        group.duration = 0.4
                        group.isRemovedOnCompletion = true
                        ring.add(group, forKey: "pulse")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ring.removeFromSuperlayer() }

                        // Hand releases
                        UIView.animate(withDuration: 0.3) {
                            self.tapHand.transform = .identity
                        }

                        // Button bounces back immediately
                        UIView.animate(
                            withDuration: 0.5,
                            delay: 0,
                            usingSpringWithDamping: 0.35,
                            initialSpringVelocity: 12
                        ) {
                            self.miniCardPumpButton.transform = .identity
                        }

                        // Pause 1s after click, then refill
                        UIView.animate(withDuration: 0.3, delay: 0.6) {
                            self.tapHand.alpha = 0
                        }

                        self.schedule(after: 1.0) {
                            // Card scale pop
                            UIView.animate(
                                withDuration: 0.4,
                                delay: 0,
                                usingSpringWithDamping: 0.5,
                                initialSpringVelocity: 8
                            ) {
                                self.miniCard.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                            } completion: { _ in
                                UIView.animate(withDuration: 0.2) {
                                    self.miniCard.transform = .identity
                                }
                            }

                            // Refill gauge green
                            self.miniCardFill.removeAllAnimations()
                            let refillLoc = CABasicAnimation(keyPath: "locations")
                            refillLoc.toValue = [0.0, 0.0, 0.001, 1.0]
                            refillLoc.duration = 0.5; refillLoc.fillMode = .forwards; refillLoc.isRemovedOnCompletion = false
                            self.miniCardFill.add(refillLoc, forKey: "refill")
                            let refillCol = CABasicAnimation(keyPath: "colors")
                            refillCol.toValue = [UIColor.clear.cgColor, UIColor.clear.cgColor,
                                                 DesignTokens.Colors.success.withAlphaComponent(0.15).cgColor,
                                                 DesignTokens.Colors.success.withAlphaComponent(0.15).cgColor]
                            refillCol.duration = 0.5; refillCol.fillMode = .forwards; refillCol.isRemovedOnCompletion = false
                            self.miniCardFill.add(refillCol, forKey: "refillColor")

                            // Timer resets green
                            self.miniCardTimer.text = "24h 00m"
                            UIView.animate(withDuration: 0.3) {
                                self.miniCardTimer.textColor = DesignTokens.Colors.success
                                self.miniCardDot.backgroundColor = DesignTokens.Colors.success
                            }
                        }
                    }
                }
            }

            // t+11.0: Card hides (after refill has time to register), first dot returns
            self.schedule(after: 11.0) {
                UIView.animate(withDuration: 0.3) {
                    self.miniCard.alpha = 0
                }

                // Remove glow highlight + reset dot size
                UIView.animate(withDuration: 0.3) {
                    entry.glow.alpha = 0
                    entry.dot.transform = .identity
                }

                UIView.animate(withDuration: 0.5, delay: 0.3, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                    entry.dot.center = entry.home
                    entry.dot.alpha = 1
                    entry.dot.backgroundColor = DesignTokens.Colors.success
                    entry.glow.center = entry.home
                } completion: { _ in
                    // First dot is back — start remaining dots
                    self.schedule(after: 0.5) {
                        self.returnNextDot(at: 0, indices: Array(1..<self.dots.count))
                    }
                }

                let brighten = CABasicAnimation(keyPath: "opacity")
                brighten.toValue = 0.5; brighten.duration = 0.3
                brighten.beginTime = CACurrentMediaTime() + 0.3
                brighten.fillMode = .forwards; brighten.isRemovedOnCompletion = false
                self.brainLayer.add(brighten, forKey: "brighten_0")
            }
        }
    }

    // MARK: - Sequential Dot Return

    /// Animates one dot back, then calls itself for the next. Guarantees no overlap.
    private func returnNextDot(at seq: Int, indices: [Int]) {
        guard seq < indices.count else {
            // All dots returned — play the ending
            schedule(after: 0.5) { self.playEnding() }
            return
        }

        let idx = indices[seq]
        let entry = dots[idx]

        notifLabel.text = "Balloon Push Notification"
        Haptics.light()

        notificationBadge?.layer.removeAllAnimations()
        notificationBadge?.alpha = 0
        notificationBadge?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4) {
            self.notificationBadge?.alpha = 1
            self.notificationBadge?.transform = .identity
        }

        // Pulse the dot + turn green + ring burst
        UIView.animate(withDuration: 0.15, delay: 0.1) {
            entry.dot.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
            entry.dot.alpha = 0.8
            entry.dot.backgroundColor = DesignTokens.Colors.success
        } completion: { _ in
            UIView.animate(withDuration: 0.15) {
                entry.dot.transform = .identity
                entry.dot.alpha = 0.5
            }
        }

        // Expanding ring pulse from the dot
        let ring = CAShapeLayer()
        let dotCenter = entry.dot.center
        ring.path = UIBezierPath(arcCenter: dotCenter, radius: 5, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = DesignTokens.Colors.success.withAlphaComponent(0.5).cgColor
        ring.lineWidth = 2
        ring.opacity = 0
        layer.addSublayer(ring)

        let expand = CABasicAnimation(keyPath: "path")
        expand.toValue = UIBezierPath(arcCenter: dotCenter, radius: 20, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        expand.duration = 0.4

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.6, 0.0]
        fade.keyTimes = [0.0, 0.2, 1.0]
        fade.duration = 0.4

        let thin = CABasicAnimation(keyPath: "lineWidth")
        thin.fromValue = 2.0
        thin.toValue = 0.5
        thin.duration = 0.4

        let group = CAAnimationGroup()
        group.animations = [expand, fade, thin]
        group.duration = 0.4
        group.beginTime = CACurrentMediaTime() + 0.1
        group.isRemovedOnCompletion = true
        ring.add(group, forKey: "pulse")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ring.removeFromSuperlayer()
        }

        UIView.animate(withDuration: 0.5, delay: 0.6, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
            entry.dot.center = entry.home
            entry.dot.alpha = 1
            entry.dot.transform = .identity
            entry.dot.backgroundColor = DesignTokens.Colors.success
            entry.glow.center = entry.home
        } completion: { _ in
            // Hide badge
            UIView.animate(withDuration: 0.25) {
                self.notificationBadge?.alpha = 0
            } completion: { _ in
                // Trigger next dot after badge is fully hidden
                self.schedule(after: 0.15) {
                    self.returnNextDot(at: seq + 1, indices: indices)
                }
            }
        }

        let progress = Float(seq + 2) / Float(dots.count)
        let brighten = CABasicAnimation(keyPath: "opacity")
        brighten.toValue = 0.5 + progress * 0.5; brighten.duration = 0.3
        brighten.beginTime = CACurrentMediaTime() + 0.4
        brighten.fillMode = .forwards; brighten.isRemovedOnCompletion = false
        brainLayer.add(brighten, forKey: "brighten_\(idx)")
    }

    // MARK: - Ending

    private func playEnding() {
        // "Everything stays top of mind."
        lifeHappensLabel.layer.removeAllAnimations()
        lifeHappensLabel.text = "Everything stays top of mind."
        lifeHappensLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        lifeHappensLabel.textColor = DesignTokens.Colors.success
        lifeHappensLabel.textAlignment = .center
        lifeHappensLabel.numberOfLines = 0
        lifeHappensLabel.transform = .identity
        lifeHappensLabel.frame = CGRect(x: 0, y: brainRect.maxY + 15, width: bounds.width, height: 50)

        UIView.animate(withDuration: 0.4) {
            self.lifeHappensLabel.alpha = 1
        }

        // Hold, then fade everything out
        schedule(after: 2.0) {
            for layer in [self.brainLayer, self.fissureLayer] + self.foldLayers {
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.toValue = 0
                fade.duration = 1.0
                fade.fillMode = .forwards
                fade.isRemovedOnCompletion = false
                layer.add(fade, forKey: "fadeOut")
            }

            UIView.animate(withDuration: 1.0) {
                for d in self.dots {
                    d.dot.alpha = 0
                    d.glow.alpha = 0
                }
                self.lifeHappensLabel.alpha = 0
            }
        }

        // Show replay after fade
        schedule(after: 3.2) {
            self.onAnimationComplete?()
            UIView.animate(withDuration: 0.3, delay: 0.3) {
                self.replayButton.alpha = 1
            }
        }
    }

    // MARK: - Timer Countdown

    private func startTimerCountdown() {
        timerLink?.invalidate()
        timerLink = CADisplayLink(target: self, selector: #selector(updateTimerCountdown))
        timerLink?.add(to: .main, forMode: .common)
    }

    private func stopTimerCountdown() {
        timerLink?.invalidate()
        timerLink = nil
    }

    @objc private func updateTimerCountdown() {
        let elapsed = CACurrentMediaTime() - timerStartTime
        let progress = min(elapsed / timerDrainDuration, 1.0) // 0..1
        let remaining = timerTotalSeconds * (1.0 - progress)

        if remaining <= 0 {
            miniCardTimer.text = "Expired"
            miniCardTimer.textColor = DesignTokens.Colors.destructive
            miniCardDot.backgroundColor = DesignTokens.Colors.destructive
            stopTimerCountdown()
            return
        }

        let total = Int(remaining)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            miniCardTimer.text = String(format: "%dh %02dm", h, m)
        } else if m > 0 {
            miniCardTimer.text = String(format: "%dm %02ds", m, s)
        } else {
            miniCardTimer.text = "\(s)s"
        }

        // Color based on progress
        if progress < 0.5 {
            miniCardTimer.textColor = DesignTokens.Colors.success
            miniCardDot.backgroundColor = DesignTokens.Colors.success
        } else if progress < 0.8 {
            miniCardTimer.textColor = DesignTokens.Colors.warning
            miniCardDot.backgroundColor = DesignTokens.Colors.warning
        } else {
            miniCardTimer.textColor = DesignTokens.Colors.destructive
            miniCardDot.backgroundColor = DesignTokens.Colors.destructive
        }
    }

    private func startTrackingLine(dotIndex: Int) {
        trackingDotIndex = dotIndex
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateConnectorLine))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopTrackingLine() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateConnectorLine() {
        guard trackingDotIndex < dots.count else { return }
        // Use presentation layer to get the in-flight animated position
        let dot = dots[trackingDotIndex].dot
        let currentCenter = dot.layer.presentation()?.position ?? dot.center
        let path = UIBezierPath()
        path.move(to: badgeCenterPoint)
        path.addLine(to: currentCenter)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        connectorLine.path = path.cgPath
        CATransaction.commit()
    }

    func stopAnimations() {
        // Invalidate all pending scheduled blocks
        animationGeneration += 1

        stopTrackingLine()
        stopTimerCountdown()

        // Remove all CA animations
        brainLayer.removeAllAnimations()
        fissureLayer.removeAllAnimations()
        for fl in foldLayers { fl.removeAllAnimations() }
        introLabel?.layer.removeAllAnimations()
        lifeHappensPill?.layer.removeAllAnimations()
        lifeHappensLabel?.layer.removeAllAnimations()
        interruptionLabel?.layer.removeAllAnimations()
        for d in dots {
            d.dot.layer.removeAllAnimations()
            d.glow.layer.removeAllAnimations()
        }
        notificationBadge?.layer.removeAllAnimations()
        connectorLine.removeAllAnimations()

        // Reset all view/layer states to initial so replay works cleanly
        brainLayer.opacity = 0
        brainLayer.fillColor = UIColor.clear.cgColor
        fissureLayer.opacity = 0
        for fl in foldLayers { fl.opacity = 0 }

        introLabel?.alpha = 0
        introLabel?.text = "Your brain"
        introLabel?.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        introLabel?.textColor = DesignTokens.Colors.warning

        lifeHappensPill?.alpha = 0
        lifeHappensPill?.transform = .identity
        if let pill = lifeHappensPill {
            let textSize = lifeHappensLabel.intrinsicContentSize
            let pillPadH: CGFloat = 24, pillPadV: CGFloat = 12
            let pillW = textSize.width + pillPadH * 2
            let pillH = textSize.height + pillPadV * 2
            pill.frame = CGRect(x: bounds.midX - pillW / 2, y: brainRect.midY - pillH / 2, width: pillW, height: pillH)
        }

        lifeHappensLabel?.alpha = 0
        lifeHappensLabel?.text = "Life happens."
        lifeHappensLabel?.textColor = DesignTokens.Colors.textPrimary
        lifeHappensLabel?.transform = .identity
        lifeHappensLabel?.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        lifeHappensLabel?.frame = CGRect(x: 0, y: brainRect.midY - 20, width: bounds.width, height: 40)

        interruptionLabel?.alpha = 0
        interruptionLabel?.transform = .identity
        interruptionLabel?.frame = CGRect(x: 0, y: brainRect.minY - 24, width: bounds.width, height: 24)

        for d in dots {
            d.dot.center = d.home
            d.dot.alpha = 0
            d.dot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            d.dot.backgroundColor = DesignTokens.Colors.success
            d.glow.center = d.home
            d.glow.alpha = 0
            d.glow.transform = .identity
        }

        miniCard?.alpha = 0
        miniCard?.transform = .identity
        miniCardFill?.removeAllAnimations()
        miniCardPumpButton?.transform = .identity
        miniCardPumpButton?.alpha = 0.5

        pushBanner?.alpha = 0
        pushBanner?.frame.origin.y = -80
        pushBanner?.transform = .identity

        tapHand?.alpha = 0
        tapHand?.transform = .identity
        replayButton?.alpha = 0

        notificationBadge?.alpha = 0
        notificationBadge?.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.9, y: 0.9)
        connectorLine.opacity = 0
        connectorLine.path = nil
    }
}
