import UIKit

nonisolated private enum SyncDebugSection: Sendable { case main }

nonisolated private enum SyncDebugItem: Hashable, Sendable {
    case stat(String, String)
    case action(String)
}

class SyncDebugViewController: BaseViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SyncDebugSection, SyncDebugItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Sync Debug"

        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = DesignTokens.Colors.background
        let layout = UICollectionViewCompositionalLayout.list(using: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
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

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SyncDebugItem> { cell, _, item in
            var content = UIListContentConfiguration.cell()
            content.textProperties.color = DesignTokens.Colors.textPrimary

            switch item {
            case .stat(let label, let value):
                content.text = label
                content.secondaryText = value
                content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary
            case .action(let title):
                content.text = title
                content.textProperties.color = DesignTokens.Colors.accent
                content.textProperties.alignment = .center
            }

            cell.contentConfiguration = content

            var bg = UIBackgroundConfiguration.listCell()
            bg.backgroundColor = DesignTokens.Colors.surfacePrimary
            cell.backgroundConfiguration = bg
        }

        dataSource = UICollectionViewDiffableDataSource<SyncDebugSection, SyncDebugItem>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        var snapshot = NSDiffableDataSourceSnapshot<SyncDebugSection, SyncDebugItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems([
            .stat("Last Push", "2 minutes ago"),
            .stat("Last Pull", "5 minutes ago"),
            .stat("Outbox Queue", "0 pending"),
            .stat("Device ID", "iPhone-15-Pro"),
            .stat("Sync Token", "abc123...def456"),
            .stat("Schema Version", "v4"),
            .action("Force Sync Now"),
        ])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension SyncDebugViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .action = item {
            // Placeholder: would trigger sync
            let alert = UIAlertController(title: "Sync", message: "Force sync triggered (dummy)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
