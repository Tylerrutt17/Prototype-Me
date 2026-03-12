import UIKit

nonisolated private enum CalendarSection: Sendable { case main }

nonisolated private struct CalendarDay: Hashable, Sendable {
    let date: String          // yyyy-MM-dd or empty for padding
    let rating: Int?
    let dayOfMonth: Int
    let isEmpty: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(date) }
    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool { lhs.date == rhs.date }
}

class CalendarViewController: BaseViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<CalendarSection, CalendarDay>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Calendar"

        configureDayHeaders()
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Day Headers

    private let dayHeaderStack = UIStackView()

    private func configureDayHeaders() {
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
            dayHeaderStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.sm),
            dayHeaderStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            dayHeaderStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            dayHeaderStack.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: dayHeaderStack.bottomAnchor, constant: DesignTokens.Spacing.xs),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / 7.0), heightDimension: .fractionalWidth(1.0 / 7.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(1.0 / 7.0))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: Array(repeating: item, count: 7))
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.lg,
                trailing: DesignTokens.Spacing.lg
            )
            return section
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<CalendarDayCell, CalendarDay> { cell, _, day in
            cell.configure(with: day)
        }

        dataSource = UICollectionViewDiffableDataSource<CalendarSection, CalendarDay>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        let cal = Calendar.current
        let today = Date.now
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) else { return }

        let weekday = cal.component(.weekday, from: monthStart)
        // Convert to Mon=1..Sun=7
        let mondayOffset = (weekday + 5) % 7

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let entryMap = Dictionary(uniqueKeysWithValues: SampleData.dayEntries.map { ($0.date, $0.rating) })

        let range = cal.range(of: .day, in: .month, for: monthStart)!
        var days: [CalendarDay] = []

        // Leading empty days
        for i in 0..<mondayOffset {
            days.append(CalendarDay(date: "pad-\(i)", rating: nil, dayOfMonth: 0, isEmpty: true))
        }

        // Actual days
        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let dateStr = fmt.string(from: date)
            let rating = entryMap[dateStr] ?? nil
            days.append(CalendarDay(date: dateStr, rating: rating, dayOfMonth: day, isEmpty: false))
        }

        var snapshot = NSDiffableDataSourceSnapshot<CalendarSection, CalendarDay>()
        snapshot.appendSections([.main])
        snapshot.appendItems(days)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - CalendarDayCell

private final class CalendarDayCell: UICollectionViewCell {

    private let dayLabel = UILabel()
    private let ratingCircle = RatingCircleView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = .clear

        dayLabel.font = DesignTokens.Typography.caption2
        dayLabel.textColor = DesignTokens.Colors.textSecondary
        dayLabel.textAlignment = .center

        ratingCircle.diameter = 28

        let stack = UIStackView(arrangedSubviews: [dayLabel, ratingCircle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    func configure(with day: CalendarDay) {
        if day.isEmpty {
            dayLabel.text = nil
            ratingCircle.isHidden = true
            return
        }

        dayLabel.text = "\(day.dayOfMonth)"
        ratingCircle.isHidden = day.rating == nil
        ratingCircle.configure(rating: day.rating)
    }
}
