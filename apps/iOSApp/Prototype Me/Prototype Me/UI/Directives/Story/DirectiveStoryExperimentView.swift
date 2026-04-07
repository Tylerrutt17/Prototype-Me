import UIKit

/// Page 1 visual: tells the full story of a directive's lifecycle —
/// problem picker → thought → create directive → test → tweak → narration about replacing.
final class DirectiveStoryExperimentView: UIView, StoryAnimatable {

    // MARK: - Content

    /// Problems that cycle through the wheel before landing on the final one.
    private let problems = [
        "I never drink enough water…",
        "I keep putting things off…",
        "I'm always tired after lunch…",
        "I can't stick to a routine…",
        "I scroll my phone too much…",
        "I can't focus at work…",
        "I skip the gym too often…",
        "I can't fall asleep at night…",
    ]

    private let pickerPrompt = "Start with something you want to fix…"

    private struct Stage {
        let title: String
        let body: String
        let colorHex: String
    }

    private let firstDirective = Stage(
        title: "No screens after 9pm",
        body: "Put the phone away and let your brain wind down.",
        colorHex: "#5E5CE6"
    )

    private let tweakedDirective = Stage(
        title: "No screens after 10pm",
        body: "Adjusted — 10pm feels more realistic.",
        colorHex: "#5E5CE6"
    )

    // MARK: - Timeline

    private let cycleDuration: TimeInterval = 24.0

    private let milestones: [(position: CGFloat, label: String)] = [
        (0.08, "Problem"),
        (0.29, "Try It"),
        (0.50, "Tweak It"),
        (0.79, "Evolve"),
    ]

    // MARK: - UI

    private let promptLabel = UILabel()
    private let pickerContainer = UIView()
    fileprivate var pickerLabels: [UILabel] = []
    private let cardContainer = UIView()
    private let narrationLabel = UILabel()
    private var card: UIView!
    private var titleLabel: UILabel!
    private var bodyLabel: UILabel!
    private var hasPlayed = false
    private var isStopped = false

    private let timelineTrack = UIView()
    private let timelineFill = UIView()
    private var timelineFillWidth: NSLayoutConstraint!
    private var milestoneDots: [UIView] = []
    private var milestoneLabels: [UILabel] = []
    private var progressLink: CADisplayLink?
    private var sequenceStartTime: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    private func buildLayout() {
        // Prompt label above the picker
        promptLabel.text = pickerPrompt
        promptLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        promptLabel.textColor = DesignTokens.Colors.textTertiary
        promptLabel.textAlignment = .center
        promptLabel.alpha = 0
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(promptLabel)

        // Picker area (3D wheel)
        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pickerContainer)

