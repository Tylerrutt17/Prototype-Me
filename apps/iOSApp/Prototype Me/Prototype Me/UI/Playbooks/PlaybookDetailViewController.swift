import UIKit

nonisolated private enum PlaybookDetailSection: Int, Sendable {
    case header
    case notes
}

nonisolated private enum PlaybookDetailItem: Hashable, Sendable {
    case header(UUID)
    case note(NoteListItem)
}

class PlaybookDetailViewController: BaseViewController {

    var folderId: UUID?
    var onNoteSelected: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<PlaybookDetailSection, PlaybookDetailItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
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
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(sectionIndex == 0 ? 120 : 72))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = DesignTokens.Spacing.sm
            section.contentInsets = NSDirectionalEdgeInsets(
                top: sectionIndex == 0 ? DesignTokens.Spacing.lg : DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.lg,
                trailing: DesignTokens.Spacing.lg
            )

            if sectionIndex > 0 {
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(32))
                let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [sectionHeader]
            }
            return section
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let headerReg = UICollectionView.CellRegistration<PlaybookHeaderCell, UUID> { cell, _, folderId in
            guard let folder = SampleData.folders.first(where: { $0.id == folderId }) else { return }
            let item = SampleData.playbookListItems.first { $0.folder.id == folderId }
            cell.configure(with: folder, noteCount: item?.noteCount ?? 0, directiveCount: item?.directiveCount ?? 0)
        }

        let noteReg = UICollectionView.CellRegistration<NoteCell, NoteListItem> { cell, _, item in
            cell.configure(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource<PlaybookDetailSection, PlaybookDetailItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header(let id):
                return collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: id)
            case .note(let noteItem):
                return collectionView.dequeueConfiguredReusableCell(using: noteReg, for: indexPath, item: noteItem)
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            if indexPath.section == PlaybookDetailSection.notes.rawValue {
                supplementaryView.configure(title: "Notes")
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        guard let folderId else { return }

        let folder = SampleData.folders.first { $0.id == folderId }
        navigationItem.title = folder?.name

        let notes = SampleData.notes(forFolderId: folderId)

        var snapshot = NSDiffableDataSourceSnapshot<PlaybookDetailSection, PlaybookDetailItem>()
        snapshot.appendSections([.header])
        snapshot.appendItems([.header(folderId)], toSection: .header)

        if !notes.isEmpty {
            snapshot.appendSections([.notes])
            snapshot.appendItems(notes.map { .note($0) }, toSection: .notes)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension PlaybookDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .note(let noteItem) = item {
            onNoteSelected?(noteItem.note.id)
        }
    }
}

// MARK: - PlaybookHeaderCell

private final class PlaybookHeaderCell: UICollectionViewCell {

    private let nameLabel = UILabel()
    private let intentBadge = StatusBadgeView()
    private let countsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        nameLabel.font = DesignTokens.Typography.title2
        nameLabel.textColor = DesignTokens.Colors.textPrimary
        nameLabel.numberOfLines = 0

        countsLabel.font = DesignTokens.Typography.subheadline
        countsLabel.textColor = DesignTokens.Colors.textSecondary

        let metaRow = UIStackView(arrangedSubviews: [intentBadge, countsLabel, UIView()])
        metaRow.axis = .horizontal
        metaRow.spacing = DesignTokens.Spacing.sm
        metaRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [nameLabel, metaRow])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with folder: Folder, noteCount: Int, directiveCount: Int) {
        nameLabel.text = folder.name
        countsLabel.text = "\(noteCount) notes · \(directiveCount) directives"

        let intentColor: UIColor = switch folder.intent {
        case .learning:    DesignTokens.Colors.accent
        case .execution:   DesignTokens.Colors.accentTertiary
        case .maintenance: DesignTokens.Colors.accentSecondary
        case .general:     DesignTokens.Colors.textSecondary
        }
        intentBadge.configure(text: folder.intent.rawValue, tint: intentColor)
    }
}
