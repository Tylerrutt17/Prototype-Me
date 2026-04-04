import UIKit

/// Card-style section for configuring a schedule (weekly/monthly/one-off) on a directive.
final class ScheduleEditorSection: UIView, UITextFieldDelegate {

    private let toggle = UISwitch()
    private let detailStack = UIStackView()

    // Weekly
    private var weeklyEnabled = false
    private let weeklyToggle = UISwitch()
    private var selectedWeekdays: Set<Int> = []
    private var dayButtons: [UIButton] = []
    private let weeklyContent = UIStackView()

    // Monthly
    private var monthlyEnabled = false
    private let monthlyToggle = UISwitch()
    private let monthlyField = UITextField()
    private let monthlyContent = UIStackView()

    // One-off
    private var oneOffEnabled = false
    private let oneOffToggle = UISwitch()
    private var oneOffDates: [[Int]] = []
    private let oneOffDatesStack = UIStackView()
    private let oneOffDatePicker = UIDatePicker()
    private let oneOffContent = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.clipsToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        let sectionLabel = UILabel()
        sectionLabel.text = "CHECKLIST"
        sectionLabel.font = DesignTokens.Typography.caption1
        sectionLabel.textColor = DesignTokens.Colors.textSecondary
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sectionLabel)

        // Header
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: "calendar.badge.clock", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "Enable Checklist"
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        toggle.isOn = false
        toggle.onTintColor = DesignTokens.Colors.accent
        toggle.addTarget(self, action: #selector(mainToggled), for: .valueChanged)

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), toggle])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.md
        headerRow.alignment = .center

        let descLabel = UILabel()
        descLabel.text = "Add a checkbox to your Focus tab on specific days. Check it off when done — it resets automatically next time."
        descLabel.font = DesignTokens.Typography.caption1
        descLabel.textColor = DesignTokens.Colors.textSecondary
        descLabel.numberOfLines = 0

        // Detail content (hidden when off)
        detailStack.axis = .vertical
        detailStack.spacing = DesignTokens.Spacing.lg
        detailStack.isHidden = true

        detailStack.addArrangedSubview(buildWeeklyRow())
        detailStack.addArrangedSubview(buildMonthlyRow())
        detailStack.addArrangedSubview(buildOneOffRow())

        let mainStack = UIStackView(arrangedSubviews: [headerRow, descLabel, detailStack])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(mainStack)

        let padding = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            card.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: padding),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -padding),
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: padding),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -padding),
        ])
    }

    @objc private func mainToggled() {
        UIView.animate(withDuration: 0.25) {
            self.detailStack.isHidden = !self.toggle.isOn
            self.detailStack.alpha = self.toggle.isOn ? 1 : 0
        }
        Haptics.selection()
    }

    // MARK: - Weekly

    private func buildWeeklyRow() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = DesignTokens.Spacing.sm

        let row = UIStackView()
        let label = UILabel()
        label.text = "Weekly"
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary
        weeklyToggle.isOn = false
        weeklyToggle.onTintColor = DesignTokens.Colors.accent
        weeklyToggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        weeklyToggle.addTarget(self, action: #selector(weeklyToggled), for: .valueChanged)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(weeklyToggle)
        row.axis = .horizontal
        row.alignment = .center
        container.addArrangedSubview(row)

        // Day buttons
        let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
        let daysRow = UIStackView()
        daysRow.axis = .horizontal
        daysRow.distribution = .fillEqually
        daysRow.spacing = DesignTokens.Spacing.xs

        for (i, name) in dayNames.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(name, for: .normal)
            btn.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            btn.layer.cornerRadius = 16
            btn.clipsToBounds = true
            btn.tag = i + 1
            btn.backgroundColor = DesignTokens.Colors.surfaceSecondary
            btn.setTitleColor(DesignTokens.Colors.textPrimary, for: .normal)
            btn.addTarget(self, action: #selector(dayTapped(_:)), for: .touchUpInside)
            btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
            daysRow.addArrangedSubview(btn)
            dayButtons.append(btn)
        }
        weeklyContent.axis = .vertical
        weeklyContent.addArrangedSubview(daysRow)
        weeklyContent.isHidden = true
        container.addArrangedSubview(weeklyContent)

        return container
    }

    @objc private func weeklyToggled() {
        weeklyEnabled = weeklyToggle.isOn
        UIView.animate(withDuration: 0.2) {
            self.weeklyContent.isHidden = !self.weeklyEnabled
        }
        Haptics.selection()
    }

    @objc private func dayTapped(_ sender: UIButton) {
        let day = sender.tag
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
            sender.backgroundColor = DesignTokens.Colors.surfaceSecondary
            sender.setTitleColor(DesignTokens.Colors.textPrimary, for: .normal)
        } else {
            selectedWeekdays.insert(day)
            sender.backgroundColor = DesignTokens.Colors.accent
            sender.setTitleColor(.white, for: .normal)
        }
        Haptics.selection()
    }

    // MARK: - Monthly

    private func buildMonthlyRow() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = DesignTokens.Spacing.sm

        let row = UIStackView()
        let label = UILabel()
        label.text = "Monthly"
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary
        monthlyToggle.isOn = false
        monthlyToggle.onTintColor = DesignTokens.Colors.accent
        monthlyToggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        monthlyToggle.addTarget(self, action: #selector(monthlyToggled), for: .valueChanged)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(monthlyToggle)
        row.axis = .horizontal
        row.alignment = .center
        container.addArrangedSubview(row)

        monthlyField.placeholder = "e.g. 1, 15"
        monthlyField.font = DesignTokens.Typography.body
        monthlyField.textColor = DesignTokens.Colors.textPrimary
        monthlyField.backgroundColor = DesignTokens.Colors.surfaceSecondary
        monthlyField.layer.cornerRadius = DesignTokens.Radii.sm
        monthlyField.keyboardType = .numbersAndPunctuation
        monthlyField.delegate = self
        monthlyField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        monthlyField.leftViewMode = .always
        monthlyField.heightAnchor.constraint(equalToConstant: 40).isActive = true

        monthlyContent.axis = .vertical
        monthlyContent.addArrangedSubview(monthlyField)
        monthlyContent.isHidden = true
        container.addArrangedSubview(monthlyContent)

        return container
    }

    @objc private func monthlyToggled() {
        monthlyEnabled = monthlyToggle.isOn
        UIView.animate(withDuration: 0.2) {
            self.monthlyContent.isHidden = !self.monthlyEnabled
        }
        Haptics.selection()
    }

    // MARK: - One-Off

    private func buildOneOffRow() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = DesignTokens.Spacing.sm

        let row = UIStackView()
        let label = UILabel()
        label.text = "Specific Dates"
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary
        oneOffToggle.isOn = false
        oneOffToggle.onTintColor = DesignTokens.Colors.accent
        oneOffToggle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        oneOffToggle.addTarget(self, action: #selector(oneOffToggled), for: .valueChanged)
        row.addArrangedSubview(label)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(oneOffToggle)
        row.axis = .horizontal
        row.alignment = .center
        container.addArrangedSubview(row)

        oneOffContent.axis = .vertical
        oneOffContent.spacing = DesignTokens.Spacing.sm

        oneOffDatesStack.axis = .vertical
        oneOffDatesStack.spacing = DesignTokens.Spacing.xs
        oneOffContent.addArrangedSubview(oneOffDatesStack)

        oneOffDatePicker.datePickerMode = .date
        oneOffDatePicker.preferredDatePickerStyle = .compact
        oneOffDatePicker.tintColor = DesignTokens.Colors.accent

        let addBtn = UIButton(type: .system)
        addBtn.setTitle("Add Date", for: .normal)
        addBtn.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addBtn.titleLabel?.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        addBtn.tintColor = DesignTokens.Colors.accent
        addBtn.addTarget(self, action: #selector(addOneOffDate), for: .touchUpInside)

        let addRow = UIStackView(arrangedSubviews: [oneOffDatePicker, UIView(), addBtn])
        addRow.axis = .horizontal
        addRow.alignment = .center
        oneOffContent.addArrangedSubview(addRow)

        oneOffContent.isHidden = true
        container.addArrangedSubview(oneOffContent)

        return container
    }

    @objc private func oneOffToggled() {
        oneOffEnabled = oneOffToggle.isOn
        UIView.animate(withDuration: 0.2) {
            self.oneOffContent.isHidden = !self.oneOffEnabled
        }
        Haptics.selection()
    }

    @objc private func addOneOffDate() {
        let cal = Calendar.current
        let date = [
            cal.component(.year, from: oneOffDatePicker.date),
            cal.component(.month, from: oneOffDatePicker.date),
            cal.component(.day, from: oneOffDatePicker.date),
        ]
        guard !oneOffDates.contains(where: { $0 == date }) else { Haptics.warning(); return }
        oneOffDates.append(date)
        oneOffDates.sort { ($0[0], $0[1], $0[2]) < ($1[0], $1[1], $1[2]) }
        rebuildOneOffList()
        Haptics.selection()
    }

    private func rebuildOneOffList() {
        oneOffDatesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium

        for (i, date) in oneOffDates.enumerated() {
            guard date.count == 3 else { continue }
            var comps = DateComponents()
            comps.year = date[0]; comps.month = date[1]; comps.day = date[2]
            let str = Calendar.current.date(from: comps).map { fmt.string(from: $0) } ?? "\(date[1])/\(date[2])/\(date[0])"

            let label = UILabel()
            label.text = str
            label.font = DesignTokens.Typography.caption1
            label.textColor = DesignTokens.Colors.textPrimary

            let removeBtn = UIButton(type: .system)
            removeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            removeBtn.tintColor = DesignTokens.Colors.destructive.withAlphaComponent(0.6)
            removeBtn.tag = i
            removeBtn.addTarget(self, action: #selector(removeOneOff(_:)), for: .touchUpInside)

            let row = UIStackView(arrangedSubviews: [label, UIView(), removeBtn])
            row.axis = .horizontal
            row.alignment = .center
            oneOffDatesStack.addArrangedSubview(row)
        }
    }

    @objc private func removeOneOff(_ sender: UIButton) {
        guard sender.tag < oneOffDates.count else { return }
        oneOffDates.remove(at: sender.tag)
        rebuildOneOffList()
        Haptics.selection()
    }

    // MARK: - UITextFieldDelegate

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: r, with: string).count <= FieldLimits.Schedule.monthlyDays
    }

    // MARK: - Public API

    func buildParams() -> [String: [Int]] {
        guard toggle.isOn else { return [:] }
        var params: [String: [Int]] = [:]

        if weeklyEnabled && !selectedWeekdays.isEmpty {
            params["weekdays"] = selectedWeekdays.sorted()
        }
        if monthlyEnabled {
            let text = monthlyField.text ?? ""
            let days = text.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .filter { $0 >= 1 && $0 <= 31 }
            if !days.isEmpty { params["monthDays"] = days.sorted() }
        }
        if oneOffEnabled && !oneOffDates.isEmpty {
            params["oneOffs"] = oneOffDates.flatMap { $0 }
        }
        return params
    }

    func loadFromRule(_ rule: ScheduleRule) {
        toggle.isOn = true
        detailStack.isHidden = false
        detailStack.alpha = 1

        if let weekdays = rule.params["weekdays"] ?? (rule.ruleType == .weekly ? rule.params["days"] : nil), !weekdays.isEmpty {
            weeklyEnabled = true
            weeklyToggle.isOn = true
            weeklyContent.isHidden = false
            selectedWeekdays = Set(weekdays)
            for btn in dayButtons {
                if selectedWeekdays.contains(btn.tag) {
                    btn.backgroundColor = DesignTokens.Colors.accent
                    btn.setTitleColor(.white, for: .normal)
                }
            }
        }
        if let monthDays = rule.params["monthDays"], !monthDays.isEmpty {
            monthlyEnabled = true
            monthlyToggle.isOn = true
            monthlyContent.isHidden = false
            monthlyField.text = monthDays.map(String.init).joined(separator: ", ")
        }
        if let flat = rule.params["oneOffs"], flat.count >= 3 {
            oneOffEnabled = true
            oneOffToggle.isOn = true
            oneOffContent.isHidden = false
            for i in stride(from: 0, to: flat.count - 2, by: 3) {
                oneOffDates.append([flat[i], flat[i+1], flat[i+2]])
            }
            rebuildOneOffList()
        }
        if let date = rule.params["oneOff"], date.count == 3 {
            oneOffEnabled = true
            oneOffToggle.isOn = true
            oneOffContent.isHidden = false
            oneOffDates = [date]
            rebuildOneOffList()
        }
    }
}