        // Card container (same position, hidden initially)
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardContainer)

        // Narration label (below card area)
        narrationLabel.text = "You can also remove directives entirely,\nor replace them with completely new ones."
        narrationLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        narrationLabel.textColor = DesignTokens.Colors.textSecondary
        narrationLabel.textAlignment = .center
        narrationLabel.numberOfLines = 0
        narrationLabel.alpha = 0
        narrationLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(narrationLabel)

        buildTimeline()

        NSLayoutConstraint.activate([
            promptLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            promptLabel.bottomAnchor.constraint(equalTo: pickerContainer.topAnchor, constant: -DesignTokens.Spacing.md),

            pickerContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            pickerContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            pickerContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            pickerContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            pickerContainer.heightAnchor.constraint(equalToConstant: 140),

            cardContainer.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),

            narrationLabel.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: DesignTokens.Spacing.xl),
            narrationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            narrationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])

        // Build initial card (hidden)
        card = makeCard(for: firstDirective, trackLabels: true)
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.95, y: 0.95)
        cardContainer.addSubview(card)
        pinCard(card)
    }

    // MARK: - 3D Wheel Picker

    /// Builds labels for the wheel and sets initial 3D transforms.
    private func buildPickerLabels() {
        pickerLabels.forEach { $0.removeFromSuperview() }
        pickerLabels.removeAll()

        for text in problems {
            let label = UILabel()
            label.text = text
            label.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
            label.textColor = DesignTokens.Colors.textPrimary
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            pickerContainer.addSubview(label)
            pickerLabels.append(label)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: pickerContainer.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: pickerContainer.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: pickerContainer.leadingAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: pickerContainer.trailingAnchor),
            ])
        }
    }

    /// Applies 3D cylinder transforms based on which index is "centered."
    fileprivate func applyWheelTransform(centeredIndex: CGFloat) {
        let radius: CGFloat = 60
        let anglePerItem: CGFloat = .pi / 6  // 30° between items

        for (i, label) in pickerLabels.enumerated() {
            let offset = CGFloat(i) - centeredIndex
            let angle = offset * anglePerItem

            // Items too far away are hidden
            if abs(offset) > 2.5 {
                label.alpha = 0
                continue
            }

            var t = CATransform3DIdentity
            t.m34 = -1.0 / 400  // perspective
            t = CATransform3DTranslate(t, 0, radius * sin(angle), radius * (1 - cos(angle)))
            t = CATransform3DRotate(t, -angle, 1, 0, 0)

            label.layer.transform = t
            label.alpha = max(0, 1.0 - abs(offset) * 0.45)
        }
    }

    /// Runs the wheel animation: scrolls through items, decelerates, lands on the last one.
    private func runPicker(completion: @escaping () -> Void) {
        buildPickerLabels()
        pickerContainer.alpha = 1
        applyWheelTransform(centeredIndex: -1)

        // Fade in prompt + picker
        UIView.animate(withDuration: 0.4) {
            self.promptLabel.alpha = 1
        }

        let finalIndex = problems.count - 1

        let startTime = CACurrentMediaTime()
        let animator = WheelAnimator(
            view: self,
            startTime: startTime,
            duration: 3.0,
            from: -1,
            to: CGFloat(finalIndex),
            finalIndex: CGFloat(finalIndex)
        ) { [weak self] in
            guard let self else { return }
            if let finalLabel = self.pickerLabels[safe: finalIndex] {
                UIView.animate(withDuration: 0.3) {
                    finalLabel.textColor = DesignTokens.Colors.accent
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion()
            }
        }
        let displayLink = CADisplayLink(target: animator, selector: #selector(WheelAnimator.tick))
        displayLink.add(to: .main, forMode: .common)
    }

    private func fadePicker() {
        UIView.animate(withDuration: 0.35) {
            self.pickerContainer.alpha = 0
            self.promptLabel.alpha = 0
        } completion: { _ in
            self.pickerLabels.forEach { $0.removeFromSuperview() }
            self.pickerLabels.removeAll()
        }
    }

    // MARK: - Card Builder (mirrors DirectiveCell layout)

    private func makeCard(for stage: Stage, trackLabels: Bool = false) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = DesignTokens.Colors.surfacePrimary
        wrapper.layer.cornerRadius = DesignTokens.Radii.md
        wrapper.clipsToBounds = true
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let colorBar = UIView()
        colorBar.backgroundColor = UIColor(hex: stage.colorHex) ?? .systemPurple
        colorBar.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(colorBar)

        let title = UILabel()
        title.text = stage.title
        title.font = DesignTokens.Typography.headline
        title.textColor = DesignTokens.Colors.textPrimary
        title.numberOfLines = 0
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: chevronConfig))
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let titleRow = UIStackView(arrangedSubviews: [title, chevron])
        titleRow.axis = .horizontal
        titleRow.spacing = DesignTokens.Spacing.sm
        titleRow.alignment = .center

        let body = UILabel()
        body.text = stage.body
        body.font = DesignTokens.Typography.caption1
        body.textColor = DesignTokens.Colors.textSecondary
        body.numberOfLines = 2

        let contentStack = UIStackView(arrangedSubviews: [titleRow, body])
        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.xs
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(contentStack)

        if trackLabels {
            titleLabel = title
            bodyLabel = body
        }

        NSLayoutConstraint.activate([
            colorBar.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: wrapper.topAnchor),
            colorBar.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 4),

            contentStack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: DesignTokens.Spacing.md),
            contentStack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -DesignTokens.Spacing.md),
            contentStack.leadingAnchor.constraint(equalTo: colorBar.trailingAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return wrapper
    }

    private func pinCard(_ cardView: UIView) {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
        ])
    }

    // MARK: - Timeline

    private func buildTimeline() {
        let trackHeight: CGFloat = 3
        let dotSize: CGFloat = 10

        timelineTrack.backgroundColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.2)
        timelineTrack.layer.cornerRadius = trackHeight / 2
        timelineTrack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timelineTrack)

        timelineFill.backgroundColor = DesignTokens.Colors.accent
        timelineFill.layer.cornerRadius = trackHeight / 2
        timelineFill.translatesAutoresizingMaskIntoConstraints = false
        timelineTrack.addSubview(timelineFill)
        timelineFillWidth = timelineFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            timelineTrack.topAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: DesignTokens.Spacing.xxxl + 30),
            timelineTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            timelineTrack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
            timelineTrack.heightAnchor.constraint(equalToConstant: trackHeight),

            timelineFill.leadingAnchor.constraint(equalTo: timelineTrack.leadingAnchor),
            timelineFill.topAnchor.constraint(equalTo: timelineTrack.topAnchor),
            timelineFill.bottomAnchor.constraint(equalTo: timelineTrack.bottomAnchor),
            timelineFillWidth,
        ])

        for milestone in milestones {
            let dot = UIView()
            dot.backgroundColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.4)
            dot.layer.cornerRadius = dotSize / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            addSubview(dot)
            milestoneDots.append(dot)

            let label = UILabel()
            label.text = milestone.label
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
            label.textColor = DesignTokens.Colors.textTertiary
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            milestoneLabels.append(label)

            let guide = UILayoutGuide()
            timelineTrack.addLayoutGuide(guide)

            NSLayoutConstraint.activate([
                guide.leadingAnchor.constraint(equalTo: timelineTrack.leadingAnchor),
                guide.widthAnchor.constraint(equalTo: timelineTrack.widthAnchor, multiplier: milestone.position),

                dot.centerYAnchor.constraint(equalTo: timelineTrack.centerYAnchor),
                dot.centerXAnchor.constraint(equalTo: guide.trailingAnchor),
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize),

                label.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                label.topAnchor.constraint(equalTo: timelineTrack.bottomAnchor, constant: DesignTokens.Spacing.sm),
            ])
        }

        timelineTrack.alpha = 0
        for dot in milestoneDots { dot.alpha = 0 }
        for lbl in milestoneLabels { lbl.alpha = 0 }
    }

    private func startProgress() {
        sequenceStartTime = CACurrentMediaTime()
        timelineFillWidth.constant = 0

        UIView.animate(withDuration: 0.4) {
            self.timelineTrack.alpha = 1
            for dot in self.milestoneDots { dot.alpha = 1 }
            for lbl in self.milestoneLabels { lbl.alpha = 1 }
        }

        for dot in milestoneDots {
            dot.backgroundColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.4)
            dot.transform = .identity
        }
        for lbl in milestoneLabels {
            lbl.textColor = DesignTokens.Colors.textTertiary
        }

        progressLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(updateProgress))
        link.add(to: .main, forMode: .common)
        progressLink = link
    }

    @objc private func updateProgress() {
        let elapsed = CACurrentMediaTime() - sequenceStartTime
        let progress = min(CGFloat(elapsed / cycleDuration), 1.0)
        let trackWidth = timelineTrack.bounds.width
        guard trackWidth > 0 else { return }

        timelineFillWidth.constant = trackWidth * progress

        for (i, milestone) in milestones.enumerated() {
            if progress >= milestone.position {
                let dot = milestoneDots[i]
                if dot.backgroundColor != DesignTokens.Colors.accent {
                    UIView.animate(withDuration: 0.3) {
                        dot.backgroundColor = DesignTokens.Colors.accent
                        self.milestoneLabels[i].textColor = DesignTokens.Colors.textSecondary
                    }
                    UIView.animate(
                        withDuration: 0.3,
                        delay: 0,
                        usingSpringWithDamping: 0.5,
                        initialSpringVelocity: 0.8
                    ) {
                        dot.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                    } completion: { _ in
                        UIView.animate(withDuration: 0.2) {
                            dot.transform = .identity
                        }
                    }
                }
            }
        }

        if progress >= 1.0 {
            progressLink?.invalidate()
            progressLink = nil
        }
    }

    private func fadeOutTimeline() {
        progressLink?.invalidate()
        progressLink = nil
        UIView.animate(withDuration: 0.4) {
            self.timelineTrack.alpha = 0
            for dot in self.milestoneDots { dot.alpha = 0 }
            for lbl in self.milestoneLabels { lbl.alpha = 0 }
        }
    }

    // MARK: - Thought Bubble

    private func showBubble(_ text: String, icon: String, color: UIColor, duration: TimeInterval = 2.5) {
        let bubble = UIView()
        bubble.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bubble)

        let bg = UIView()
        bg.backgroundColor = color.withAlphaComponent(0.15)
        bg.layer.cornerRadius = 16
        bg.layer.borderWidth = 1
        bg.layer.borderColor = color.withAlphaComponent(0.3).cgColor
        bg.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(bg)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .footnote, weight: .bold)
        label.textColor = color

        let row = UIStackView(arrangedSubviews: [iconView, label])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(row)

        let tail = TriangleTailView(color: color.withAlphaComponent(0.15), borderColor: color.withAlphaComponent(0.3))
        tail.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(tail)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: bg.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -12),

            bg.topAnchor.constraint(equalTo: bubble.topAnchor),
            bg.centerXAnchor.constraint(equalTo: bubble.centerXAnchor),

            tail.topAnchor.constraint(equalTo: bg.bottomAnchor, constant: -1),
            tail.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            tail.widthAnchor.constraint(equalToConstant: 14),
            tail.heightAnchor.constraint(equalToConstant: 8),
            tail.bottomAnchor.constraint(equalTo: bubble.bottomAnchor),

            bubble.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            bubble.bottomAnchor.constraint(equalTo: cardContainer.topAnchor, constant: -10),
        ])

        bubble.alpha = 0
        bubble.transform = CGAffineTransform(scaleX: 0.3, y: 0.3).translatedBy(x: 0, y: 12)

        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.8
        ) {
            bubble.alpha = 1
            bubble.transform = .identity
        }

        UIView.animate(
            withDuration: 0.45,
            delay: duration,
            options: .curveEaseIn
        ) {
            bubble.alpha = 0
            bubble.transform = CGAffineTransform(translationX: 0, y: -8)
        } completion: { _ in
            bubble.removeFromSuperview()
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !hasPlayed else { return }
        hasPlayed = true
        isStopped = false

        guard !UIAccessibility.isReduceMotionEnabled else {
            card.alpha = 1
            card.transform = .identity
            return
        }

        runSequence()
    }

    // MARK: - Sequence

    /// problem picker → thought → create → test → tweak → narration → loop
    private func runSequence() {
        guard !isStopped else { return }

        startProgress()
        narrationLabel.alpha = 0

        // Phase 1 (0s): Problem picker spins through issues
        layoutIfNeeded()
        runPicker { [weak self] in
            guard let self, !self.isStopped else { return }

            // Phase 2 (~3.5s): Thought bubble — what should I do about this?
            self.showBubble("How can I wind down better?", icon: "lightbulb.fill", color: .systemYellow, duration: 3.0)

            // Phase 3 (~6.5s): Fade picker, directive card slides in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.fadePicker()
                UIView.animate(
                    withDuration: 0.6,
                    delay: 0.2,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.3
                ) {
                    self.card.alpha = 1
                    self.card.transform = .identity
                }
            }

            // Phase 4 (~10s): Testing bubble
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.showBubble("Let's test this out…", icon: "checkmark.circle.fill", color: .systemGreen, duration: 2.5)
            }

            // Phase 5 (~13s): Tweak bubble
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.5) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.showBubble("Hmm, maybe I can adjust this…", icon: "pencil.circle.fill", color: .systemCyan, duration: 2.5)
            }

            // Phase 6 (~15.5s): Text edits in-place
            DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.editTextInPlace()
            }

            // Phase 7 (~17s): Narration fades in
            DispatchQueue.main.asyncAfter(deadline: .now() + 14.5) { [weak self] in
                guard let self, !self.isStopped else { return }
                UIView.animate(withDuration: 0.6) {
                    self.narrationLabel.alpha = 1
                }
            }

            // Phase 8 (~21s): Fade everything out and reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 20.5) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.fadeOutAndReset()
            }
        }
    }

    /// Edits the title and body labels in-place with a highlight flash.
    private func editTextInPlace() {
        let next = tweakedDirective

        let flash = UIView()
        flash.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        flash.frame = card.bounds
        flash.layer.cornerRadius = DesignTokens.Radii.md
        flash.alpha = 0
        card.addSubview(flash)

        UIView.animateKeyframes(withDuration: 1.0, delay: 0) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2) {
                flash.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 0.15, relativeDuration: 0.35) {
                self.titleLabel.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.01) {
                self.titleLabel.text = next.title
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.35) {
                self.titleLabel.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.3) {
                self.bodyLabel.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.01) {
                self.bodyLabel.text = next.body
            }
            UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.35) {
                self.bodyLabel.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                flash.alpha = 0
            }
        } completion: { _ in
            flash.removeFromSuperview()
        }

        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.3
        ) {
            self.card.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.2
            ) {
                self.card.transform = .identity
            }
        }
    }

    /// Fades everything out, resets state, and loops.
    private func fadeOutAndReset() {
        guard !isStopped else { return }

        fadeOutTimeline()

        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn) {
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.narrationLabel.alpha = 0
        } completion: { [weak self] _ in
            guard let self, !self.isStopped else { return }

            self.card.removeFromSuperview()

            let freshCard = self.makeCard(for: self.firstDirective, trackLabels: true)
            freshCard.alpha = 0
            freshCard.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.95, y: 0.95)
            self.cardContainer.addSubview(freshCard)
            self.pinCard(freshCard)
            self.card = freshCard

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard !self.isStopped else { return }
                self.runSequence()
            }
        }
    }

    func stopAnimations() {
        isStopped = true
        progressLink?.invalidate()
        progressLink = nil
        card?.layer.removeAllAnimations()
    }
}

