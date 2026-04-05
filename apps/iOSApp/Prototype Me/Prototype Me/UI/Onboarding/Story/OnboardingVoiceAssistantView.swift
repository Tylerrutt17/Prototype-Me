import UIKit

/// Chat-style demo: a mic bubble pulses, the user's spoken request gets
/// transcribed, the app "thinks", and then a response bubble confirms the
/// action it took. Conveys the "talk or type to change things or ask things"
/// feature.
final class OnboardingVoiceAssistantView: UIView, StoryAnimatable {

    private let userBubble = UIView()
    private let userMicIcon = UIImageView()
    private let userLabel = UILabel()
    private let userRing1 = CAShapeLayer()
    private let userRing2 = CAShapeLayer()

    private let thinkingBubble = UIView()
    private let thinkingDots: [UIView] = (0..<3).map { _ in
        let dot = UIView()
        dot.layer.cornerRadius = 3
        return dot
    }

    private let appBubble = UIView()
    private let appSparkIcon = UIImageView()
    private let appLabel = UILabel()

    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0

    private let userPhrase = "swap my sleep directive for something specific"
    private let appResponse = "Done — now: Same bedtime, every night"

    var prefersFullWidth: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildLayout()
        }
        updateRingPaths()
    }

    // MARK: - Build

    private func buildLayout() {
        buildUserBubble()
        buildThinkingBubble()
        buildAppBubble()

        NSLayoutConstraint.activate([
            userBubble.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.lg),
            userBubble.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            userBubble.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xxl),

            thinkingBubble.topAnchor.constraint(equalTo: userBubble.bottomAnchor, constant: DesignTokens.Spacing.md),
            thinkingBubble.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),

            appBubble.topAnchor.constraint(equalTo: thinkingBubble.bottomAnchor, constant: DesignTokens.Spacing.md),
            appBubble.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            appBubble.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xxl),
        ])
    }

    private func buildUserBubble() {
        let accent = DesignTokens.Colors.accent
        userBubble.backgroundColor = accent.withAlphaComponent(0.15)
        userBubble.layer.cornerRadius = DesignTokens.Radii.lg
        userBubble.layer.borderWidth = 1
        userBubble.layer.borderColor = accent.withAlphaComponent(0.35).cgColor
        userBubble.alpha = 0
        userBubble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(userBubble)

        // Sound-wave rings behind the mic (animated outward)
        userRing1.fillColor = UIColor.clear.cgColor
        userRing1.strokeColor = accent.withAlphaComponent(0.5).cgColor
        userRing1.lineWidth = 1.5
        userRing1.opacity = 0
        userBubble.layer.addSublayer(userRing1)

        userRing2.fillColor = UIColor.clear.cgColor
        userRing2.strokeColor = accent.withAlphaComponent(0.5).cgColor
        userRing2.lineWidth = 1.5
        userRing2.opacity = 0
        userBubble.layer.addSublayer(userRing2)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        userMicIcon.image = UIImage(systemName: "mic.fill", withConfiguration: iconConfig)
        userMicIcon.tintColor = accent
        userMicIcon.contentMode = .scaleAspectFit
        userMicIcon.translatesAutoresizingMaskIntoConstraints = false

        userLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        userLabel.textColor = DesignTokens.Colors.textPrimary
        userLabel.numberOfLines = 0
        userLabel.text = ""

        let row = UIStackView(arrangedSubviews: [userMicIcon, userLabel])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        userBubble.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            userMicIcon.widthAnchor.constraint(equalToConstant: 18),
            userMicIcon.heightAnchor.constraint(equalToConstant: 18),
            row.topAnchor.constraint(equalTo: userBubble.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: userBubble.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: userBubble.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: userBubble.trailingAnchor, constant: -pad),
        ])
    }

    private func buildThinkingBubble() {
        thinkingBubble.backgroundColor = DesignTokens.Colors.surfacePrimary
        thinkingBubble.layer.cornerRadius = DesignTokens.Radii.md
        thinkingBubble.layer.borderWidth = 1
        thinkingBubble.layer.borderColor = DesignTokens.Colors.separator.cgColor
        thinkingBubble.alpha = 0
        thinkingBubble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thinkingBubble)

        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 4
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        thinkingBubble.addSubview(dotsStack)

        for dot in thinkingDots {
            dot.backgroundColor = DesignTokens.Colors.textTertiary
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 6).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            dotsStack.addArrangedSubview(dot)
        }

        NSLayoutConstraint.activate([
            dotsStack.topAnchor.constraint(equalTo: thinkingBubble.topAnchor, constant: DesignTokens.Spacing.sm + 2),
            dotsStack.bottomAnchor.constraint(equalTo: thinkingBubble.bottomAnchor, constant: -(DesignTokens.Spacing.sm + 2)),
            dotsStack.leadingAnchor.constraint(equalTo: thinkingBubble.leadingAnchor, constant: DesignTokens.Spacing.md),
            dotsStack.trailingAnchor.constraint(equalTo: thinkingBubble.trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])
    }

    private func buildAppBubble() {
        let success = DesignTokens.Colors.success
        appBubble.backgroundColor = DesignTokens.Colors.surfacePrimary
        appBubble.layer.cornerRadius = DesignTokens.Radii.lg
        appBubble.layer.borderWidth = 1
        appBubble.layer.borderColor = success.withAlphaComponent(0.4).cgColor
        appBubble.alpha = 0
        appBubble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(appBubble)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        appSparkIcon.image = UIImage(systemName: "sparkles", withConfiguration: iconConfig)
        appSparkIcon.tintColor = success
        appSparkIcon.contentMode = .scaleAspectFit
        appSparkIcon.translatesAutoresizingMaskIntoConstraints = false

        appLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        appLabel.textColor = DesignTokens.Colors.textPrimary
        appLabel.numberOfLines = 0
        appLabel.text = appResponse

        let row = UIStackView(arrangedSubviews: [appSparkIcon, appLabel])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .top
        row.translatesAutoresizingMaskIntoConstraints = false
        appBubble.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            appSparkIcon.widthAnchor.constraint(equalToConstant: 18),
            appSparkIcon.heightAnchor.constraint(equalToConstant: 18),
            row.topAnchor.constraint(equalTo: appBubble.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: appBubble.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: appBubble.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: appBubble.trailingAnchor, constant: -pad),
        ])
    }

    private func updateRingPaths() {
        guard userBubble.bounds.height > 0 else { return }
        // Position rings around the mic icon (top-left area of user bubble)
        let iconCenter = CGPoint(
            x: DesignTokens.Spacing.md + 9,
            y: DesignTokens.Spacing.md + 9
        )
        let path = UIBezierPath(arcCenter: iconCenter, radius: 10, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        userRing1.path = path
        userRing2.path = path
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        cycleID += 1
        let currentCycle = cycleID
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            userBubble.alpha = 1
            userLabel.text = userPhrase
            appBubble.alpha = 1
            return
        }

        // 1. User bubble slides in from the right
        userBubble.transform = CGAffineTransform(translationX: 40, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.userBubble.alpha = 1
            self.userBubble.transform = .identity
        }

        // 2. Mic rings pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.pulseRings()
        }

        // 3. Transcribe text word-by-word
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.transcribeText(self.userPhrase, cycle: currentCycle)
        }

        // 4. Thinking bubble after transcription finishes (~1.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            UIView.animate(withDuration: 0.2) { self.thinkingBubble.alpha = 1 }
            self.animateThinkingDots(cycle: currentCycle)
        }

        // 5. App response bubble
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            UIView.animate(withDuration: 0.3) { self.thinkingBubble.alpha = 0 }
            self.appBubble.transform = CGAffineTransform(translationX: -30, y: 0)
            UIView.animate(withDuration: 0.45, delay: 0.15, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3) {
                self.appBubble.alpha = 1
                self.appBubble.transform = .identity
            }
            Haptics.success()
        }

        // 6. Loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.playEntrance()
        }
    }

    private func transcribeText(_ phrase: String, cycle: Int) {
        let words = phrase.split(separator: " ").map(String.init)
        var current = ""
        for (i, word) in words.enumerated() {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == cycle else { return }
                current += (current.isEmpty ? "" : " ") + word
                self.userLabel.text = current
            }
        }
    }

    private func pulseRings() {
        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.6
        scaleAnim.toValue = 2.2
        scaleAnim.duration = 1.2

        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 0.6
        fadeAnim.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [scaleAnim, fadeAnim]
        group.duration = 1.2
        group.repeatCount = 2
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        userRing1.add(group, forKey: "ring1")

        let group2 = CAAnimationGroup()
        group2.animations = [scaleAnim, fadeAnim]
        group2.duration = 1.2
        group2.beginTime = CACurrentMediaTime() + 0.4
        group2.repeatCount = 2
        group2.timingFunction = CAMediaTimingFunction(name: .easeOut)
        userRing2.add(group2, forKey: "ring2")
    }

    private func animateThinkingDots(cycle: Int) {
        for (i, dot) in thinkingDots.enumerated() {
            let bounce = CABasicAnimation(keyPath: "transform.translation.y")
            bounce.fromValue = 0
            bounce.toValue = -3
            bounce.duration = 0.3
            bounce.autoreverses = true
            bounce.repeatCount = 2
            bounce.beginTime = CACurrentMediaTime() + Double(i) * 0.1
            bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.layer.add(bounce, forKey: "bounce")
        }
    }

    func stopAnimations() {
        isStopped = true
        userBubble.layer.removeAllAnimations()
        thinkingBubble.layer.removeAllAnimations()
        appBubble.layer.removeAllAnimations()
        userRing1.removeAllAnimations()
        userRing2.removeAllAnimations()
        for dot in thinkingDots { dot.layer.removeAllAnimations() }
    }

    // MARK: - Reset

    private func resetState() {
        userBubble.alpha = 0
        userBubble.transform = .identity
        userLabel.text = ""
        userRing1.removeAllAnimations()
        userRing2.removeAllAnimations()

        thinkingBubble.alpha = 0
        for dot in thinkingDots { dot.layer.removeAllAnimations() }

        appBubble.alpha = 0
        appBubble.transform = .identity
        appLabel.text = appResponse
    }
}
