import UIKit

nonisolated private enum NoteListSection: Sendable { case main }

class NoteListViewController: BaseViewController {

    var onNoteSelected: ((UUID) -> Void)?
    var onDirectivesTapped: (() -> Void)?
    var onBalloonsTapped: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<NoteListSection, NoteListItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Notes"
        navigationController?.navigationBar.prefersLargeTitles = true

        configureNavBarButtons()
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Nav Bar

    private func configureNavBarButtons() {
        let directivesButton = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet"),
            style: .plain,
            target: self,
            action: #selector(directivesTapped)
        )
        let balloonsButton = UIBarButtonItem(
            image: UIImage(systemName: "balloon.2.fill"),
            style: .plain,
            target: self,
            action: #selector(balloonsTapped)
        )
        navigationItem.rightBarButtonItems = [balloonsButton, directivesButton]
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        let layout = createLayout()
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

    private func createLayout() -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        return UICollectionViewCompositionalLayout { _, env in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(72))
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
        let cellRegistration = UICollectionView.CellRegistration<NoteCell, NoteListItem> { cell, _, item in
            cell.configure(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource<NoteListSection, NoteListItem>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        let items = SampleData.noteListItems  // Future: ValueObservation
        applySnapshot(items)
    }

    private func applySnapshot(_ items: [NoteListItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<NoteListSection, NoteListItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - Actions

    @objc private func directivesTapped() { onDirectivesTapped?() }
    @objc private func balloonsTapped() { onBalloonsTapped?() }
}

// MARK: - UICollectionViewDelegate

extension NoteListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onNoteSelected?(item.note.id)
    }
}
