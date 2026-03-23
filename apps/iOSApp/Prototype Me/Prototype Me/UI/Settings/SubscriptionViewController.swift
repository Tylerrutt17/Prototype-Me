import UIKit

/// Settings sub-screen showing current plan details, Pro badge, manage/restore.
class SubscriptionViewController: BaseViewController {

    var subscriptionInfo: SubscriptionInfo!
    var usageQuota: UsageQuota!
    var onUpgradeTapped: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SubscriptionSection, SubscriptionItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Subscription", animated: false)
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
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, SubscriptionItem> { cell, _, item in
            var content = UIListContentConfiguration.cell()
            content.textProperties.color = DesignTokens.Colors.textPrimary

            switch item {
            case .planBadge(let plan):
                content.text = plan == .pro ? "Pro" : "Free"
                content.secondaryText = plan == .pro ? "All features unlocked" : "Basic features"
                content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary
                let imageName = plan == .pro ? "crown.fill" : "person.circle"
                content.image = UIImage(systemName: imageName)
                content.imageProperties.tintColor = plan == .pro ? DesignTokens.Colors.accentTertiary : DesignTokens.Colors.textTertiary

            case .info(let title, let value):
                content.text = title
                content.secondaryText = value
                content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary

            case .action(let title):
                content.text = title
                content.textProperties.color = DesignTokens.Colors.accent
                cell.accessories = [.disclosureIndicator()]

            case .destructiveAction(let title):
                content.text = title
                content.textProperties.color = DesignTokens.Colors.destructive
            }

            cell.contentConfiguration = content
            var bg = UIBackgroundConfiguration.listCell()
            bg.backgroundColor = DesignTokens.Colors.surfacePrimary
            cell.backgroundConfiguration = bg
        }

        dataSource = UICollectionViewDiffableDataSource<SubscriptionSection, SubscriptionItem>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        let headerReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = SubscriptionSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .plan:    "Current Plan"
            case .details: "Details"
            case .actions: "Manage"
            case .none:    ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        let sub = subscriptionInfo!

        var snapshot = NSDiffableDataSourceSnapshot<SubscriptionSection, SubscriptionItem>()

        snapshot.appendSections([.plan])
        snapshot.appendItems([.planBadge(sub.plan)], toSection: .plan)

        snapshot.appendSections([.details])
        var details: [SubscriptionItem] = []
        if let expires = sub.expiresAt {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            details.append(.info("Renews", fmt.string(from: expires)))
        }
        if sub.isTrialActive, let days = sub.trialDaysRemaining {
            details.append(.info("Trial", "\(days) days remaining"))
        }
        details.append(.info("AI quota", "\(usageQuota.remaining) / \(usageQuota.dailyLimit) remaining today"))
        snapshot.appendItems(details, toSection: .details)

        snapshot.appendSections([.actions])
        var actions: [SubscriptionItem] = []
        if sub.plan == .free {
            actions.append(.action("Upgrade to Pro"))
        }
        actions.append(.action("Restore Purchases"))
        snapshot.appendItems(actions, toSection: .actions)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension SubscriptionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .action("Upgrade to Pro") = item {
            onUpgradeTapped?()
        }
    }
}

// MARK: - Section / Item enums

nonisolated private enum SubscriptionSection: Int, Hashable, Sendable {
    case plan
    case details
    case actions
}

nonisolated private enum SubscriptionItem: Hashable, Sendable {
    case planBadge(SubscriptionPlan)
    case info(String, String)
    case action(String)
    case destructiveAction(String)
}

// Uses shared SectionHeaderView from UI/Shared/Views/SectionHeaderView.swift
