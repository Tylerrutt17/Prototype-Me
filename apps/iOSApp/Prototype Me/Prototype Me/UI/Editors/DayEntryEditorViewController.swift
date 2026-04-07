import UIKit
import GRDB

final class DayEntryEditorViewController: BaseViewController {

    // MARK: - Public

    var entryId: UUID?                       // nil = create, non-nil = edit
    var preselectedDate: String?             // yyyy-MM-dd
    var dayEntryService: DayEntryService?
    var onSave: (() -> Void)?

    // MARK: - Form Controls

    private let dateHeaderLabel = UILabel()
    private let datePicker = UIDatePicker()
    private lazy var dateRow: UIStackView = {
        dateHeaderLabel.text = "DATE"
        dateHeaderLabel.font = DesignTokens.Typography.caption1
        dateHeaderLabel.textColor = DesignTokens.Colors.textSecondary

        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.tintColor = DesignTokens.Colors.accent

        let row = UIStackView(arrangedSubviews: [dateHeaderLabel, datePicker])
        row.axis = .horizontal
        row.alignment = .center
        return row
    }()

    private let ratingHeaderLabel = UILabel()
    private let ratingButtonStack = UIStackView()
    private var ratingButtons: [UIButton] = []

    /// Colors gradient from red (1) through yellow (5) to green (10)
    private static func ratingColor(for rating: Int) -> UIColor {
        let t = CGFloat(rating - 1) / 9.0  // 0.0 to 1.0
        if t < 0.5 {
            // Red → Yellow
            let p = t / 0.5
            return UIColor(
                red: 1.0,
                green: 0.3 + 0.5 * p,
                blue: 0.2 * (1 - p),
                alpha: 1
            )
        } else {
            // Yellow → Green
            let p = (t - 0.5) / 0.5
            return UIColor(
                red: 1.0 - 0.6 * p,
                green: 0.8 + 0.2 * p,
                blue: 0.15 * p,
                alpha: 1
            )
        }
    }

    private lazy var ratingRow: UIStackView = {
        ratingHeaderLabel.text = "HOW WAS YOUR DAY?"
        ratingHeaderLabel.font = DesignTokens.Typography.caption1
        ratingHeaderLabel.textColor = DesignTokens.Colors.textSecondary

        ratingButtonStack.axis = .horizontal
        ratingButtonStack.distribution = .fillEqually
        ratingButtonStack.spacing = 4

        for i in 1...10 {
            let btn = UIButton(type: .system)
            btn.setTitle("\(i)", for: .normal)
            btn.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .bold)
            btn.tag = i
            btn.layer.cornerRadius = DesignTokens.Radii.sm
            btn.clipsToBounds = true
            btn.addTarget(self, action: #selector(ratingButtonTapped(_:)), for: .touchUpInside)
            ratingButtonStack.addArrangedSubview(btn)
            ratingButtons.append(btn)
        }

        let outer = UIStackView(arrangedSubviews: [ratingHeaderLabel, ratingButtonStack])
        outer.axis = .vertical
        outer.spacing = DesignTokens.Spacing.sm
        return outer
    }()

    private let journalField: FormTextView = {
        let f = FormTextView(title: "JOURNAL", minHeight: 160)
        f.maxLength = FieldLimits.Journal.diary
        return f
    }()
    private let tagsField: FormTextField = {
        let f = FormTextField(title: "TAGS (COMMA SEPARATED)", placeholder: "focus, health, work")
        // Generous input limit derived from tag count × (tag length + ", ")
        f.maxLength = FieldLimits.Journal.tagCount * (FieldLimits.Journal.tag + 2)
        return f
    }()

    private let hintContainer = UIView()
    private let hintIcon = UIImageView()
    private let hintLabel = UILabel()

    // MARK: - State

