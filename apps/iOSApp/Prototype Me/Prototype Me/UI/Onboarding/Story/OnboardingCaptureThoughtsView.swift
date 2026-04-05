import UIKit

/// Capture demo: ghost "thought fragments" drift in around the edges, then
/// one by one fly into a central note card and become solid list items.
/// Conveys "write it down so you don't have to hold it in your head."
final class OnboardingCaptureThoughtsView: UIView, StoryAnimatable {

    private let noteCard = UIView()
    private let noteHeader = UILabel()
    private let noteStack = UIStackView()

    private var ghostLabels: [UILabel] = []
    private var listRows: [UIView] = []

    private var hasBuilt = false
    private var isStopped = false
    private var cycleID = 0

    private let observations: [String] = [
        "5am was tough",
        "stretching helped",
        "skipped lunch again",
        "no screens after 9 worked",
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
    }

    // MARK: - Build

    private func buildLayout() {
        buildNoteCard()
        buildGhostLabels()
        buildListRows()
    }

    private func buildNoteCard() {
        let accent = DesignTokens.Colors.accent
        noteCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        noteCard.layer.cornerRadius = DesignTokens.Radii.lg
        noteCard.layer.borderWidth = 1
        noteCard.layer.borderColor = accent.withAlphaComponent(0.35).cgColor
        noteCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(noteCard)

        noteHeader.text = "TODAY"
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

    private func buildGhostLabels() {
        // Ghost thought fragments scattered around the card — they drift, then
        // fly into the note card one by one. Positions are relative offsets from
        // center, tuned to sit outside the note card.
        let positions: [(dx: CGFloat, dy: CGFloat)] = [
            (-0.42, -0.35),  // top-left
            (0.40,  -0.32),  // top-right
            (-0.38, 0.38),   // bottom-left
            (0.42,  0.35),   // bottom-right
        ]

        for (i, text) in observations.enumerated() {
            let label = UILabel()
            label.text = "\"\(text)\""
            label.font = UIFont.italicSystemFont(ofSize: 13)
            label.textColor = DesignTokens.Colors.textTertiary
            label.alpha = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)

            let pos = positions[i % positions.count]
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor, constant: bounds.width * pos.dx),
                label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: bounds.height * pos.dy),
            ])
            ghostLabels.append(label)
        }
    }

    private func buildListRows() {
        let accent = DesignTokens.Colors.accent
        for text in observations {
            let row = UIView()
            row.alpha = 0
            row.translatesAutoresizingMaskIntoConstraints = false

            let bullet = UIView()
            bullet.backgroundColor = accent
            bullet.layer.cornerRadius = 2.5
            bullet.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = text
            label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
            label.textColor = DesignTokens.Colors.textPrimary
            label.numberOfLines = 1

            let rowStack = UIStackView(arrangedSubviews: [bullet, label, UIView()])
            rowStack.axis = .horizontal
            rowStack.spacing = DesignTokens.Spacing.sm
            rowStack.alignment = .center
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(rowStack)

            NSLayoutConstraint.activate([
                bullet.widthAnchor.constraint(equalToConstant: 5),
                bullet.heightAnchor.constraint(equalToConstant: 5),
                rowStack.topAnchor.constraint(equalTo: row.topAnchor),
                rowStack.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            ])
            noteStack.addArrangedSubview(row)
            listRows.append(row)
        }
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false
        cycleID += 1
        let currentCycle = cycleID
        resetState()

        guard !UIAccessibility.isReduceMotionEnabled else {
            for row in listRows { row.alpha = 1 }
            return
        }

        // 1. Ghost fragments fade in
        for (i, ghost) in ghostLabels.enumerated() {
            UIView.animate(withDuration: 0.5, delay: 0.2 + Double(i) * 0.1, options: .curveEaseOut) {
                ghost.alpha = 0.7
            }
            // Gentle drift
            UIView.animate(withDuration: 2.0, delay: 0.7 + Double(i) * 0.1, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
                ghost.transform = CGAffineTransform(translationX: 0, y: -4)
            }
        }

        // 2. Capture each ghost into the note card
        for (i, ghost) in ghostLabels.enumerated() {
            let delay = 0.9 + Double(i) * 0.8
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
                self.captureGhost(at: i, cycle: currentCycle)
            }
        }

        // 3. Loop
        let totalDuration = 0.9 + Double(ghostLabels.count) * 0.8 + 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            guard let self, !self.isStopped, self.cycleID == currentCycle else { return }
            self.playEntrance()
        }
    }

    private func captureGhost(at index: Int, cycle: Int) {
        guard index < ghostLabels.count, index < listRows.count else { return }
        let ghost = ghostLabels[index]
        let row = listRows[index]

        // Stop the drift
        ghost.layer.removeAllAnimations()

        // Calculate the destination: center of the target list row, converted to self coords
        layoutIfNeeded()
        let targetPoint = row.convert(CGPoint(x: row.bounds.width / 2, y: row.bounds.height / 2), to: self)
        let currentPoint = ghost.convert(CGPoint(x: ghost.bounds.width / 2, y: ghost.bounds.height / 2), to: self)
        let dx = targetPoint.x - currentPoint.x
        let dy = targetPoint.y - currentPoint.y

        // Fly the ghost into the note card while shrinking + fading
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.3, options: .curveEaseIn, animations: {
            ghost.transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: 0.6, y: 0.6)
            ghost.alpha = 0
        }, completion: { _ in
            // Reveal the list row
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3) {
                row.alpha = 1
            }
            Haptics.light()
        })
    }

    func stopAnimations() {
        isStopped = true
        for ghost in ghostLabels {
            ghost.layer.removeAllAnimations()
        }
        for row in listRows {
            row.layer.removeAllAnimations()
        }
        noteCard.layer.removeAllAnimations()
    }

    // MARK: - Reset

    private func resetState() {
        for ghost in ghostLabels {
            ghost.layer.removeAllAnimations()
            ghost.alpha = 0
            ghost.transform = .identity
        }
        for row in listRows {
            row.layer.removeAllAnimations()
            row.alpha = 0
        }
    }
}
