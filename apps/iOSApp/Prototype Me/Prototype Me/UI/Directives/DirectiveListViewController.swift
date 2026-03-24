import UIKit
import GRDB

nonisolated private enum DirectiveListSection: Sendable { case main }

nonisolated private enum DirectiveFilter: Int, CaseIterable, Sendable {
    case all, active, archived
    var title: String {
        switch self {
        case .all: "All"
        case .active: "Active"
        case .archived: "Archived"
        }
    }
}

class DirectiveListViewController: BaseViewController {

    var onDirectiveSelected: ((UUID) -> Void)?
    var onAddTapped: (() -> Void)?
    var isEmbedded = false

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DirectiveListSection, DirectiveRowData>!
    private var allItems: [DirectiveRowData] = []
    private var currentFilter: DirectiveFilter = .all

    override func viewDidLoad() {
        if isEmbedded { hidesNavBar = true }
        super.viewDidLoad()
        if !isEmbedded {
            navBar.setRightButtons([
                NavBarButton(systemImage: "plus", action: { [weak self] in self?.addTapped() }),
            ])
        }
        configureSegmentedControl()
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Segmented Control

    private func configureSegmentedControl() {
        let segmented = UISegmentedControl(items: DirectiveFilter.allCases.map(\.title))
        segmented.selectedSegmentIndex = 0
        segmented.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
        navBar.setTitleView(segmented)
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
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
            guard let self, let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                self.confirmDelete(directiveId: item.directive.id)
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

    private func confirmDelete(directiveId: UUID) {
        let alert = UIAlertController(title: "Delete Directive", message: "This will also remove linked schedules and history.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            try? self?.dbQueue.write { db in
                _ = try Directive.deleteOne(db, key: directiveId)
            }
            Haptics.success()
        })
        present(alert, animated: true)
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, item in
            cell.configure(with: item)
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource<DirectiveListSection, DirectiveRowData>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        let observation = ValueObservation.tracking { db -> [DirectiveRowData] in
            let directives = try Directive.order(Column("createdAt").desc).fetchAll(db)
            let allRules = try ScheduleRule.fetchAll(db)
            return directives.map { dir in
                let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                return DirectiveRowData(
                    directive: dir,
                    scheduledToday: scheduled
                )
            }
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] items in
            self?.allItems = items
            self?.applyFilter()
        })
    }

    private func addTapped() { onAddTapped?() }

    @objc private func filterChanged(_ sender: UISegmentedControl) {
        currentFilter = DirectiveFilter(rawValue: sender.selectedSegmentIndex) ?? .all
        applyFilter()
    }

    private func applyFilter() {
        let filtered: [DirectiveRowData] = switch currentFilter {
        case .all:      allItems.filter { $0.directive.status != .archived }
        case .active:   allItems.filter { $0.directive.status == .active }
        case .archived: allItems.filter { $0.directive.status == .archived }
        }
        var snapshot = NSDiffableDataSourceSnapshot<DirectiveListSection, DirectiveRowData>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filtered)
        dataSource.apply(snapshot, animatingDifferences: true)

        // Force cell reconfiguration since model equality is id-only
        var reconfigSnap = dataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        dataSource.apply(reconfigSnap, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension DirectiveListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onDirectiveSelected?(item.directive.id)
    }
}
