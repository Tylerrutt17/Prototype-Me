import UIKit

/// Capture demo: the view fills with a chaotic cloud of drifting thought
/// fragments (mental overflow). The note card emerges, magnetically pulls
/// all the noise into itself, and settles with a clean list of organized
/// observations. Conveys "your head is full — give it somewhere to land."
final class OnboardingCaptureThoughtsView: UIView, StoryAnimatable {

    private let noteCard = UIView()
    private let noteHeader = UILabel()
    private let noteStack = UIStackView()
    private let borderTraceLayer = CAShapeLayer()

    private var noiseLabels: [UILabel] = []
    private var noiseHomes: [CGPoint] = []
    private var noiseDrifts: [(vector: CGVector, duration: TimeInterval, delay: TimeInterval)] = []
    private var noiseFadeAlphas: [CGFloat] = []
    private var listRows: [UIView] = []

    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0

    // The observations that land in the card at the end.
    private let observations: [String] = [
        "what worked",
        "what didn't",
    ]

    // The broader cloud of "noise" — fragments, half-thoughts, to-dos.
    private let noiseFragments: [String] = [
        "call mom", "emails", "remember to", "tired again",
        "why can't I", "one more thing", "meeting at 3", "groceries",
        "sleep more", "budget", "that email", "dentist",
        "laundry", "what if", "deadline friday", "water plants",
        "gym later?", "pay rent", "breathe", "follow up",
        "didn't sleep", "book flight", "should I", "too much coffee",
        "text back", "check-in", "car service", "what did I eat",
        "skipped gym", "birthday gift", "send invoice", "sunday plans",
        "stretch more", "vitamins", "screen time",
    ]

