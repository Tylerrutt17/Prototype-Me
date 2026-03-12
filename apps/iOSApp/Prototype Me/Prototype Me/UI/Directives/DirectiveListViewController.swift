import UIKit

nonisolated private enum DirectiveListSection: Sendable { case main }

nonisolated private enum DirectiveFilter: Int, CaseIterable, Sendable {
    case all, active, maintained
    var title: String {
        switch self {
        case .all: "All"
        case .active: "Active"
        case .maintained: "Maintained"
        }
    }
}

class DirectiveListViewController: BaseViewController {

    var onDirectiveSelected: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DirectiveListSection, DirectiveRowData>!
    private var allItems: [DirectiveRowData] = []
    private var currentFilter: DirectiveFilter = .all

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Directives"

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
        navigationItem.titleView = segmented
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
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

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, item in
            cell.configure(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource<DirectiveListSection, DirectiveRowData>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        allItems = SampleData.directiveRowData  // Future: ValueObservation
        applyFilter()
    }

    @objc private func filterChanged(_ sender: UISegmentedControl) {
        currentFilter = DirectiveFilter(rawValue: sender.selectedSegmentIndex) ?? .all
        applyFilter()
    }

    private func applyFilter() {
        let filtered: [DirectiveRowData] = switch currentFilter {
        case .all:        allItems.filter { $0.directive.status != .retired }
        case .active:     allItems.filter { $0.directive.status == .active }
        case .maintained: allItems.filter { $0.directive.status == .maintained }
        }
        var snapshot = NSDiffableDataSourceSnapshot<DirectiveListSection, DirectiveRowData>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filtered)
        dataSource.apply(snapshot, animatingDifferences: true)
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
