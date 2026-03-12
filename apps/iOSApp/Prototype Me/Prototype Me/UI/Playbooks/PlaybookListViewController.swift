import UIKit

nonisolated private enum PlaybookListSection: Sendable { case main }

class PlaybookListViewController: BaseViewController {

    var onPlaybookSelected: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<PlaybookListSection, PlaybookListItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Playbooks"
        navigationController?.navigationBar.prefersLargeTitles = true

        configureCollectionView()
        configureDataSource()
        loadData()
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
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
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
        let cellRegistration = UICollectionView.CellRegistration<PlaybookCell, PlaybookListItem> { cell, _, item in
            cell.configure(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource<PlaybookListSection, PlaybookListItem>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        let items = SampleData.playbookListItems  // Future: ValueObservation
        var snapshot = NSDiffableDataSourceSnapshot<PlaybookListSection, PlaybookListItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

// MARK: - UICollectionViewDelegate

extension PlaybookListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onPlaybookSelected?(item.folder.id)
    }
}

// MARK: - PlaybookCell

private final class PlaybookCell: UICollectionViewCell {

    static let reuseID = "PlaybookCell"

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let countsLabel = UILabel()
    private let intentBadge = StatusBadgeView()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        iconView.image = UIImage(systemName: "book.closed.fill")
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        nameLabel.font = DesignTokens.Typography.headline
        nameLabel.textColor = DesignTokens.Colors.textPrimary

        countsLabel.font = DesignTokens.Typography.caption1
        countsLabel.textColor = DesignTokens.Colors.textSecondary

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, countsLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xxs

        let mainStack = UIStackView(arrangedSubviews: [iconView, textStack, intentBadge, chevron])
        mainStack.axis = .horizontal
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with item: PlaybookListItem) {
        nameLabel.text = item.folder.name
        countsLabel.text = "\(item.noteCount) notes · \(item.directiveCount) directives"

        let intentColor: UIColor = switch item.folder.intent {
        case .learning:    DesignTokens.Colors.accent
        case .execution:   DesignTokens.Colors.accentTertiary
        case .maintenance: DesignTokens.Colors.accentSecondary
        case .general:     DesignTokens.Colors.textSecondary
        }
        intentBadge.configure(text: item.folder.intent.rawValue, tint: intentColor)
    }
}
