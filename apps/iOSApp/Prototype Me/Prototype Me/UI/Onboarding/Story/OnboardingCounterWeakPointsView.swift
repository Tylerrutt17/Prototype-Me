import UIKit

/// Bridge visual: starts as the two-column weak-points list (same layout as
/// OnboardingShortcomingsView), then cross-fades into the two vertical mode
/// cards (same layout as OnboardingSystemEvolvesView). The swap is the aha
/// moment — the situational stuff clusters into modes.
final class OnboardingCounterWeakPointsView: UIView, StoryAnimatable {

    private let columnsContainer = UIView()
    private let cardsContainer = UIView()
    private var generalPills: [UIView] = []
    private var situationalPills: [UIView] = []
    private var modeCards: [UIView] = []
    private var isStopped = false

    var prefersFullWidth: Bool { true }

    private let generalProblems: [(text: String, icon: String)] = [
        ("I wake up with no energy", "brain.head.profile"),
        ("asdf", "face.smiling"),
        ("Trouble falling asleep", "sunrise.fill"),
    ]

    private let situationalProblems: [(text: String, icon: String)] = [
        ("Eyes get strained at work", "eye"),
        ("Trouble being consistent with gym", "bolt.slash.fill"),
        ("I sit too long when working", "figure.stand"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Build

    private func buildLayout() {
        columnsContainer.translatesAutoresizingMaskIntoConstraints = false
        cardsContainer.translatesAutoresizingMaskIntoConstraints = false
        cardsContainer.alpha = 0
        addSubview(columnsContainer)
        addSubview(cardsContainer)

        NSLayoutConstraint.activate([
            columnsContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            columnsContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            columnsContainer.centerYAnchor.constraint(equalTo: centerYAnchor),

            cardsContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardsContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardsContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        buildColumns()
        buildCards()
    }

    private func buildColumns() {
        let columnsStack = UIStackView()
        columnsStack.axis = .horizontal
        columnsStack.spacing = DesignTokens.Spacing.md
        columnsStack.distribution = .fillEqually
        columnsStack.alignment = .top
        columnsStack.translatesAutoresizingMaskIntoConstraints = false
        columnsContainer.addSubview(columnsStack)

        NSLayoutConstraint.activate([
            columnsStack.topAnchor.constraint(equalTo: columnsContainer.topAnchor),
            columnsStack.bottomAnchor.constraint(equalTo: columnsContainer.bottomAnchor),
            columnsStack.leadingAnchor.constraint(equalTo: columnsContainer.leadingAnchor, constant: DesignTokens.Spacing.lg),
            columnsStack.trailingAnchor.constraint(equalTo: columnsContainer.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        let fwColor = NoteKind.framework.color
        let modeColor = NoteKind.mode.color

        let generalColumn = makeColumn(
            headerText: "GENERALLY",
            headerIcon: "star.fill",
            headerColor: fwColor,
            problems: generalProblems,
            pillColor: fwColor,
            pillsOut: &generalPills
        )
        columnsStack.addArrangedSubview(generalColumn)

        let situationalColumn = makeColumn(
            headerText: "SITUATIONAL",
            headerIcon: "bolt.fill",
            headerColor: modeColor,
            problems: situationalProblems,
            pillColor: modeColor,
            pillsOut: &situationalPills
        )
        columnsStack.addArrangedSubview(situationalColumn)
    }

    private func buildCards() {
        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = DesignTokens.Spacing.sm
        cardsStack.distribution = .fill
        cardsStack.translatesAutoresizingMaskIntoConstraints = false
        cardsContainer.addSubview(cardsStack)

        NSLayoutConstraint.activate([
            cardsStack.topAnchor.constraint(equalTo: cardsContainer.topAnchor),
            cardsStack.bottomAnchor.constraint(equalTo: cardsContainer.bottomAnchor),
            cardsStack.leadingAnchor.constraint(equalTo: cardsContainer.leadingAnchor, constant: DesignTokens.Spacing.lg),
            cardsStack.trailingAnchor.constraint(equalTo: cardsContainer.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        let modeColor = NoteKind.mode.color

        let mode1 = UIView()
        buildNoteCard(
            mode1,
            icon: "bolt.fill",
            title: "Computer Work - MODE",
            note: "Eyes burning, back sore by afternoon",
            color: modeColor,
            directives: ["Rest my eyes more", "Stretch when I can"]
        )
        cardsStack.addArrangedSubview(mode1)
        modeCards.append(mode1)

        let mode2 = UIView()
        buildNoteCard(
            mode2,
            icon: "bolt.fill",
            title: "Winding Down - MODE",
            note: "Can't switch off, scrolling till late",
            color: modeColor,
            directives: ["Try to relax", "Put my phone down"]
        )
        cardsStack.addArrangedSubview(mode2)
        modeCards.append(mode2)
    }

    private func makeColumn(
        headerText: String,
        headerIcon: String,
        headerColor: UIColor,
        problems: [(text: String, icon: String)],
        pillColor: UIColor,
        pillsOut: inout [UIView]
    ) -> UIView {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: headerIcon, withConfiguration: iconConfig))
        iconView.tintColor = headerColor
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let headerLabel = UILabel()
        headerLabel.text = headerText
        headerLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        headerLabel.textColor = headerColor

        let headerRow = UIStackView(arrangedSubviews: [iconView, headerLabel, UIView()])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.xs
        headerRow.alignment = .center

        let pillStack = UIStackView()
        pillStack.axis = .vertical
        pillStack.spacing = DesignTokens.Spacing.xs
        pillStack.alignment = .fill

        for problem in problems {
            let pill = makePill(text: problem.text, icon: problem.icon, color: pillColor)
            pill.alpha = 0
            pill.transform = CGAffineTransform(translationX: 0, y: 12)
            pillStack.addArrangedSubview(pill)
            pillsOut.append(pill)
        }

        let column = UIStackView(arrangedSubviews: [headerRow, pillStack])
        column.axis = .vertical
        column.spacing = DesignTokens.Spacing.sm
        return column
    }

    private func makePill(text: String, icon: String, color: UIColor) -> UIView {
        let pill = UIView()
        pill.backgroundColor = color.withAlphaComponent(0.08)
        pill.layer.cornerRadius = DesignTokens.Radii.sm
        pill.layer.borderWidth = 1
        pill.layer.borderColor = color.withAlphaComponent(0.25).cgColor

        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        label.textColor = color
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(stack)

        let pad = DesignTokens.Spacing.sm
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            stack.topAnchor.constraint(equalTo: pill.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -pad),
        ])

        return pill
    }

    private func buildNoteCard(
        _ card: UIView,
        icon: String,
        title: String,
        note: String?,
        color: UIColor,
        directives: [String]
    ) {
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let bar = UIView()
        bar.backgroundColor = color
        bar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bar)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 14).isActive = true
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold)
        titleLabel.textColor = color
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView()])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.xs
        headerRow.alignment = .center

        var cardSubviews: [UIView] = [headerRow]

        if let note = note {
            let noteLabel = UILabel()
            noteLabel.text = "Reason — \(note)"
            noteLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .regular)
            noteLabel.textColor = DesignTokens.Colors.textTertiary
            noteLabel.numberOfLines = 0
            cardSubviews.append(noteLabel)
        }

        let dirStack = UIStackView()
        dirStack.axis = .vertical
        dirStack.spacing = 4

        for text in directives {
            let label = UILabel()
            label.text = text
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
            label.textColor = DesignTokens.Colors.textPrimary
            dirStack.addArrangedSubview(label)
        }
        cardSubviews.append(dirStack)

        let cardStack = UIStackView(arrangedSubviews: cardSubviews)
        cardStack.axis = .vertical
        cardStack.spacing = DesignTokens.Spacing.sm
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: card.topAnchor),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 3),

            cardStack.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: pad),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
        ])
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false

        // Reset state
        columnsContainer.alpha = 1
        cardsContainer.alpha = 0
        for pill in generalPills + situationalPills {
            pill.alpha = 0
            pill.transform = CGAffineTransform(translationX: 0, y: 12)
        }
        for card in modeCards {
            card.alpha = 0
            card.transform = CGAffineTransform(translationX: 0, y: 10)
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            for pill in generalPills + situationalPills { pill.alpha = 1; pill.transform = .identity }
            for card in modeCards { card.alpha = 1; card.transform = .identity }
            columnsContainer.alpha = 0
            cardsContainer.alpha = 1
            return
        }

        // Phase 1 — pills spring in
        for (i, pill) in generalPills.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: 0.15 + Double(i) * 0.18,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                pill.alpha = 1
                pill.transform = .identity
            }
        }
        let situationalStart = 0.15 + Double(generalPills.count) * 0.18 + 0.12
        for (i, pill) in situationalPills.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: situationalStart + Double(i) * 0.18,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                pill.alpha = 1
                pill.transform = .identity
            }
        }

        // Phase 2 — cross-fade to mode cards after pills settle
        let pillsDoneAt = situationalStart + Double(situationalPills.count) * 0.18 + 0.4
        let holdDuration = 1.6
        let crossfadeAt = pillsDoneAt + holdDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeAt) { [weak self] in
            guard let self, !self.isStopped else { return }
            UIView.animate(withDuration: 0.45, delay: 0, options: .curveEaseInOut) {
                self.columnsContainer.alpha = 0
            }
            for (i, card) in self.modeCards.enumerated() {
                UIView.animate(
                    withDuration: 0.5,
                    delay: 0.15 + Double(i) * 0.12,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.3
                ) {
                    self.cardsContainer.alpha = 1
                    card.alpha = 1
                    card.transform = .identity
                }
            }
        }
    }

    func stopAnimations() {
        isStopped = true
        for pill in generalPills + situationalPills { pill.layer.removeAllAnimations() }
        for card in modeCards { card.layer.removeAllAnimations() }
        columnsContainer.layer.removeAllAnimations()
        cardsContainer.layer.removeAllAnimations()
    }
}