// MARK: - Wheel Animator (CADisplayLink target)

private final class WheelAnimator: NSObject {
    private weak var view: DirectiveStoryExperimentView?
    private let startTime: CFTimeInterval
    private let duration: TimeInterval
    private let from: CGFloat
    private let to: CGFloat
    private let finalIndex: CGFloat
    private let completion: () -> Void

    init(view: DirectiveStoryExperimentView, startTime: CFTimeInterval, duration: TimeInterval,
         from: CGFloat, to: CGFloat, finalIndex: CGFloat, completion: @escaping () -> Void) {
        self.view = view
        self.startTime = startTime
        self.duration = duration
        self.from = from
        self.to = to
        self.finalIndex = finalIndex
        self.completion = completion
    }

    @objc func tick(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - startTime
        var t = min(CGFloat(elapsed / duration), 1.0)

        // Ease-out curve (decelerate toward the end)
        t = 1 - pow(1 - t, 3)

        let current = from + (to - from) * t
        view?.applyWheelTransform(centeredIndex: current)

        if t >= 1.0 {
            link.invalidate()
            view?.applyWheelTransform(centeredIndex: finalIndex)
            completion()
        }
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Triangle Tail

private final class TriangleTailView: UIView {
    private let fillColor: UIColor
    private let borderColor: UIColor

    init(color: UIColor, borderColor: UIColor) {
        self.fillColor = color
        self.borderColor = borderColor
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.close()

        fillColor.setFill()
        path.fill()

        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
