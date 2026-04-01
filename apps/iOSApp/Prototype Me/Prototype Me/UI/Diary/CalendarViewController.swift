import UIKit
import GRDB

nonisolated private enum CalendarSection: Sendable { case main }

nonisolated private struct CalendarDay: Hashable, Sendable {
    let date: String          // yyyy-MM-dd or empty for padding
    let rating: Int?
    let dayOfMonth: Int
    let isEmpty: Bool
    let entryId: UUID?

    func hash(into hasher: inout Hasher) { hasher.combine(date) }
    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.date == rhs.date }
}

class CalendarViewController: BaseViewController {

    /// Tap edit button on an existing entry → open editor
    var onEditEntry: ((UUID) -> Void)?
    /// Tap "Create Entry" for a day with no entry
    var onCreateEntry: ((String) -> Void)?
    /// When true, hides the nav bar (used when embedded as a child VC)
    var embedded = false

    // MARK: - State

    private var selectedDate: String?
    private var allDays: [CalendarDay] = []
    private var entryCache: [String: DayEntry] = [:]   // date → entry

    // MARK: - Calendar UI

    private let dayHeaderStack = UIStackView()
    private var calendarCollectionView: UICollectionView!
    private var calendarDataSource: UICollectionViewDiffableDataSource<CalendarSection, CalendarDay>!

    // MARK: - Detail Panel

    private let detailScroll = UIScrollView()
    private let detailStack = UIStackView()
    private let selectedDateLabel = UILabel()
    private let ratingContainer = UIView()
    private let ratingValueLabel = UILabel()
    private let ratingBar = UIView()
    private let ratingFill = UIView()
    private let tagsStack = UIStackView()
    private let diaryLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private let editButton = UIButton(type: .system)
    private let createButton = UIButton(type: .system)
    private let separator = UIView()

    /// Top anchor for content — navBar bottom when standalone, top safe area when embedded
    private var calendarContentTop: NSLayoutYAxisAnchor {
        embedded ? view.safeAreaLayoutGuide.topAnchor : contentTopAnchor
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if embedded {
            navBar.isHidden = true
            view.backgroundColor = .clear
        } else {
            navBar.setTitle("Calendar", animated: false)
        }

        setupDayHeaders()
        setupCalendar()
        setupDetailPanel()
        configureCalendarDataSource()
        loadData()

        // Select today by default
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        selectDay(fmt.string(from: .now))
    }

    // MARK: - Day Headers