    var prefersFullWidth: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 && bounds.height > 0 {
            hasBuilt = true
            buildLayout()
        }
        // Keep the traced border path in sync with the card's current bounds.
        if noteCard.bounds.width > 0 {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            borderTraceLayer.frame = noteCard.bounds
            borderTraceLayer.path = UIBezierPath(
                roundedRect: noteCard.bounds,
                cornerRadius: DesignTokens.Radii.lg
            ).cgPath
            CATransaction.commit()
        }
    }

    // MARK: - Build

    private func buildLayout() {
        buildNoiseCloud()
        buildNoteCard()
        buildListRows()
        layoutIfNeeded()
    }

    private func buildNoiseCloud() {
        // Deterministic pseudo-random positions so each cycle looks the same.
        var rng = SeededGenerator(seed: 42)
        let w = bounds.width
        let h = bounds.height

        for fragment in noiseFragments {
            let label = UILabel()
            label.text = fragment
            let size = CGFloat.random(in: 11...15, using: &rng)
            label.font = UIFont.italicSystemFont(ofSize: size)
            label.textColor = DesignTokens.Colors.textTertiary
            label.alpha = 0
            label.translatesAutoresizingMaskIntoConstraints = true
            label.sizeToFit()
            addSubview(label)

            // Scatter across the whole view, avoiding the dead-center card zone.
            var point: CGPoint
            repeat {
                point = CGPoint(
                    x: CGFloat.random(in: 0.05...0.95, using: &rng) * w,
                    y: CGFloat.random(in: 0.05...0.95, using: &rng) * h
                )
            } while abs(point.x - w / 2) < w * 0.22 && abs(point.y - h / 2) < h * 0.18

            label.center = point
            noiseLabels.append(label)
            noiseHomes.append(point)

            // Per-label drift parameters and resting alpha (stable across cycles).
            let drift = CGVector(
                dx: CGFloat.random(in: -22...22, using: &rng),
                dy: CGFloat.random(in: -22...22, using: &rng)
            )
            let duration = TimeInterval.random(in: 2.0...3.6, using: &rng)
            let delay = TimeInterval.random(in: 0...0.9, using: &rng)
            noiseDrifts.append((drift, duration, delay))
            noiseFadeAlphas.append(CGFloat.random(in: 0.55...0.9, using: &rng))
        }
    }

    private func buildNoteCard() {
        let accent = DesignTokens.Colors.accent
        noteCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        noteCard.layer.cornerRadius = DesignTokens.Radii.lg
        noteCard.layer.borderWidth = 1
        noteCard.layer.borderColor = accent.withAlphaComponent(0.35).cgColor
        noteCard.alpha = 0
        noteCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(noteCard)

        // Traced border that draws on as the card emerges.
        borderTraceLayer.fillColor = UIColor.clear.cgColor
        borderTraceLayer.strokeColor = accent.cgColor
        borderTraceLayer.lineWidth = 2
        borderTraceLayer.lineCap = .round
        borderTraceLayer.strokeEnd = 0
        noteCard.layer.addSublayer(borderTraceLayer)

        noteHeader.text = "LIST"
        noteHeader.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold)
        noteHeader.textColor = accent
        noteHeader.translatesAutoresizingMaskIntoConstraints = false
        noteCard.addSubview(noteHeader)

        noteStack.axis = .vertical
        noteStack.spacing = DesignTokens.Spacing.xs
        noteStack.alignment = .fill
        noteStack.translatesAutoresizingMaskIntoConstraints = false
        noteCard.addSubview(noteStack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            noteCard.centerXAnchor.constraint(equalTo: centerXAnchor),
            noteCard.centerYAnchor.constraint(equalTo: centerYAnchor),
            noteCard.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.75),

            noteHeader.topAnchor.constraint(equalTo: noteCard.topAnchor, constant: pad),
            noteHeader.leadingAnchor.constraint(equalTo: noteCard.leadingAnchor, constant: pad),
            noteHeader.trailingAnchor.constraint(equalTo: noteCard.trailingAnchor, constant: -pad),

            noteStack.topAnchor.constraint(equalTo: noteHeader.bottomAnchor, constant: DesignTokens.Spacing.sm),
            noteStack.leadingAnchor.constraint(equalTo: noteCard.leadingAnchor, constant: pad),
            noteStack.trailingAnchor.constraint(equalTo: noteCard.trailingAnchor, constant: -pad),
            noteStack.bottomAnchor.constraint(equalTo: noteCard.bottomAnchor, constant: -pad),
        ])
    }

    private func buildListRows() {
        let styles: [(symbol: String, tint: UIColor)] = [
            ("checkmark.circle.fill", DesignTokens.Colors.success),
            ("xmark.circle.fill", DesignTokens.Colors.warning),
        ]
        for (i, text) in observations.enumerated() {
            let style = styles[i % styles.count]
            let row = buildStylizedRow(text: text, symbolName: style.symbol, tint: style.tint)
            noteStack.addArrangedSubview(row)
            listRows.append(row)
        }
        // Give a touch more breathing room between the two items.
        noteStack.spacing = DesignTokens.Spacing.sm
    }

    private func buildStylizedRow(text: String, symbolName: String, tint: UIColor) -> UIView {
        let row = UIView()
        row.alpha = 0
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: symbolName, withConfiguration: iconConfig))
        iconView.tintColor = tint
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .callout, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary
        label.numberOfLines = 1

        // Subtle pill background tinted to the row's status color.
        let pill = UIView()
        pill.backgroundColor = tint.withAlphaComponent(0.08)
        pill.layer.cornerRadius = 8
        pill.layer.borderWidth = 1
        pill.layer.borderColor = tint.withAlphaComponent(0.25).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(pill)

        let rowStack = UIStackView(arrangedSubviews: [iconView, label, UIView()])
        rowStack.axis = .horizontal
        rowStack.spacing = DesignTokens.Spacing.sm
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(rowStack)

        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: row.topAnchor),
            pill.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            pill.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: row.trailingAnchor),

            rowStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 6),
            rowStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -6),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -10),
        ])
        return row
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        cycleID += 1
        let currentCycle = cycleID
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            noteCard.alpha = 1
            for row in listRows { row.alpha = 1 }
            return
        }

        let cardCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        // 1. Noise cloud fades in gently and chaotically — staggered, soft ease.
        for (i, label) in noiseLabels.enumerated() {
            let fadeDelay = 0.1 + Double(i) * 0.05
            let targetAlpha = i < noiseFadeAlphas.count ? noiseFadeAlphas[i] : 0.5
            UIView.animate(withDuration: 0.9, delay: fadeDelay, options: [.curveEaseInOut, .allowUserInteraction]) {
                label.alpha = targetAlpha
            }
        }

        // 2. Each fragment starts drifting once it's visible — varied direction/duration.
        for (i, label) in noiseLabels.enumerated() {
            guard i < noiseDrifts.count else { continue }
            let d = noiseDrifts[i]
            UIView.animate(
                withDuration: d.duration,
                delay: 0.3 + d.delay,
                options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut],
                animations: {
                    label.transform = CGAffineTransform(translationX: d.vector.dx, y: d.vector.dy)
                }
            )
        }

        // 3. Beat — let the noise sit and overwhelm. Then the card emerges.
        let cardEmergeTime: TimeInterval = 3.2
        UIView.animate(withDuration: 0.55, delay: cardEmergeTime, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3, options: .curveEaseOut) {
            self.noteCard.alpha = 1
            self.noteCard.transform = .identity
        }

        // Border trace — draws on around the card perimeter as it emerges.
        DispatchQueue.main.asyncAfter(deadline: .now() + cardEmergeTime) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            let stroke = CABasicAnimation(keyPath: "strokeEnd")
            stroke.fromValue = 0
            stroke.toValue = 1
            stroke.duration = 0.9
            stroke.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            stroke.fillMode = .forwards
            stroke.isRemovedOnCompletion = false
            self.borderTraceLayer.strokeEnd = 1
            self.borderTraceLayer.add(stroke, forKey: "borderTrace")
        }

        // 4. The pull — every noise fragment gets sucked toward the card,
        // shrinking + fading. Stop drift first so the pull looks clean.
        let pullStart = cardEmergeTime + 0.2
        for (i, label) in noiseLabels.enumerated() {
            let staggered = pullStart + Double(i) * 0.02
            DispatchQueue.main.asyncAfter(deadline: .now() + staggered) { [weak self, weak label] in
                guard let self, let label, !self.isStopped, self.cycleID == currentCycle else { return }
                label.layer.removeAllAnimations()
                UIView.animate(
                    withDuration: 0.7,
                    delay: 0,
                    usingSpringWithDamping: 0.95,
                    initialSpringVelocity: 0.5,
                    options: [.curveEaseIn, .allowUserInteraction],
                    animations: {
                        label.center = cardCenter
                        label.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
                        label.alpha = 0
                    }
                )
            }
        }

        // 4. Clean list items rise up inside the card.
        let listStart = pullStart + 0.55
        for (i, row) in listRows.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: listStart + Double(i) * 0.12,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 0.4,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    row.alpha = 1
                    row.transform = .identity
                },
                completion: { [weak self] _ in
                    guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                    Haptics.light()
                }
            )
        }

        // 5. Hold the finished state so the viewer can read the list.
        let listDoneTime = listStart + Double(listRows.count) * 0.12 + 0.5
        let holdDuration: TimeInterval = 6.0
        let exitStart = listDoneTime + holdDuration

        // 6. Clean exit — card fades + scales down so the next cycle can reset.
        DispatchQueue.main.asyncAfter(deadline: .now() + exitStart) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            UIView.animate(
                withDuration: 0.6,
                delay: 0,
                options: [.curveEaseIn, .allowUserInteraction],
                animations: {
                    self.noteCard.alpha = 0
                    self.noteCard.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
                    for row in self.listRows { row.alpha = 0 }
                }
            )
        }

        // 7. Loop
        let totalDuration = exitStart + 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.playEntrance()
        }
    }

    func stopAnimations() {
        isStopped = true
        for label in noiseLabels { label.layer.removeAllAnimations() }
        for row in listRows { row.layer.removeAllAnimations() }
        noteCard.layer.removeAllAnimations()
    }

    // MARK: - Reset

    private func resetState() {
        for (i, label) in noiseLabels.enumerated() {
            label.layer.removeAllAnimations()
            label.alpha = 0
            label.transform = .identity
            if i < noiseHomes.count {
                label.center = noiseHomes[i]
            }
        }
        for row in listRows {
            row.layer.removeAllAnimations()
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 6)
        }
        noteCard.layer.removeAllAnimations()
        noteCard.alpha = 0
        noteCard.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        borderTraceLayer.removeAllAnimations()
        borderTraceLayer.strokeEnd = 0
    }
}

// MARK: - Seeded RNG

/// Simple deterministic PRNG so the noise cloud layout stays stable across cycles.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
