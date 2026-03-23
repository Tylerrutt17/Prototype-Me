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
    var onProfileTapped: (() -> Void)?
    var onSubscriptionTapped: (() -> Void)?
    var onUsageTapped: (() -> Void)?
    var onFriendsTapped: (() -> Void)?
    var onReplayTourTapped: (() -> Void)?
    var onLegalTapped: ((String) -> Void)?    // passes "Terms of Service" or "Privacy Policy"

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SettingsSection, SettingsItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Settings", animated: false)

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
        collectionView.contentInset.top = DesignTokens.Spacing.xl
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
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SettingsItem> { [weak self] cell, indexPath, item in
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
            if case .toggle(let title, let isOn) = item {
                let toggle = UISwitch()
                toggle.isOn = isOn
                toggle.onTintColor = DesignTokens.Colors.accent
                toggle.addTarget(self, action: #selector(self?.settingsToggleChanged(_:)), for: .valueChanged)
                // Tag toggles by title for identification
                switch title {
                case "Dark Mode": toggle.tag = 1
                case "Haptic Feedback": toggle.tag = 2
                case "Balloon Notifications": toggle.tag = 3
                default: break
                }
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
        snapshot.appendItems([
            .account("Tyler Morrow"),
            .navigation("Subscription"),
            .navigation("AI Usage"),
            .navigation("Friends"),
        ], toSection: .account)

        snapshot.appendSections([.preferences])
        snapshot.appendItems([
            .toggle("Haptic Feedback", Haptics.isEnabled),
            .navigation("Replay Tour"),
        ], toSection: .preferences)

        snapshot.appendSections([.data])
        snapshot.appendItems([
            .navigation("Sync Debug"),
        ], toSection: .data)

        snapshot.appendSections([.about])
        snapshot.appendItems([
            .info("Version", "0.1.0"),
            .info("Build", "1"),
            .navigation("Terms of Service"),
            .navigation("Privacy Policy"),
        ], toSection: .about)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension SettingsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .account:
            onProfileTapped?()
        case .navigation(let title):
            switch title {
            case "Sync Debug":    onSyncDebugTapped?()
            case "Subscription":  onSubscriptionTapped?()
            case "AI Usage":      onUsageTapped?()
            case "Friends":       onFriendsTapped?()
            case "Replay Tour":       onReplayTourTapped?()
            case "Terms of Service":  onLegalTapped?("Terms of Service")
            case "Privacy Policy":    onLegalTapped?("Privacy Policy")
            default: break
            }
        default:
            break
        }
    }
}

// MARK: - Toggle Handlers

extension SettingsViewController {
    @objc func settingsToggleChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 1: // Dark Mode
            UserDefaults.standard.set(sender.isOn, forKey: "darkModeEnabled")
            let style: UIUserInterfaceStyle = sender.isOn ? .dark : .light
            view.window?.overrideUserInterfaceStyle = style
        case 2: // Haptic Feedback
            Haptics.isEnabled = sender.isOn
        default:
            break
        }
    }
}
