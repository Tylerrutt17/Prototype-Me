import UIKit

/// Onboarding screen: Animated calendar grid with a mini-editor overlay.
/// Shows pre-filled days, then demos the entry flow: tap day → editor slides up →
/// rating selected → journal typed → save → dot fills on calendar. Loops.
final class OnboardingJournalDemoView: UIView, StoryAnimatable {

    private let containerView = UIView()
    private let editorCard = UIView()
    private var dayCells: [DayCell] = []
    private var hasBuilt = false
    private var isStopped = false

    // Editor subviews
    private let editorDateLabel = UILabel()
    private let editorRatingHeader = UILabel()
    private var editorRatingButtons: [UIView] = []
    private let editorJournalHeader = UILabel()
    private let editorJournalField = UIView()
    private let editorJournalText = UILabel()
    private let editorSaveButton = UIView()
    private let editorSaveLabel = UILabel()

    // Pre-filled calendar data
    private let mockRatings: [Int?] = [
        nil,  4,   3,   5,   6,   nil, nil,
        6,    7,   8,   7,   8,   9,   nil,
        8,    9,   5,   4,   6,   7,   8,
        7,    8,   9,   8,   9,   9,   nil,
        8,    nil, nil, nil, nil, nil, nil,
    ]

    // Demo entries: (dayIndex, rating, date text, journal text to "type")
    private let demoEntries: [(dayIndex: Int, rating: Int, date: String, diary: String)] = [
        (29, 9, "Tue, Mar 30", "Crushed it today. Morning routine was on point."),
        (30, 7, "Wed, Mar 31", "Solid day. Could have been more focused."),
    ]
    private var demoStep = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildCalendar()
            buildEditor()
        }
    }

    // MARK: - Build Calendar

    private func buildCalendar() {
        containerView.backgroundColor = DesignTokens.Colors.surfacePrimary
        containerView.layer.cornerRadius = DesignTokens.Radii.lg
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = DesignTokens.Colors.separator.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm),
        ])

        let monthLabel = UILabel()
        monthLabel.text = "March 2026"
        monthLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        monthLabel.textColor = DesignTokens.Colors.textPrimary
        monthLabel.textAlignment = .center
        monthLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(monthLabel)

        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .fillEqually
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        for day in ["M", "T", "W", "T", "F", "S", "S"] {
            let label = UILabel()
            label.text = day
            label.font = DesignTokens.Typography.caption2
            label.textColor = DesignTokens.Colors.textTertiary
            label.textAlignment = .center
            headerStack.addArrangedSubview(label)
        }
        containerView.addSubview(headerStack)

        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 4
        gridStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(gridStack)

        let padding = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            monthLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: padding),
            monthLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            monthLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            headerStack.topAnchor.constraint(equalTo: monthLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            gridStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: DesignTokens.Spacing.xs),
            gridStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: padding),
            gridStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -padding),
            gridStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -padding),
        ])

        var dayIndex = 0
        for _ in 0..<5 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 4
            for _ in 0..<7 {
                let rating = dayIndex < mockRatings.count ? mockRatings[dayIndex] : nil
                let dayNum = dayIndex + 1
                let cell = DayCell(dayNumber: dayNum <= 31 ? dayNum : nil, rating: rating)
                rowStack.addArrangedSubview(cell)
                cell.heightAnchor.constraint(equalToConstant: 40).isActive = true
                if dayNum <= 31 { dayCells.append(cell) }
                dayIndex += 1
            }
            gridStack.addArrangedSubview(rowStack)
        }

        containerView.alpha = 0
        containerView.transform = CGAffineTransform(translationX: 0, y: 20)
    }

    // MARK: - Build Mini Editor

    private func buildEditor() {
        editorCard.backgroundColor = DesignTokens.Colors.surfaceSecondary
        editorCard.layer.cornerRadius = DesignTokens.Radii.lg
        editorCard.layer.borderWidth = 1
        editorCard.layer.borderColor = DesignTokens.Colors.separator.cgColor
        editorCard.translatesAutoresizingMaskIntoConstraints = false
        editorCard.alpha = 0
        editorCard.transform = CGAffineTransform(translationX: 0, y: 40)
        addSubview(editorCard)

        // Date
        editorDateLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        editorDateLabel.textColor = DesignTokens.Colors.textPrimary

        // Rating header + buttons
        editorRatingHeader.text = "HOW WAS YOUR DAY?"
        editorRatingHeader.font = DesignTokens.Typography.caption1
        editorRatingHeader.textColor = DesignTokens.Colors.textSecondary

        let ratingStack = UIStackView()
        ratingStack.axis = .horizontal
        ratingStack.distribution = .fillEqually
        ratingStack.spacing = 3

        for i in 1...10 {
            let btn = UIView()
            btn.layer.cornerRadius = DesignTokens.Radii.sm
            btn.clipsToBounds = true
            let color = Self.editorRatingColor(for: i)
            btn.backgroundColor = color.withAlphaComponent(0.15)

            let label = UILabel()
            label.text = "\(i)"
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            label.textColor = color
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            btn.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            ])

            ratingStack.addArrangedSubview(btn)
            btn.heightAnchor.constraint(equalToConstant: 28).isActive = true
            editorRatingButtons.append(btn)
        }

        let ratingRow = UIStackView(arrangedSubviews: [editorRatingHeader, ratingStack])
        ratingRow.axis = .vertical
        ratingRow.spacing = DesignTokens.Spacing.xs

        // Journal header + field
        editorJournalHeader.text = "JOURNAL"
        editorJournalHeader.font = DesignTokens.Typography.caption1
        editorJournalHeader.textColor = DesignTokens.Colors.textSecondary

        editorJournalField.backgroundColor = DesignTokens.Colors.surfacePrimary
        editorJournalField.layer.cornerRadius = DesignTokens.Radii.md
        editorJournalField.layer.borderWidth = 1
        editorJournalField.layer.borderColor = DesignTokens.Colors.separator.cgColor

        editorJournalText.font = DesignTokens.Typography.caption1
        editorJournalText.textColor = DesignTokens.Colors.textPrimary
        editorJournalText.numberOfLines = 2
        editorJournalText.text = ""
        editorJournalText.translatesAutoresizingMaskIntoConstraints = false
        editorJournalField.addSubview(editorJournalText)

        NSLayoutConstraint.activate([
            editorJournalText.topAnchor.constraint(equalTo: editorJournalField.topAnchor, constant: DesignTokens.Spacing.sm),
            editorJournalText.leadingAnchor.constraint(equalTo: editorJournalField.leadingAnchor, constant: DesignTokens.Spacing.sm),
            editorJournalText.trailingAnchor.constraint(equalTo: editorJournalField.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            editorJournalText.bottomAnchor.constraint(equalTo: editorJournalField.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            editorJournalField.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])

        let journalRow = UIStackView(arrangedSubviews: [editorJournalHeader, editorJournalField])
        journalRow.axis = .vertical
        journalRow.spacing = DesignTokens.Spacing.xs

        // Save button
        editorSaveButton.backgroundColor = DesignTokens.Colors.accent
        editorSaveButton.layer.cornerRadius = DesignTokens.Radii.md

        editorSaveLabel.text = "Save Entry"
        editorSaveLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        editorSaveLabel.textColor = DesignTokens.Colors.textPrimary
        editorSaveLabel.textAlignment = .center
        editorSaveLabel.translatesAutoresizingMaskIntoConstraints = false
        editorSaveButton.addSubview(editorSaveLabel)

        NSLayoutConstraint.activate([
            editorSaveLabel.centerXAnchor.constraint(equalTo: editorSaveButton.centerXAnchor),
            editorSaveLabel.centerYAnchor.constraint(equalTo: editorSaveButton.centerYAnchor),
            editorSaveButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Main stack
        let mainStack = UIStackView(arrangedSubviews: [editorDateLabel, ratingRow, journalRow, editorSaveButton])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        editorCard.addSubview(mainStack)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            editorCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            editorCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.sm),
            editorCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.sm),

            mainStack.topAnchor.constraint(equalTo: editorCard.topAnchor, constant: pad),
            mainStack.leadingAnchor.constraint(equalTo: editorCard.leadingAnchor, constant: pad),
            mainStack.trailingAnchor.constraint(equalTo: editorCard.trailingAnchor, constant: -pad),
            mainStack.bottomAnchor.constraint(equalTo: editorCard.bottomAnchor, constant: -pad),
        ])
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        isStopped = false

        guard !UIAccessibility.isReduceMotionEnabled else {
            containerView.alpha = 1
            containerView.transform = .identity
            for cell in dayCells { cell.showRating() }
            return
        }

        // 1. Fade in calendar
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }

        // 2. Sweep in existing dots
        for (i, cell) in dayCells.enumerated() {
            guard cell.hasRating else { continue }
            let delay = 0.4 + Double(i) * 0.03
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                cell.showRating()
            }
        }

        // 3. Start demo loop after sweep
        let sweepDuration = 0.4 + Double(dayCells.count) * 0.03 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + sweepDuration) { [weak self] in
            self?.playDemoStep()
        }
    }

    func stopAnimations() {
        isStopped = true
        containerView.layer.removeAllAnimations()
        editorCard.layer.removeAllAnimations()
        for cell in dayCells { cell.layer.removeAllAnimations() }
    }

    // MARK: - Demo Loop

    private func playDemoStep() {
        guard !isStopped else { return }

        guard demoStep < demoEntries.count else {
            // Done — wait, dismiss editor, reset, loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.resetDemoEntries()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.playDemoStep()
                }
            }
            return
        }

        let entry = demoEntries[demoStep]
        guard entry.dayIndex < dayCells.count else { return }
        let cell = dayCells[entry.dayIndex]

        // Step 1: Select the day on the calendar
        cell.showSelected()

        // Step 2: Slide up the editor card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.showEditor(for: entry)
        }
    }

    private func showEditor(for entry: (dayIndex: Int, rating: Int, date: String, diary: String)) {
        editorDateLabel.text = entry.date
        editorJournalText.text = ""
        resetEditorRatingButtons()

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.editorCard.alpha = 1
            self.editorCard.transform = .identity
        }

        // Step 3: After a beat, select a rating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.isStopped else { return }
            self.selectRating(entry.rating)

            // Step 4: Type the journal text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.typeText(entry.diary) {
                    // Step 5: "Tap" save
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                        guard let self, !self.isStopped else { return }
                        self.tapSave(entry: entry)
                    }
                }
            }
        }
    }

    private func selectRating(_ rating: Int) {
        let index = rating - 1
        guard index < editorRatingButtons.count else { return }
        let btn = editorRatingButtons[index]
        let color = Self.editorRatingColor(for: rating)

        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            btn.backgroundColor = color
            btn.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            if let label = btn.subviews.first as? UILabel {
                label.textColor = .white
            }

            // Dim the others
            for (i, other) in self.editorRatingButtons.enumerated() where i != index {
                other.alpha = 0.5
            }
        }
    }

    private func resetEditorRatingButtons() {
        for (i, btn) in editorRatingButtons.enumerated() {
            let color = Self.editorRatingColor(for: i + 1)
            btn.backgroundColor = color.withAlphaComponent(0.15)
            btn.transform = .identity
            btn.alpha = 1.0
            if let label = btn.subviews.first as? UILabel {
                label.textColor = color
            }
        }
    }

    private func typeText(_ text: String, completion: @escaping () -> Void) {
        var charIndex = 0
        // Type in chunks of 3 characters for speed
        let chunkSize = 3
        let interval: TimeInterval = 0.04

        func typeNext() {
            guard !self.isStopped, charIndex < text.count else {
                completion()
                return
            }
            let endIndex = min(charIndex + chunkSize, text.count)
            let partial = String(text.prefix(endIndex))
            self.editorJournalText.text = partial
            charIndex = endIndex

            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                typeNext()
            }
        }
        typeNext()
    }

    private func tapSave(entry: (dayIndex: Int, rating: Int, date: String, diary: String)) {
        // Flash the save button
        UIView.animate(withDuration: 0.1) {
            self.editorSaveButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.editorSaveButton.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.7)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.editorSaveButton.transform = .identity
                self.editorSaveButton.backgroundColor = DesignTokens.Colors.accent
            }
        }

        Haptics.light()

        // Dismiss editor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, !self.isStopped else { return }

            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
                self.editorCard.alpha = 0
                self.editorCard.transform = CGAffineTransform(translationX: 0, y: 40)
            }

            // Fill the dot on the calendar and deselect
            let cell = self.dayCells[entry.dayIndex]
            cell.fillRating(entry.rating)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                cell.hideSelected()
                self?.demoStep += 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.playDemoStep()
                }
            }
        }
    }

    private func resetDemoEntries() {
        demoStep = 0
        for entry in demoEntries {
            guard entry.dayIndex < dayCells.count else { continue }
            dayCells[entry.dayIndex].resetRating()
        }
    }

    // MARK: - Rating Color (matches DayEntryEditorViewController)

    private static func editorRatingColor(for rating: Int) -> UIColor {
        let t = CGFloat(rating - 1) / 9.0
        if t < 0.5 {
            let p = t / 0.5
            return UIColor(red: 1.0, green: 0.3 + 0.5 * p, blue: 0.2 * (1 - p), alpha: 1)
        } else {
            let p = (t - 0.5) / 0.5
            return UIColor(red: 1.0 - 0.6 * p, green: 0.8 + 0.2 * p, blue: 0.15 * p, alpha: 1)
        }
    }
}

