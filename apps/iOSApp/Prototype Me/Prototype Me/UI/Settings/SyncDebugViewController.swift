import UIKit

nonisolated private enum SyncDebugSection: Sendable { case main }

nonisolated private enum SyncDebugItem: Hashable, Sendable {
    case stat(String, String)
    case action(String)
}

class SyncDebugViewController: BaseViewController {

    var syncEngine: SyncEngine?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SyncDebugSection, SyncDebugItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Sync Debug", animated: false)

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
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
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
        Task { @MainActor in
            let info = try? await syncEngine?.debugInfo()
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .medium

            var snapshot = NSDiffableDataSourceSnapshot<SyncDebugSection, SyncDebugItem>()
            snapshot.appendSections([.main])
            snapshot.appendItems([
                .stat("Outbox Queue", "\(info?.outboxCount ?? 0) pending"),
                .stat("Last Push", info?.lastPushAt.map { fmt.string(from: $0) } ?? "Never"),
                .stat("Last Pull", info?.lastPullAt.map { fmt.string(from: $0) } ?? "Never"),
                .stat("Sync Token", info?.lastSyncToken.map { String($0.prefix(16)) + "…" } ?? "None"),
                .stat("Device ID", String((info?.deviceId ?? "Unknown").prefix(20))),
                .stat("Last Error", info?.lastError ?? "None"),
                .stat("Schema Version", "v6"),
                .action("Force Sync Now"),
            ])
            await dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
}

// MARK: - UICollectionViewDelegate

extension SyncDebugViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .action = item {
            Task {
                do {
                    try await syncEngine?.sync()
                    loadData()  // Refresh after sync
                } catch {
                    let alert = UIAlertController(title: "Sync Failed", message: "\(error)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
}
