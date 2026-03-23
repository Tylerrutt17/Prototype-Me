import UIKit
import GRDB

nonisolated private enum DiarySection: Int, Hashable, Sendable {
    case createToday
    case entries
}

nonisolated private enum DiaryItem: Hashable, Sendable {
    case createTodayPrompt
    case entry(DayEntrySummary)
}

class DiaryViewController: BaseViewController {

    var onAddTapped: (() -> Void)?
    var onEntrySelected: ((UUID) -> Void)?
    var onHistoryTapped: (() -> Void)?
    /// Calendar: edit existing entry
    var onEditEntry: ((UUID) -> Void)?
    /// Calendar: create entry for date
    var onCreateEntry: ((String) -> Void)?

    // MARK: - Tab Bar

    private let segmentedControl = UISegmentedControl(items: ["List", "Calendar"])
    private var calendarVC: CalendarViewController?

    // MARK: - List UI

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DiarySection, DiaryItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Diary", animated: false)
        navBar.setRightButtons([
            NavBarButton(systemImage: "plus", action: { [weak self] in self?.addTapped() }),
            NavBarButton(systemImage: "chart.bar.fill", action: { [weak self] in self?.historyTapped() }),
        ])

        setupSegmentedControl()
        configureCollectionView()
        collectionView.delegate = self
        configureDataSource()
        loadData()
        embedCalendar()

        // Start on list
        segmentedControl.selectedSegmentIndex = 0
        showTab(0)
    }

    // MARK: - Segmented Control

    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentTintColor = DesignTokens.Colors.accent
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: DesignTokens.Colors.textPrimary,
            .font: DesignTokens.Typography.subheadline,
        ], for: .selected)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: DesignTokens.Colors.textSecondary,
            .font: DesignTokens.Typography.subheadline,
        ], for: .normal)
        segmentedControl.backgroundColor = DesignTokens.Colors.surfaceSecondary
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        view.addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.xs),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @objc private func segmentChanged() {
        showTab(segmentedControl.selectedSegmentIndex)
    }

    private func showTab(_ index: Int) {
        let showList = index == 0
        collectionView.isHidden = !showList
        calendarVC?.view.isHidden = showList
    }

    // MARK: - Embed Calendar

    private func embedCalendar() {
        let cal = CalendarViewController()
        cal.embedded = true
        cal.dbQueue = dbQueue
        cal.onEditEntry = { [weak self] entryId in
            self?.onEditEntry?(entryId)
        }
        cal.onCreateEntry = { [weak self] dateString in
            self?.onCreateEntry?(dateString)
        }

        addChild(cal)
        cal.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cal.view)

        NSLayoutConstraint.activate([
            cal.view.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: DesignTokens.Spacing.xs),
            cal.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cal.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cal.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        cal.didMove(toParent: self)
        calendarVC = cal
    }

    // MARK: - Collection View (List)

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: DesignTokens.Spacing.xs),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let item = self.dataSource.itemIdentifier(for: indexPath),
                  case .entry(let summary) = item else { return nil }
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                self.confirmDelete(entryId: summary.entry.id)
                completion(true)
            }
            deleteAction.backgroundColor = DesignTokens.Colors.destructive
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        return UICollectionViewCompositionalLayout { _, layoutEnv in
            let sectionConfig = config
            let section = NSCollectionLayoutSection.list(using: sectionConfig, layoutEnvironment: layoutEnv)
            section.interGroupSpacing = DesignTokens.Spacing.sm
            section.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.lg,
                trailing: DesignTokens.Spacing.lg
            )
            return section
        }
    }

    private func confirmDelete(entryId: UUID) {
        let alert = UIAlertController(title: "Delete Entry", message: "Are you sure you want to delete this diary entry?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            try? self?.dbQueue.write { db in
                _ = try DayEntry.deleteOne(db, key: entryId)
            }
            Haptics.success()
        })
        present(alert, animated: true)
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let createTodayReg = UICollectionView.CellRegistration<CreateTodayCell, DiaryItem> { cell, _, _ in
            cell.configure()
        }

        let entryReg = UICollectionView.CellRegistration<DayEntryCell, DayEntrySummary> { cell, _, item in
            cell.configure(with: item)
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource<DiarySection, DiaryItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .createTodayPrompt:
                return collectionView.dequeueConfiguredReusableCell(using: createTodayReg, for: indexPath, item: item)
            case .entry(let summary):
                return collectionView.dequeueConfiguredReusableCell(using: entryReg, for: indexPath, item: summary)
            }
        }
    }

    // MARK: - Observe Data

    private static var todayDateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: .now)
    }

    private func loadData() {
        let observation = ValueObservation.tracking { db -> [DayEntrySummary] in
            let entries = try DayEntry.order(Column("date").desc).fetchAll(db)
            return entries.map { entry in
                DayEntrySummary(
                    entry: entry,
                    tagNames: entry.tags,
                    diaryPreview: String(entry.diary.prefix(100))
                )
            }
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] items in
            let today = Self.todayDateString
            let hasTodayEntry = items.contains { $0.entry.date == today }

            var snapshot = NSDiffableDataSourceSnapshot<DiarySection, DiaryItem>()

            if !hasTodayEntry {
                snapshot.appendSections([.createToday])
                snapshot.appendItems([.createTodayPrompt], toSection: .createToday)
            }

            snapshot.appendSections([.entries])
            snapshot.appendItems(items.map { .entry($0) }, toSection: .entries)
            self?.dataSource.apply(snapshot, animatingDifferences: true)

            // Force cell reconfiguration — equality is id-only so content changes
            // (edited diary text, rating, tags) need an explicit reconfigure pass.
            if let ds = self?.dataSource {
                var reconfig = ds.snapshot()
                reconfig.reconfigureItems(reconfig.itemIdentifiers)
                ds.apply(reconfig, animatingDifferences: false)
            }
        })
    }

    private func addTapped() { onAddTapped?() }
    private func historyTapped() { onHistoryTapped?() }
}

// MARK: - UICollectionViewDelegate

extension DiaryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .createTodayPrompt:
            onAddTapped?()
        case .entry(let summary):
            onEntrySelected?(summary.entry.id)
        }
    }
}

// MARK: - CreateTodayCell

private final class CreateTodayCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.layer.borderWidth = 1.5
        contentView.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor
        contentView.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.text = "Start Today's Entry"
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let hStack = UIStackView(arrangedSubviews: [iconView, textStack, UIView()])
        hStack.axis = .horizontal
        hStack.spacing = DesignTokens.Spacing.md
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 36),
            hStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            hStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            hStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            hStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure() {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        subtitleLabel.text = fmt.string(from: .now)
    }
}