// MARK: - Day Cell

private final class DayCell: UIView {

    private let numberLabel = UILabel()
    private let dotView = UIView()
    private let selectionRing = UIView()
    private(set) var hasRating: Bool
    private let dayNumber: Int?

    init(dayNumber: Int?, rating: Int?) {
        self.dayNumber = dayNumber
        self.hasRating = rating != nil
        super.init(frame: .zero)
        if let rating { dotView.backgroundColor = Self.ratingColor(for: rating) }
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupCell() {
        layer.cornerRadius = DesignTokens.Radii.sm

        selectionRing.layer.cornerRadius = DesignTokens.Radii.sm
        selectionRing.layer.borderWidth = 1.5
        selectionRing.layer.borderColor = DesignTokens.Colors.accent.cgColor
        selectionRing.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        selectionRing.alpha = 0
        selectionRing.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectionRing)

        numberLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        numberLabel.textColor = dayNumber != nil ? DesignTokens.Colors.textSecondary : .clear
        numberLabel.textAlignment = .center
        numberLabel.text = dayNumber.map { "\($0)" }
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(numberLabel)

        dotView.layer.cornerRadius = 4
        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.alpha = 0
        dotView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        addSubview(dotView)

        NSLayoutConstraint.activate([
            selectionRing.topAnchor.constraint(equalTo: topAnchor),
            selectionRing.bottomAnchor.constraint(equalTo: bottomAnchor),
            selectionRing.leadingAnchor.constraint(equalTo: leadingAnchor),
            selectionRing.trailingAnchor.constraint(equalTo: trailingAnchor),
            numberLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            numberLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            dotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotView.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 2),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),
        ])
    }

    func showRating() {
        guard hasRating else { return }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.dotView.alpha = 1
            self.dotView.transform = .identity
            self.backgroundColor = self.dotView.backgroundColor?.withAlphaComponent(0.08)
        }
    }

    func showSelected() {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.selectionRing.alpha = 1
            self.numberLabel.textColor = DesignTokens.Colors.accent
        }
    }

    func hideSelected() {
        UIView.animate(withDuration: 0.2) {
            self.selectionRing.alpha = 0
            self.numberLabel.textColor = DesignTokens.Colors.textSecondary
        }
    }

    func fillRating(_ rating: Int) {
        hasRating = true
        dotView.backgroundColor = Self.ratingColor(for: rating)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            self.dotView.alpha = 1
            self.dotView.transform = .identity
            self.backgroundColor = self.dotView.backgroundColor?.withAlphaComponent(0.08)
        }
    }

    func resetRating() {
        hasRating = false
        UIView.animate(withDuration: 0.3) {
            self.dotView.alpha = 0
            self.dotView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            self.backgroundColor = .clear
        }
    }

    static func ratingColor(for rating: Int) -> UIColor {
        switch rating {
        case 1...3:  return DesignTokens.Colors.destructive
        case 4...5:  return DesignTokens.Colors.warning
        case 6...7:  return UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0)
        default:     return DesignTokens.Colors.success
        }
    }
}
