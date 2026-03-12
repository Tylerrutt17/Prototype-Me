import UIKit

nonisolated private enum SettingsSection: Int, Hashable, Sendable {
    case account
    case preferences
    case data
    case about
}

nonisolated private enum SettingsItem: Hashable, Sendable {
    case account(String)
    case toggle(String, Bool)
    case navigation(String)
    case info(String, String)
}

class SettingsViewController: BaseViewController {

    var onSyncDebugTapped: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SettingsSection, SettingsItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true

        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = DesignTokens.Colors.background
        config.headerMode = .supplementary
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
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SettingsItem> { cell, indexPath, item in
            var content = UIListContentConfiguration.cell()
            content.textProperties.color = DesignTokens.Colors.textPrimary

            switch item {
            case .account(let title):
                content.text = title
                content.image = UIImage(systemName: "person.circle")
                content.imageProperties.tintColor = DesignTokens.Colors.accent
            case .toggle(let title, _):
                content.text = title
            case .navigation(let title):
                content.text = title
                cell.accessories = [.disclosureIndicator()]
            case .info(let title, let value):
                content.text = title
                content.secondaryText = value
                content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary
            }

            cell.contentConfiguration = content

            var bg = UIBackgroundConfiguration.listCell()
            bg.backgroundColor = DesignTokens.Colors.surfacePrimary
            cell.backgroundConfiguration = bg

            // Add toggle for toggle items
            if case .toggle(_, let isOn) = item {
                let toggle = UISwitch()
                toggle.isOn = isOn
                toggle.onTintColor = DesignTokens.Colors.accent
                cell.accessories = [.customView(configuration: .init(customView: toggle, placement: .trailing()))]
            }
        }

        dataSource = UICollectionViewDiffableDataSource<SettingsSection, SettingsItem>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        let headerReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = SettingsSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .account:     "Account"
            case .preferences: "Preferences"
            case .data:        "Data"
            case .about:       "About"
            case .none:        ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        var snapshot = NSDiffableDataSourceSnapshot<SettingsSection, SettingsItem>()

        snapshot.appendSections([.account])
        snapshot.appendItems([.account("Tyler Morrow")], toSection: .account)

        snapshot.appendSections([.preferences])
        snapshot.appendItems([
            .toggle("Dark Mode", true),
            .toggle("Haptic Feedback", true),
            .toggle("Balloon Notifications", true),
        ], toSection: .preferences)

        snapshot.appendSections([.data])
        snapshot.appendItems([
            .navigation("Sync Debug"),
        ], toSection: .data)

        snapshot.appendSections([.about])
        snapshot.appendItems([
            .info("Version", "0.1.0"),
            .info("Build", "1"),
        ], toSection: .about)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension SettingsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .navigation("Sync Debug") = item {
            onSyncDebugTapped?()
        }
    }
}
