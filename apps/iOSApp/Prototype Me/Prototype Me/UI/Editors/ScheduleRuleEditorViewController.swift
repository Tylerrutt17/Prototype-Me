import UIKit
import GRDB

/// Modal editor for creating/editing a schedule rule on a directive.
/// Supports combining weekly + monthly + one-off in a single rule.
final class ScheduleRuleEditorViewController: BaseViewController {

    var directiveId: UUID?
    var existingRule: ScheduleRule?
    var onSave: (() -> Void)?

    // MARK: - State

    private var weeklyEnabled = false
    private var selectedWeekdays: Set<Int> = []  // 1=Sun ... 7=Sat
    private var monthlyEnabled = false
    private var selectedMonthDays: [Int] = []
    private var oneOffEnabled = false
    private var oneOffDates: [[Int]] = []  // [[year, month, day], ...]

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let weeklyToggle = UISwitch()
    private let weeklyDaysStack = UIStackView()
    private var dayButtons: [UIButton] = []

    private let monthlyToggle = UISwitch()
    private let monthlyField = UITextField()

    private let oneOffToggle = UISwitch()
    private let datePicker = UIDatePicker()
    private let oneOffDatesStack = UIStackView()
    private let addDateButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle(existingRule == nil ? "Add Schedule" : "Edit Schedule", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in self?.dismiss(animated: true) })
        navBar.setRightButtons([NavBarButton(title: "Save", action: { [weak self] in self?.save() })])

        loadExisting()
        setupUI()
    }

    private func loadExisting() {
        guard let rule = existingRule else { return }
        let p = rule.params
        if let days = p["weekdays"], !days.isEmpty {
            weeklyEnabled = true
            selectedWeekdays = Set(days)
        }
        if let dates = p["monthDays"], !dates.isEmpty {
            monthlyEnabled = true
            selectedMonthDays = dates
        }
        // New format: "oneOffs" stores flattened [y,m,d, y,m,d, ...]
        if let flat = p["oneOffs"], flat.count >= 3 {
            oneOffEnabled = true
            for i in stride(from: 0, to: flat.count - 2, by: 3) {
                oneOffDates.append([flat[i], flat[i+1], flat[i+2]])
            }
        }
        // Legacy: single "oneOff" [y,m,d]
        if !oneOffEnabled, let date = p["oneOff"], date.count == 3 {
            oneOffEnabled = true
            oneOffDates = [date]
        }
        // Legacy: old rules stored weekly days under "days" key
        if !weeklyEnabled, let days = p["days"], !days.isEmpty, rule.ruleType == .weekly {
            weeklyEnabled = true
            selectedWeekdays = Set(days)
        }
    }

    // MARK: - Setup

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.xl
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: DesignTokens.Spacing.xl),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2),
        ])

        // Weekly section
        contentStack.addArrangedSubview(buildSection(
            title: "Weekly",
            subtitle: "Repeats on selected days each week",
            icon: "calendar",
            toggle: weeklyToggle,
            isOn: weeklyEnabled,
            content: buildWeeklyContent()
        ))

        // Monthly section
        contentStack.addArrangedSubview(buildSection(
            title: "Monthly",
            subtitle: "Repeats on specific dates each month",
            icon: "calendar.badge.clock",
            toggle: monthlyToggle,
            isOn: monthlyEnabled,
            content: buildMonthlyContent()
        ))

        // One-off section
        contentStack.addArrangedSubview(buildSection(
            title: "One-Off",
            subtitle: "A single specific date",
            icon: "calendar.badge.exclamationmark",
            toggle: oneOffToggle,
            isOn: oneOffEnabled,
            content: buildOneOffContent()
        ))
    }

    private func buildSection(title: String, subtitle: String, icon: String, toggle: UISwitch, isOn: Bool, content: UIView) -> UIView {
        let container = UIView()
        container.backgroundColor = DesignTokens.Colors.surfacePrimary
        container.layer.cornerRadius = DesignTokens.Radii.lg
        container.clipsToBounds = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        toggle.isOn = isOn
        toggle.onTintColor = DesignTokens.Colors.accent
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)

        let headerRow = UIStackView(arrangedSubviews: [iconView, textStack, toggle])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.md
        headerRow.alignment = .center

        content.isHidden = !isOn

        let stack = UIStackView(arrangedSubviews: [headerRow, content])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        // Tag content view so we can show/hide it
        content.tag = toggle == weeklyToggle ? 100 : toggle == monthlyToggle ? 200 : 300

        return container
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let tag: Int
        if sender == weeklyToggle { weeklyEnabled = sender.isOn; tag = 100 }
        else if sender == monthlyToggle { monthlyEnabled = sender.isOn; tag = 200 }
        else { oneOffEnabled = sender.isOn; tag = 300 }

        if let content = view.viewWithTag(tag) {
            UIView.animate(withDuration: 0.25) {
                content.isHidden = !sender.isOn
                content.alpha = sender.isOn ? 1 : 0
            }
        }
        Haptics.selection()
    }

    // MARK: - Weekly

    private func buildWeeklyContent() -> UIView {
        let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
        weeklyDaysStack.axis = .horizontal
        weeklyDaysStack.distribution = .fillEqually
        weeklyDaysStack.spacing = DesignTokens.Spacing.sm

        for (i, name) in dayNames.enumerated() {
            let weekday = i + 1
            let btn = UIButton(type: .system)
            btn.setTitle(name, for: .normal)
            btn.titleLabel?.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
            btn.layer.cornerRadius = 20
            btn.clipsToBounds = true
            btn.tag = weekday
            btn.addTarget(self, action: #selector(dayTapped(_:)), for: .touchUpInside)
            btn.heightAnchor.constraint(equalToConstant: 40).isActive = true
            weeklyDaysStack.addArrangedSubview(btn)
            dayButtons.append(btn)
            updateDayButton(btn)
        }
        return weeklyDaysStack
    }

    @objc private func dayTapped(_ sender: UIButton) {
        let weekday = sender.tag
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
        updateDayButton(sender)
        Haptics.selection()
    }

    private func updateDayButton(_ btn: UIButton) {
        let isSelected = selectedWeekdays.contains(btn.tag)
        btn.backgroundColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.surfaceSecondary
        btn.setTitleColor(isSelected ? .white : DesignTokens.Colors.textPrimary, for: .normal)
    }

    // MARK: - Monthly

    private func buildMonthlyContent() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm

        let label = UILabel()
        label.text = "Days of month (comma-separated)"
        label.font = DesignTokens.Typography.caption1
        label.textColor = DesignTokens.Colors.textSecondary

        monthlyField.placeholder = "e.g. 1, 15"
        monthlyField.font = DesignTokens.Typography.body
        monthlyField.textColor = DesignTokens.Colors.textPrimary
        monthlyField.backgroundColor = DesignTokens.Colors.surfaceSecondary
        monthlyField.layer.cornerRadius = DesignTokens.Radii.md
        monthlyField.keyboardType = .numbersAndPunctuation
        monthlyField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        monthlyField.leftViewMode = .always
        monthlyField.heightAnchor.constraint(equalToConstant: 44).isActive = true

        if !selectedMonthDays.isEmpty {
            monthlyField.text = selectedMonthDays.map(String.init).joined(separator: ", ")
        }

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(monthlyField)
        return stack
    }

    // MARK: - One-Off

    private func buildOneOffContent() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = DesignTokens.Spacing.md

        // Existing dates list
        oneOffDatesStack.axis = .vertical
        oneOffDatesStack.spacing = DesignTokens.Spacing.sm
        container.addArrangedSubview(oneOffDatesStack)
        rebuildOneOffDatesList()

        // Date picker
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.tintColor = DesignTokens.Colors.accent
        datePicker.date = Date()

        // Add button
        addDateButton.setTitle("Add Date", for: .normal)
        addDateButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addDateButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        addDateButton.tintColor = DesignTokens.Colors.accent
        addDateButton.addTarget(self, action: #selector(addOneOffDate), for: .touchUpInside)

        let addRow = UIStackView(arrangedSubviews: [datePicker, UIView(), addDateButton])
        addRow.axis = .horizontal
        addRow.spacing = DesignTokens.Spacing.md
        addRow.alignment = .center
        container.addArrangedSubview(addRow)

        return container
    }

    @objc private func addOneOffDate() {
        let cal = Calendar.current
        let date = [
            cal.component(.year, from: datePicker.date),
            cal.component(.month, from: datePicker.date),
            cal.component(.day, from: datePicker.date),
        ]
        // Don't add duplicates
        guard !oneOffDates.contains(where: { $0 == date }) else { Haptics.warning(); return }
        oneOffDates.append(date)
        oneOffDates.sort { ($0[0], $0[1], $0[2]) < ($1[0], $1[1], $1[2]) }
        rebuildOneOffDatesList()
        Haptics.selection()
    }

    private func rebuildOneOffDatesList() {
        oneOffDatesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let fmt = DateFormatter()
        fmt.dateStyle = .medium

        for (i, date) in oneOffDates.enumerated() {
            guard date.count == 3 else { continue }
            var comps = DateComponents()
            comps.year = date[0]; comps.month = date[1]; comps.day = date[2]
            let dateStr = Calendar.current.date(from: comps).map { fmt.string(from: $0) } ?? "\(date[1])/\(date[2])/\(date[0])"

            let label = UILabel()
            label.text = dateStr
            label.font = DesignTokens.Typography.body
            label.textColor = DesignTokens.Colors.textPrimary

            let removeBtn = UIButton(type: .system)
            removeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            removeBtn.tintColor = DesignTokens.Colors.destructive.withAlphaComponent(0.6)
            removeBtn.tag = i
            removeBtn.addTarget(self, action: #selector(removeOneOffDate(_:)), for: .touchUpInside)

            let row = UIStackView(arrangedSubviews: [label, UIView(), removeBtn])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = DesignTokens.Spacing.sm

            let card = UIView()
            card.backgroundColor = DesignTokens.Colors.surfaceSecondary
            card.layer.cornerRadius = DesignTokens.Radii.sm
            row.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignTokens.Spacing.sm),
                row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignTokens.Spacing.sm),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignTokens.Spacing.md),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignTokens.Spacing.md),
            ])
            oneOffDatesStack.addArrangedSubview(card)
        }
    }

    @objc private func removeOneOffDate(_ sender: UIButton) {
        let index = sender.tag
        guard index < oneOffDates.count else { return }
        oneOffDates.remove(at: index)
        rebuildOneOffDatesList()
        Haptics.selection()
    }

    // MARK: - Save

    private func save() {
        guard let directiveId else { return }

        // Build combined params
        var params: [String: [Int]] = [:]

        if weeklyEnabled {
            guard !selectedWeekdays.isEmpty else { Haptics.warning(); return }
            params["weekdays"] = selectedWeekdays.sorted()
        }

        if monthlyEnabled {
            let text = monthlyField.text ?? ""
            let days = text.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                .filter { $0 >= 1 && $0 <= 31 }
            guard !days.isEmpty else { Haptics.warning(); return }
            params["monthDays"] = days.sorted()
        }

        if oneOffEnabled {
            guard !oneOffDates.isEmpty else { Haptics.warning(); return }
            // Flatten [[y,m,d], [y,m,d]] → [y,m,d, y,m,d]
            params["oneOffs"] = oneOffDates.flatMap { $0 }
        }

        guard !params.isEmpty else { Haptics.warning(); return }

        // Use .weekly as default ruleType (the params carry the real info)
        let ruleType: ScheduleType = weeklyEnabled ? .weekly : monthlyEnabled ? .monthly : .oneOff

        do {
            try dbQueue.write { db in
                if var existing = self.existingRule {
                    existing.ruleType = ruleType
                    existing.params = params
                    try existing.update(db)
                } else {
                    let rule = ScheduleRule(
                        id: UUID(), directiveId: directiveId,
                        ruleType: ruleType, params: params,
                        createdAt: Date()
                    )
                    try rule.insert(db)
                }

                // Generate today's instance if applicable
                try self.generateTodayInstance(db: db, params: params, directiveId: directiveId)
            }
            Haptics.success()
            onSave?()
        } catch {
            Haptics.error()
        }
    }

    private func generateTodayInstance(db: Database, params: [String: [Int]], directiveId: UUID) throws {
        let cal = Calendar.current
        let today = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayStr = fmt.string(from: today)

        let exists = try ScheduleInstance
            .filter(Column("directiveId") == directiveId && Column("date") == todayStr)
            .fetchCount(db) > 0
        guard !exists else { return }

        var shouldCreate = false

        // Check weekly
        if let weekdays = params["weekdays"] {
            let weekday = cal.component(.weekday, from: today)
            if weekdays.contains(weekday) { shouldCreate = true }
        }

        // Check monthly
        if let monthDays = params["monthDays"] {
            let day = cal.component(.day, from: today)
            if monthDays.contains(day) { shouldCreate = true }
        }

        // Check one-offs (flattened: [y,m,d, y,m,d, ...])
        if let flat = params["oneOffs"], flat.count >= 3 {
            let y = cal.component(.year, from: today)
            let m = cal.component(.month, from: today)
            let d = cal.component(.day, from: today)
            for i in stride(from: 0, to: flat.count - 2, by: 3) {
                if flat[i] == y && flat[i+1] == m && flat[i+2] == d {
                    shouldCreate = true
                    break
                }
            }
        }
        // Legacy single oneOff
        if let oneOff = params["oneOff"], oneOff.count == 3 {
            if cal.component(.year, from: today) == oneOff[0]
                && cal.component(.month, from: today) == oneOff[1]
                && cal.component(.day, from: today) == oneOff[2] {
                shouldCreate = true
            }
        }

        if shouldCreate {
            let instance = ScheduleInstance(id: UUID(), directiveId: directiveId, date: todayStr, status: .pending)
            try instance.insert(db)
        }
    }
}