    private func setupDayHeaders() {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        dayHeaderStack.axis = .horizontal
        dayHeaderStack.distribution = .fillEqually
        dayHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        for day in days {
            let label = UILabel()
            label.text = day
            label.font = DesignTokens.Typography.caption2
            label.textColor = DesignTokens.Colors.textTertiary
            label.textAlignment = .center
            dayHeaderStack.addArrangedSubview(label)
        }

        view.addSubview(dayHeaderStack)
        NSLayoutConstraint.activate([
            dayHeaderStack.topAnchor.constraint(equalTo: calendarContentTop, constant: DesignTokens.Spacing.sm),
            dayHeaderStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            dayHeaderStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            dayHeaderStack.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    // MARK: - Calendar Grid

    private func setupCalendar() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / 7.0),
                heightDimension: .absolute(44)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(44)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: Array(repeating: item, count: 7))
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.xs,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.sm,
                trailing: DesignTokens.Spacing.lg
            )
            return section
        }

        calendarCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        calendarCollectionView.backgroundColor = .clear
        calendarCollectionView.isScrollEnabled = false
        calendarCollectionView.delegate = self
        calendarCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(calendarCollectionView)

        // 6 rows max × 44pt = 264, plus insets
        let calendarHeight: CGFloat = 6 * 44 + DesignTokens.Spacing.xs + DesignTokens.Spacing.sm

        NSLayoutConstraint.activate([
            calendarCollectionView.topAnchor.constraint(equalTo: dayHeaderStack.bottomAnchor, constant: DesignTokens.Spacing.xs),
            calendarCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            calendarCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            calendarCollectionView.heightAnchor.constraint(equalToConstant: calendarHeight),
        ])
    }

    // MARK: - Detail Panel

    private func setupDetailPanel() {
        // Separator line
        separator.backgroundColor = DesignTokens.Colors.surfaceSecondary
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)

        // Scroll view for detail content
        detailScroll.translatesAutoresizingMaskIntoConstraints = false
        detailScroll.alwaysBounceVertical = true
        view.addSubview(detailScroll)

        // Vertical stack
        detailStack.axis = .vertical
        detailStack.spacing = DesignTokens.Spacing.md
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailScroll.addSubview(detailStack)

        // Date label
        selectedDateLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .semibold)
        selectedDateLabel.textColor = DesignTokens.Colors.textPrimary
        detailStack.addArrangedSubview(selectedDateLabel)

        // Rating row
        setupRatingRow()

        // Tags
        tagsStack.axis = .horizontal
        tagsStack.spacing = DesignTokens.Spacing.xs
        tagsStack.distribution = .fill
        detailStack.addArrangedSubview(tagsStack)

        // Diary text
        diaryLabel.font = DesignTokens.Typography.body
        diaryLabel.textColor = DesignTokens.Colors.textSecondary
        diaryLabel.numberOfLines = 0
        detailStack.addArrangedSubview(diaryLabel)

        // Edit button
        var editConfig = UIButton.Configuration.filled()
        editConfig.title = "Edit Entry"
        editConfig.image = UIImage(systemName: "pencil")
        editConfig.imagePadding = DesignTokens.Spacing.xs
        editConfig.cornerStyle = .large
        editConfig.baseBackgroundColor = DesignTokens.Colors.accent
        editConfig.baseForegroundColor = DesignTokens.Colors.textPrimary
        editButton.configuration = editConfig
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        detailStack.addArrangedSubview(editButton)

        // Create button (shown when no entry exists)
        var createConfig = UIButton.Configuration.filled()
        createConfig.title = "Create Entry"
        createConfig.image = UIImage(systemName: "plus.circle.fill")
        createConfig.imagePadding = DesignTokens.Spacing.xs
        createConfig.cornerStyle = .large
        createConfig.baseBackgroundColor = DesignTokens.Colors.accent
        createConfig.baseForegroundColor = DesignTokens.Colors.textPrimary
        createButton.configuration = createConfig
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        detailStack.addArrangedSubview(createButton)

        // Empty state
        emptyStateLabel.text = "No entry for this day"
        emptyStateLabel.font = DesignTokens.Typography.subheadline
        emptyStateLabel.textColor = DesignTokens.Colors.textTertiary
        emptyStateLabel.textAlignment = .center
        detailStack.addArrangedSubview(emptyStateLabel)

        // Spacer at bottom
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: DesignTokens.Spacing.xxxl).isActive = true
        detailStack.addArrangedSubview(spacer)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: calendarCollectionView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            separator.heightAnchor.constraint(equalToConstant: 1),

            detailScroll.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: DesignTokens.Spacing.md),
            detailScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            detailStack.topAnchor.constraint(equalTo: detailScroll.topAnchor),
            detailStack.leadingAnchor.constraint(equalTo: detailScroll.leadingAnchor, constant: DesignTokens.Spacing.xl),
            detailStack.trailingAnchor.constraint(equalTo: detailScroll.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            detailStack.bottomAnchor.constraint(equalTo: detailScroll.bottomAnchor),
            detailStack.widthAnchor.constraint(equalTo: detailScroll.widthAnchor, constant: -DesignTokens.Spacing.xl * 2),
        ])
    }

    private func setupRatingRow() {
        ratingContainer.translatesAutoresizingMaskIntoConstraints = false

        let ratingTitleLabel = UILabel()
        ratingTitleLabel.text = "Rating"
        ratingTitleLabel.font = DesignTokens.Typography.caption1
        ratingTitleLabel.textColor = DesignTokens.Colors.textTertiary
        ratingTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        ratingValueLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        ratingValueLabel.textColor = DesignTokens.Colors.accent
        ratingValueLabel.translatesAutoresizingMaskIntoConstraints = false

        // Bar background
        ratingBar.backgroundColor = DesignTokens.Colors.surfaceSecondary
        ratingBar.layer.cornerRadius = 4
        ratingBar.clipsToBounds = true
        ratingBar.translatesAutoresizingMaskIntoConstraints = false

        ratingFill.backgroundColor = DesignTokens.Colors.accent
        ratingFill.layer.cornerRadius = 4
        ratingFill.translatesAutoresizingMaskIntoConstraints = false
        ratingBar.addSubview(ratingFill)

        ratingContainer.addSubview(ratingTitleLabel)
        ratingContainer.addSubview(ratingValueLabel)
        ratingContainer.addSubview(ratingBar)

        NSLayoutConstraint.activate([
            ratingTitleLabel.topAnchor.constraint(equalTo: ratingContainer.topAnchor),
            ratingTitleLabel.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor),

            ratingValueLabel.topAnchor.constraint(equalTo: ratingTitleLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            ratingValueLabel.leadingAnchor.constraint(equalTo: ratingContainer.leadingAnchor),

            ratingBar.centerYAnchor.constraint(equalTo: ratingValueLabel.centerYAnchor),
            ratingBar.leadingAnchor.constraint(equalTo: ratingValueLabel.trailingAnchor, constant: DesignTokens.Spacing.md),
            ratingBar.trailingAnchor.constraint(equalTo: ratingContainer.trailingAnchor),
            ratingBar.heightAnchor.constraint(equalToConstant: 8),

            ratingFill.topAnchor.constraint(equalTo: ratingBar.topAnchor),
            ratingFill.bottomAnchor.constraint(equalTo: ratingBar.bottomAnchor),
            ratingFill.leadingAnchor.constraint(equalTo: ratingBar.leadingAnchor),

            ratingContainer.bottomAnchor.constraint(equalTo: ratingValueLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            ratingContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
        ])

        detailStack.addArrangedSubview(ratingContainer)
    }

    // MARK: - Data Source

    private func configureCalendarDataSource() {
        let cellReg = UICollectionView.CellRegistration<CalendarDayCell, CalendarDay> { [weak self] cell, _, day in
            cell.configure(with: day, isSelected: day.date == self?.selectedDate)
        }

        calendarDataSource = UICollectionViewDiffableDataSource(collectionView: calendarCollectionView) { cv, indexPath, day in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: day)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        let observation = ValueObservation.tracking { db -> [DayEntry] in
            try DayEntry.fetchAll(db)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] entries in
            self?.rebuildCalendar(entries: entries)
        })
    }

    private func rebuildCalendar(entries: [DayEntry]) {
        let cal = Calendar.current
        let today = Date.now
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) else { return }

        let weekday = cal.component(.weekday, from: monthStart)
        let mondayOffset = (weekday + 5) % 7

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        entryCache = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0) })

        let range = cal.range(of: .day, in: .month, for: monthStart)!
        var days: [CalendarDay] = []

        for i in 0..<mondayOffset {
            days.append(CalendarDay(date: "pad-\(i)", rating: nil, dayOfMonth: 0, isEmpty: true, entryId: nil))
        }

        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dateStr = fmt.string(from: date)
            let entry = entryCache[dateStr]
            days.append(CalendarDay(date: dateStr, rating: entry?.rating, dayOfMonth: day, isEmpty: false, entryId: entry?.id))
        }

        allDays = days

        var snapshot = NSDiffableDataSourceSnapshot<CalendarSection, CalendarDay>()
        snapshot.appendSections([.main])
        snapshot.appendItems(days)
        calendarDataSource.apply(snapshot, animatingDifferences: false)

        // Reconfigure to pick up rating changes (equality is date-only)
        var reconfigSnap = calendarDataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        calendarDataSource.apply(reconfigSnap, animatingDifferences: false)

        // Refresh the detail panel if a day is selected
        if selectedDate != nil {
            updateDetailPanel()
        }
    }

    // MARK: - Selection

    private var ratingFillWidth: NSLayoutConstraint?

    private func selectDay(_ date: String) {
        selectedDate = date
        updateDetailPanel()
        reconfigureCalendarCells()
    }

    private func updateDetailPanel() {
        guard let date = selectedDate else { return }

        // Format date for display
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "EEEE, MMMM d"
        if let d = fmt.date(from: date) {
            selectedDateLabel.text = displayFmt.string(from: d)
        } else {
            selectedDateLabel.text = date
        }

        if let entry = entryCache[date] {
            // Has entry — show details
            ratingContainer.isHidden = entry.rating == nil
            if let rating = entry.rating {
                ratingValueLabel.text = "\(rating)/10"
                let fraction = CGFloat(rating) / 10.0
                ratingFillWidth?.isActive = false
                ratingFillWidth = ratingFill.widthAnchor.constraint(equalTo: ratingBar.widthAnchor, multiplier: max(0.01, fraction))
                ratingFillWidth?.isActive = true

                // Color based on rating
                let newColor: UIColor
                if rating >= 7 {
                    newColor = DesignTokens.Colors.success
                } else if rating >= 4 {
                    newColor = DesignTokens.Colors.warning
                } else {
                    newColor = DesignTokens.Colors.destructive
                }

                // Animate bar width + color
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 5, options: .curveEaseOut) {
                    self.ratingFill.backgroundColor = newColor
                    self.ratingValueLabel.textColor = newColor
                    self.ratingBar.superview?.layoutIfNeeded()
                }
            }

            // Tags
            tagsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            tagsStack.isHidden = entry.tags.isEmpty
            for tag in entry.tags {
                let chip = PillLabel()
                chip.text = tag
                chip.font = DesignTokens.Typography.caption2
                chip.textColor = DesignTokens.Colors.accent
                chip.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
                chip.layer.cornerRadius = 10
                chip.clipsToBounds = true
                chip.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
                tagsStack.addArrangedSubview(chip)
            }
            // Flexible spacer so chips don't stretch
            tagsStack.addArrangedSubview(UIView())

            diaryLabel.text = entry.diary.isEmpty ? "No diary text." : entry.diary
            diaryLabel.isHidden = false
            editButton.isHidden = false
            createButton.isHidden = true
            emptyStateLabel.isHidden = true
        } else {
            // No entry
            ratingContainer.isHidden = true
            tagsStack.isHidden = true
            diaryLabel.isHidden = true
            editButton.isHidden = true
            createButton.isHidden = false
            emptyStateLabel.isHidden = false
        }

        view.layoutIfNeeded()
    }

    private func reconfigureCalendarCells() {
        var snapshot = calendarDataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        calendarDataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Actions

    @objc private func editTapped() {
        guard let date = selectedDate, let entry = entryCache[date] else { return }
        onEditEntry?(entry.id)
    }

    @objc private func createTapped() {
        guard let date = selectedDate else { return }
        onCreateEntry?(date)
    }
}