    private var selectedRating: Int = 0       // 0 = no rating

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle(entryId == nil ? "New Entry" : "Edit Entry", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in self?.cancelTapped() })
        navBar.setRightButtons([NavBarButton(title: "Save", action: { [weak self] in self?.saveTapped() })])

        buildForm()
        updateRatingButtons(animated: false)

        if let preselectedDate,
           let date = Self.dateFormatter.date(from: preselectedDate) {
            datePicker.date = date
        }

        if entryId != nil { loadExistingEntry() }
        observeKeyboard()
    }

    // MARK: - Build Form

    private func buildForm() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = DesignTokens.Spacing.xl
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        stackView.addArrangedSubview(dateRow)
        stackView.addArrangedSubview(ratingRow)
        stackView.addArrangedSubview(hintContainer)
        configureHintContainer()
        stackView.addArrangedSubview(journalField)
        stackView.setCustomSpacing(DesignTokens.Spacing.md, after: hintContainer)

        let padding = DesignTokens.Spacing.lg

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -padding),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2),
        ])
    }

    // MARK: - Data Loading

    private func loadExistingEntry() {
        guard let entryId else { return }
        do {
            let entry = try dbQueue.read { db in
                try DayEntry.fetchOne(db, key: entryId)
            }
            guard let entry else { return }
            if let date = Self.dateFormatter.date(from: entry.date) {
                datePicker.date = date
            }
            selectedRating = entry.rating ?? 0
            updateRatingButtons(animated: false)
            updateRatingHint(animated: false)
            journalField.textView.text = entry.diary
            tagsField.textField.text = entry.tags.joined(separator: ", ")
        } catch {}
    }

    // MARK: - Actions

    @objc private func ratingButtonTapped(_ sender: UIButton) {
        let tapped = sender.tag
        // Tap same one again to deselect
        if selectedRating == tapped {
            selectedRating = 0
        } else {
            selectedRating = tapped
        }
        updateRatingButtons(animated: true)
        updateRatingHint(animated: true)
        Haptics.selection()
    }

    // MARK: - Hint

    private func configureHintContainer() {
        hintContainer.layer.cornerRadius = DesignTokens.Radii.md
        hintContainer.clipsToBounds = true
        hintContainer.isHidden = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        hintIcon.image = UIImage(systemName: "lightbulb.fill", withConfiguration: iconConfig)
        hintIcon.contentMode = .scaleAspectFit
        hintIcon.setContentHuggingPriority(.required, for: .horizontal)
        hintIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        hintLabel.font = DesignTokens.Typography.caption1
        hintLabel.textColor = DesignTokens.Colors.textSecondary
        hintLabel.numberOfLines = 0

        let hintStack = UIStackView(arrangedSubviews: [hintIcon, hintLabel])
        hintStack.axis = .horizontal
        hintStack.alignment = .top
        hintStack.spacing = DesignTokens.Spacing.sm
        hintStack.translatesAutoresizingMaskIntoConstraints = false
        hintContainer.addSubview(hintStack)

        NSLayoutConstraint.activate([
            hintStack.topAnchor.constraint(equalTo: hintContainer.topAnchor, constant: DesignTokens.Spacing.sm),
            hintStack.bottomAnchor.constraint(equalTo: hintContainer.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            hintStack.leadingAnchor.constraint(equalTo: hintContainer.leadingAnchor, constant: DesignTokens.Spacing.md),
            hintStack.trailingAnchor.constraint(equalTo: hintContainer.trailingAnchor, constant: -DesignTokens.Spacing.md),
            hintIcon.widthAnchor.constraint(equalToConstant: 16),
            hintIcon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    private func updateRatingHint(animated: Bool) {
        let n = selectedRating

        guard n > 0 else {
            let wasVisible = !hintContainer.isHidden
            if wasVisible && animated {
                UIView.animate(withDuration: 0.2, animations: {
                    self.hintContainer.alpha = 0
                }, completion: { _ in
                    self.hintContainer.isHidden = true
                    self.hintContainer.alpha = 1
                })
            } else {
                hintContainer.isHidden = true
                hintContainer.alpha = 1
            }
            return
        }

        let text: String
        switch n {
        case 1...3:
            text = "Note why it felt like a \(n). What went wrong or dragged you down? Those details are how patterns show up later."
        case 4...6:
            text = "Note why it felt like a \(n). What held it back from being better? Small details add up."
        case 7...8:
            text = "Note why it felt like a \(n). What worked? Capture it so you can repeat it."
        default: // 9-10
            text = "Note why it felt like a \(n). What clicked today? Lock it in."
        }

        let color = Self.ratingColor(for: n)
        let wasHidden = hintContainer.isHidden

        hintLabel.text = text
        hintIcon.tintColor = color
        hintContainer.backgroundColor = color.withAlphaComponent(0.12)

        if wasHidden {
            hintContainer.isHidden = false
            hintContainer.alpha = 0
            if animated {
                UIView.animate(withDuration: 0.25) {
                    self.hintContainer.alpha = 1
                }
            } else {
                hintContainer.alpha = 1
            }
        }
    }

    private func updateRatingButtons(animated: Bool) {
        let hasSelection = selectedRating > 0

        for btn in ratingButtons {
            let rating = btn.tag
            let isSelected = rating == selectedRating
            let color = Self.ratingColor(for: rating)

            let targetBg: UIColor
            let targetFg: UIColor
            let targetScale: CGFloat
            let targetAlpha: CGFloat

            if isSelected {
                targetBg = color
                targetFg = .white
                targetScale = 1.15
                targetAlpha = 1.0
            } else if hasSelection {
                targetBg = color.withAlphaComponent(0.1)
                targetFg = color.withAlphaComponent(0.5)
                targetScale = 1.0
                targetAlpha = 0.6
            } else {
                targetBg = color.withAlphaComponent(0.15)
                targetFg = color
                targetScale = 1.0
                targetAlpha = 1.0
            }

            let apply = {
                btn.backgroundColor = targetBg
                btn.setTitleColor(targetFg, for: .normal)
                btn.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
                btn.alpha = targetAlpha
            }

            if animated {
                UIView.animate(
                    withDuration: isSelected ? 0.4 : 0.2,
                    delay: 0,
                    usingSpringWithDamping: isSelected ? 0.45 : 1.0,
                    initialSpringVelocity: isSelected ? 14 : 0,
                    options: .allowUserInteraction
                ) {
                    apply()
                }
            } else {
                apply()
            }
        }
    }

    private func saveTapped() {
        guard selectedRating > 0 else {
            Haptics.warning()
            shakeRatingRow()
            return
        }

        let dateString = Self.dateFormatter.string(from: datePicker.date)
        let diary = journalField.textView.text ?? ""
        let tagsText = tagsField.textField.text ?? ""
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let rating: Int? = selectedRating

        Task {
            do {
                _ = try await dayEntryService?.createOrUpdate(
                    date: dateString, rating: rating, diary: diary, tags: tags
                )
                Haptics.success()
                onSave?()
            } catch {
                Haptics.error()
            }
        }
    }

    private func cancelTapped() {
        dismiss(animated: true)
    }

    private func shakeRatingRow() {
        let flash = UIColor.systemRed.withAlphaComponent(0.15)
        let original = ratingHeaderLabel.textColor

        ratingHeaderLabel.textColor = .systemRed

        UIView.animate(withDuration: 0.08, animations: {
            self.ratingRow.transform = CGAffineTransform(translationX: -8, y: 0)
        }) { _ in
            UIView.animate(withDuration: 0.08, animations: {
                self.ratingRow.transform = CGAffineTransform(translationX: 8, y: 0)
            }) { _ in
                UIView.animate(withDuration: 0.08, animations: {
                    self.ratingRow.transform = .identity
                })
            }
        }

        // Flash unselected buttons
        for btn in ratingButtons where btn.tag != selectedRating {
            btn.backgroundColor = flash
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.ratingHeaderLabel.textColor = original
            self.updateRatingButtons(animated: true)
        }
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scrollView.contentInset.bottom = frame.height
        scrollView.verticalScrollIndicatorInsets.bottom = frame.height
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
}
