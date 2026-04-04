import UIKit

/// Bottom-sheet calendar showing missed / completed / unscheduled days
/// for a single directive across the review period.
final class MissedCalendarSheet: BaseViewController {

    private let item: PeriodicReview.MissedScheduled
    private let periodStart: String
    private let periodEnd: String

    private let titleLabel = UILabel()
    private let scheduleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let legendView = UIView()
    private let gridView = UIView()

    init(item: PeriodicReview.MissedScheduled, periodStart: String, periodEnd: String) {
        self.item = item
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        super.init(nibName: nil, bundle: nil)
        hidesNavBar = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background

        setupHeader()
        setupLegend()
        setupCalendar()
    }

    // MARK: - Header

    private func setupHeader() {
        titleLabel.text = item.directiveTitle
        titleLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        // Schedule label derived from which weekdays appear in scheduledDates
        scheduleLabel.text = Self.scheduleDescription(from: item.scheduledDates)
        scheduleLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        scheduleLabel.textColor = DesignTokens.Colors.accent
        scheduleLabel.numberOfLines = 0

        let missed = item.missedDates.count
        let total = item.scheduledDates.count
        let completed = total - missed
        summaryLabel.text = "\(missed) missed • \(completed) completed • \(total) scheduled"
        summaryLabel.font = DesignTokens.Typography.footnote
        summaryLabel.textColor = DesignTokens.Colors.textSecondary

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, scheduleLabel, summaryLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4
        headerStack.setCustomSpacing(2, after: scheduleLabel)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.lg),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    // MARK: - Legend