// MARK: - UICollectionViewDelegate

extension CalendarViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let day = calendarDataSource.itemIdentifier(for: indexPath), !day.isEmpty else { return }
        selectDay(day.date)
    }
}

// MARK: - CalendarDayCell

private final class CalendarDayCell: InteractiveCell {

    private let dayLabel = UILabel()
    private let dot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true

        dayLabel.font = DesignTokens.Typography.subheadline
        dayLabel.textAlignment = .center
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dot)

        NSLayoutConstraint.activate([
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -3),

            dot.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dot.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    func configure(with day: CalendarDay, isSelected: Bool) {
        if day.isEmpty {
            dayLabel.text = nil
            dot.isHidden = true
            contentView.backgroundColor = .clear
            return
        }

        dayLabel.text = "\(day.dayOfMonth)"

        // Dot indicates entry exists, colored by rating
        dot.isHidden = day.entryId == nil
        if let rating = day.rating {
            if rating >= 7 {
                dot.backgroundColor = DesignTokens.Colors.success
            } else if rating >= 4 {
                dot.backgroundColor = DesignTokens.Colors.warning
            } else {
                dot.backgroundColor = DesignTokens.Colors.destructive
            }
        } else {
            dot.backgroundColor = DesignTokens.Colors.textTertiary
        }

        // Selection state
        if isSelected {
            contentView.backgroundColor = DesignTokens.Colors.accent
            dayLabel.textColor = DesignTokens.Colors.textPrimary
            dayLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .bold)
        } else if day.entryId != nil {
            contentView.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
            dayLabel.textColor = DesignTokens.Colors.textPrimary
            dayLabel.font = DesignTokens.Typography.subheadline
        } else {
            contentView.backgroundColor = .clear
            dayLabel.textColor = DesignTokens.Colors.textSecondary
            dayLabel.font = DesignTokens.Typography.subheadline
        }
    }
}

// MARK: - PillLabel

private final class PillLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
