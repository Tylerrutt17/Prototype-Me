import UIKit

nonisolated private enum SettingsSection: Int, Hashable, Sendable {
    case account
    case preferences
    case guides
    case data
    case about
}

nonisolated private enum SettingsItem: Hashable, Sendable {
    case account(String)
    case toggle(String, Bool, String, Int)   // title, isOn, iconName, colorIndex
    case navigation(String, String, Int)     // title, iconName, colorIndex
    case info(String, String, String, Int)   // title, value, iconName, colorIndex
}

private let settingsIconColors: [UIColor] = [
    DesignTokens.Colors.accent,           // 0 blue
    DesignTokens.Colors.accentSecondary,  // 1 green
    DesignTokens.Colors.accentTertiary,   // 2 orange
    DesignTokens.Colors.destructive,      // 3 red
    DesignTokens.Colors.warning,          // 4 yellow
    UIColor.systemPurple,                 // 5 purple
    UIColor.systemPink,                   // 6 pink
    UIColor.systemTeal,                   // 7 teal
]

class SettingsViewController: BaseViewController {

    var onSyncDebugTapped: (() -> Void)?
    var onProfileTapped: (() -> Void)?
    var onSubscriptionTapped: (() -> Void)?
    var onUsageTapped: (() -> Void)?
    var onFriendsTapped: (() -> Void)?
    var onReplayTourTapped: (() -> Void)?
    var onReplayIntroTapped: (() -> Void)?
    var onLegalTapped: ((String) -> Void)?    // passes "Terms of Service" or "Privacy Policy"
    var syncEngine: SyncEngine?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SettingsSection, SettingsItem>!
    private let syncBanner = SyncStatusBannerView()

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Settings", animated: false)

        configureSyncBanner()
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshSyncStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(syncDidComplete), name: .syncDidComplete, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .syncDidComplete, object: nil)
    }

    @objc private func syncDidComplete() {
        refreshSyncStatus()
    }

    // MARK: - Sync Banner

    private func configureSyncBanner() {
        syncBanner.isHidden = !AuthService.isPro
        syncBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(syncBanner)

        NSLayoutConstraint.activate([
            syncBanner.topAnchor.constraint(equalTo: contentTopAnchor, constant: DesignTokens.Spacing.md),
            syncBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            syncBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    private func refreshSyncStatus() {
        guard AuthService.isPro, let syncEngine else {
            syncBanner.isHidden = true
            return
        }
        syncBanner.isHidden = false
        Task {
            let info = try? await syncEngine.debugInfo()
            await MainActor.run {
                let outbox = info?.outboxCount ?? 0
                if let error = info?.lastError {
                    syncBanner.configure(state: .error(error))
                } else if outbox > 0 {
                    syncBanner.configure(state: .pending(outbox))
                } else {
                    syncBanner.configure(state: .synced)
                }
            }
        }
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
            collectionView.topAnchor.constraint(equalTo: syncBanner.bottomAnchor, constant: DesignTokens.Spacing.sm),
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

            func badgedIcon(_ systemName: String, color: UIColor) -> UIImage? {
                let size: CGFloat = 34
                let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                guard let symbol = UIImage(systemName: systemName, withConfiguration: iconConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal) else { return nil }
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
                return renderer.image { ctx in
                    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 7)
                    color.setFill()
                    path.fill()
                    let symbolSize = symbol.size
                    let x = (size - symbolSize.width) / 2
                    let y = (size - symbolSize.height) / 2
                    symbol.draw(in: CGRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height))
                }
            }

            switch item {
            case .account(let title):
                content.text = title
                content.image = badgedIcon("person.circle", color: DesignTokens.Colors.accent)
            case .toggle(let title, _, let icon, let colorIdx):
                content.text = title
                content.image = badgedIcon(icon, color: settingsIconColors[colorIdx])
            case .navigation(let title, let icon, let colorIdx):
                content.text = title
                content.image = badgedIcon(icon, color: settingsIconColors[colorIdx])
                cell.accessories = [.disclosureIndicator()]
            case .info(let title, let value, let icon, let colorIdx):
                content.text = title
                content.secondaryText = value
                content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary
                content.image = badgedIcon(icon, color: settingsIconColors[colorIdx])
            }

            cell.contentConfiguration = content

            var bg = UIBackgroundConfiguration.listCell()
            bg.backgroundColor = DesignTokens.Colors.surfacePrimary
            cell.backgroundConfiguration = bg

            // Add toggle for toggle items
            if case .toggle(let title, let isOn, _, _) = item {
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
            case .guides:      "Guides"
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
            .navigation("Subscription", "creditcard", 0),          // blue
            .navigation("Prototype Usage", "sparkles", 0),                // blue
            .navigation("Friends", "person.2", 0),                 // blue
        ], toSection: .account)

        snapshot.appendSections([.preferences])
        snapshot.appendItems([
            .toggle("Haptic Feedback", Haptics.isEnabled, "hand.tap", 1),  // green
        ], toSection: .preferences)

        snapshot.appendSections([.guides])
        snapshot.appendItems([
            .navigation("Replay Tour", "map", 2),                          // orange
            .navigation("Replay Intro", "play.circle", 2),                 // orange
        ], toSection: .guides)

        snapshot.appendSections([.data])
        snapshot.appendItems([
            .navigation("Sync Debug", "arrow.triangle.2.circlepath", 1),   // green
        ], toSection: .data)

        snapshot.appendSections([.about])
        snapshot.appendItems([
            .navigation("Contact Support", "envelope", 0),         // blue
            .info("Version", "0.1.0", "info.circle", 5),          // purple
            .info("Build", "1", "hammer", 5),                      // purple
            .navigation("Terms of Service", "doc.text", 5),        // purple
            .navigation("Privacy Policy", "lock.shield", 5),       // purple
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
        case .navigation(let title, _, _):
            switch title {
            case "Sync Debug":    onSyncDebugTapped?()
            case "Subscription":  onSubscriptionTapped?()
            case "Prototype Usage":   onUsageTapped?()
            case "Friends":       onFriendsTapped?()
            case "Replay Tour":       onReplayTourTapped?()
            case "Replay Intro":      onReplayIntroTapped?()
            case "Contact Support":   SupportMailer.present(from: self)
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