    private func setupLegend() {
        legendView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(legendView)

        let missed = makeLegendItem(symbol: "xmark", color: DesignTokens.Colors.destructive, label: "Missed")
        let completed = makeLegendItem(symbol: "checkmark", color: DesignTokens.Colors.success, label: "Done")
        let unscheduled = makeLegendItem(symbol: "circle", color: DesignTokens.Colors.textTertiary, label: "Off day")

        let stack = UIStackView(arrangedSubviews: [missed, completed, unscheduled])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.lg
        stack.translatesAutoresizingMaskIntoConstraints = false
        legendView.addSubview(stack)

        NSLayoutConstraint.activate([
            legendView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            legendView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            legendView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),

            stack.topAnchor.constraint(equalTo: legendView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: legendView.leadingAnchor),
            stack.bottomAnchor.constraint(equalTo: legendView.bottomAnchor),
        ])
    }

    private func makeLegendItem(symbol: String, color: UIColor, label: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)))
        icon.tintColor = color
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let text = UILabel()
        text.text = label
        text.font = DesignTokens.Typography.caption2
        text.textColor = DesignTokens.Colors.textSecondary

        let stack = UIStackView(arrangedSubviews: [icon, text])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 4
        return stack
    }

    // MARK: - Calendar grid

    private func setupCalendar() {
        gridView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gridView)

        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: legendView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            gridView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        buildGrid()
    }

    private func buildGrid() {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let start = parser.date(from: periodStart),
              let end = parser.date(from: periodEnd) else { return }

        let cal = Calendar(identifier: .gregorian)
        let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
        let dayCount = days + 1

        // Weekday labels row
        let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]
        let weekdayRow = UIStackView()
        weekdayRow.axis = .horizontal
        weekdayRow.distribution = .fillEqually
        weekdayRow.spacing = 4
        weekdayRow.translatesAutoresizingMaskIntoConstraints = false
        for letter in weekdayLabels {
            let label = UILabel()
            label.text = letter
            label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            label.textColor = DesignTokens.Colors.textTertiary
            label.textAlignment = .center
            weekdayRow.addArrangedSubview(label)
        }
        gridView.addSubview(weekdayRow)
        NSLayoutConstraint.activate([
            weekdayRow.topAnchor.constraint(equalTo: gridView.topAnchor),
            weekdayRow.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
            weekdayRow.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
        ])

        // Missed/scheduled sets for fast lookup
        let missedSet = Set(item.missedDates)
        let scheduledSet = Set(item.scheduledDates)

        // Build rows — start at the first-of-period's weekday offset
        let startWeekday = cal.component(.weekday, from: start) - 1  // 0=Sun
        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 4
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        gridView.addSubview(rowsStack)

        var currentRow: UIStackView = makeDayRow()
        rowsStack.addArrangedSubview(currentRow)

        // Leading empty cells for the first row
        for _ in 0..<startWeekday {
            currentRow.addArrangedSubview(makeEmptyCell())
        }

        var columnIndex = startWeekday
        for dayOffset in 0..<dayCount {
            if columnIndex == 7 {
                currentRow = makeDayRow()
                rowsStack.addArrangedSubview(currentRow)
                columnIndex = 0
            }

            guard let date = cal.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            let dateStr = parser.string(from: date)
            let dayNum = cal.component(.day, from: date)

            let state: DayCell.State
            if missedSet.contains(dateStr) {
                state = .missed
            } else if scheduledSet.contains(dateStr) {
                state = .completed
            } else {
                state = .unscheduled
            }
            currentRow.addArrangedSubview(DayCell(day: dayNum, state: state))
            columnIndex += 1
        }

        // Trailing empty cells
        while columnIndex < 7 {
            currentRow.addArrangedSubview(makeEmptyCell())
            columnIndex += 1
        }

        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: weekdayRow.bottomAnchor, constant: 6),
            rowsStack.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: gridView.bottomAnchor),
        ])
    }

    private func makeDayRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 4
        return row
    }

    private func makeEmptyCell() -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalTo: v.widthAnchor).isActive = true
        return v
    }

    // MARK: - Schedule label derivation

    /// Inspect which weekdays or month-days appear in scheduledDates and return
    /// a human-readable description like "Mon · Wed · Fri" or "Every day".
    private static func scheduleDescription(from scheduledDates: [String]) -> String {
        guard !scheduledDates.isEmpty else { return "" }

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        let cal = Calendar(identifier: .gregorian)

        var weekdaysSeen = Set<Int>() // 1=Sun ... 7=Sat
        var daysOfMonth = Set<Int>()
        for dateStr in scheduledDates {
            guard let date = parser.date(from: dateStr) else { continue }
            weekdaysSeen.insert(cal.component(.weekday, from: date))
            daysOfMonth.insert(cal.component(.day, from: date))
        }

        // If it fires every day across the period, call it that
        if weekdaysSeen.count == 7 { return "Every day" }
        if weekdaysSeen == [2, 3, 4, 5, 6] { return "Weekdays" }
        if weekdaysSeen == [1, 7] { return "Weekends" }

        // Heuristic: if the same number of month-days keeps repeating, it's monthly.
        // Otherwise assume weekly and show weekday abbreviations.
        let shortSymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let ordered = Array(weekdaysSeen).sorted()
        let weekdayLabel = ordered.map { shortSymbols[$0 - 1] }.joined(separator: " · ")
        return weekdayLabel
    }
}

// MARK: - DayCell

private final class DayCell: UIView {
    enum State { case missed, completed, unscheduled }

    init(day: Int, state: State) {
        super.init(frame: .zero)
        setupCell(day: day, state: state)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell(day: Int, state: State) {
        heightAnchor.constraint(equalTo: widthAnchor).isActive = true
        layer.cornerRadius = DesignTokens.Radii.sm
        clipsToBounds = true

        let dayLabel = UILabel()
        dayLabel.text = "\(day)"
        dayLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        dayLabel.textColor = DesignTokens.Colors.textSecondary
        dayLabel.textAlignment = .center

        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit

        switch state {
        case .missed:
            backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.15)
            iconView.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
            iconView.tintColor = DesignTokens.Colors.destructive
        case .completed:
            backgroundColor = DesignTokens.Colors.success.withAlphaComponent(0.15)
            iconView.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
            iconView.tintColor = DesignTokens.Colors.success
        case .unscheduled:
            backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.4)
            iconView.image = nil
        }

        let stack = UIStackView(arrangedSubviews: [dayLabel, iconView])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 1
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 10),
        ])
    }
}
