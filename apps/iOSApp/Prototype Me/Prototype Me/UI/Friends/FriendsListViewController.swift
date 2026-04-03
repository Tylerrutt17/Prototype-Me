import UIKit

/// Friends list with accepted friends and pending requests sections.
class FriendsListViewController: BaseViewController {

    var friends: [FriendItem]? { didSet { if isViewLoaded { loadData() } } }
    var onFriendTapped: ((FriendItem) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<FriendsSection, FriendItem>!
    private var emptyState: EmptyStateView?
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Friends", animated: false)
        navBar.setRightButtons([
            NavBarButton(systemImage: "person.badge.plus") { [weak self] in self?.addFriendTapped() }
        ])

        configureCollectionView()
        configureDataSource()
        if friends != nil {
            loadData()
        } else {
            spinner.color = DesignTokens.Colors.textSecondary
            spinner.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
            spinner.startAnimating()
        }
    }

    func showLoadError(_ message: String) {
        spinner.stopAnimating()
        spinner.removeFromSuperview()
        let label = UILabel()
        label.text = message
        label.font = DesignTokens.Typography.body
        label.textColor = DesignTokens.Colors.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        config.backgroundColor = DesignTokens.Colors.background
        config.headerMode = .supplementary

        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self,
                  let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }

            if item.status == .pending {
                let accept = UIContextualAction(style: .normal, title: "Accept") { _, _, completion in
                    // Placeholder — would call service
                    completion(true)
                }
                accept.backgroundColor = DesignTokens.Colors.success

                let decline = UIContextualAction(style: .destructive, title: "Decline") { _, _, completion in
                    completion(true)
                }
                return UISwipeActionsConfiguration(actions: [decline, accept])
            } else {
                let remove = UIContextualAction(style: .destructive, title: "Remove") { _, _, completion in
                    completion(true)
                }
                return UISwipeActionsConfiguration(actions: [remove])
            }
        }

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
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, FriendItem> { cell, _, friend in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = friend.displayName
            content.textProperties.color = DesignTokens.Colors.textPrimary

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .light)
            content.image = UIImage(systemName: friend.avatarSystemImage, withConfiguration: iconConfig)
            content.imageProperties.tintColor = DesignTokens.Colors.accent

            if friend.status == .pending {
                content.secondaryText = "Pending request"
                content.secondaryTextProperties.color = DesignTokens.Colors.accentTertiary
            } else if let since = friend.since {
                let fmt = DateFormatter()
                fmt.dateStyle = .medium
                content.secondaryText = "Friends since \(fmt.string(from: since))"
                content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary
            }

            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]

            var bg = UIBackgroundConfiguration.listCell()
            bg.backgroundColor = DesignTokens.Colors.surfacePrimary
            cell.backgroundConfiguration = bg
        }

        dataSource = UICollectionViewDiffableDataSource<FriendsSection, FriendItem>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        let headerReg = UICollectionView.SupplementaryRegistration<FriendsSectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = FriendsSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .requests: "Pending Requests"
            case .friends:  "Friends"
            case .none:     ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        spinner.stopAnimating()
        spinner.removeFromSuperview()
        guard let friends else { return }
        let pending = friends.filter { $0.status == .pending }
        let accepted = friends.filter { $0.status == .accepted }

        if friends.isEmpty {
            showEmptyState()
            return
        }

        var snapshot = NSDiffableDataSourceSnapshot<FriendsSection, FriendItem>()

        if !pending.isEmpty {
            snapshot.appendSections([.requests])
            snapshot.appendItems(pending, toSection: .requests)
        }

        if !accepted.isEmpty {
            snapshot.appendSections([.friends])
            snapshot.appendItems(accepted, toSection: .friends)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func showEmptyState() {
        let empty = EmptyStateView(
            icon: "person.2.slash",
            title: "No Friends Yet",
            message: "Add friends to share folders and see each other's progress.",
            buttonTitle: "Add Friend"
        )
        empty.onAction = { [weak self] in self?.addFriendTapped() }
        empty.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(empty)

        NSLayoutConstraint.activate([
            empty.topAnchor.constraint(equalTo: contentTopAnchor),
            empty.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        emptyState = empty
    }

    private func addFriendTapped() {
        // Placeholder — would present a search/invite sheet
    }
}

// MARK: - UICollectionViewDelegate

extension FriendsListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onFriendTapped?(item)
    }
}

// MARK: - Sections

nonisolated private enum FriendsSection: Int, Hashable, Sendable {
    case requests
    case friends
}

// MARK: - Section Header

private final class FriendsSectionHeaderView: UICollectionReusableView {

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.xs),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String) { titleLabel.text = title.uppercased() }
}
