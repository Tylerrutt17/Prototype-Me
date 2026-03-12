import UIKit

nonisolated private enum NoteDetailSection: Int, Sendable {
    case header
    case directives
}

nonisolated private enum NoteDetailItem: Hashable, Sendable {
    case header(UUID)
    case directive(DirectiveRowData)
}

class NoteDetailViewController: BaseViewController {

    var noteId: UUID?
    var onDirectiveSelected: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<NoteDetailSection, NoteDetailItem>!

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
            let section = NoteDetailSection(rawValue: sectionIndex)
            switch section {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(200))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.lg,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.md,
                    trailing: DesignTokens.Spacing.lg
                )
                return layoutSection

            default:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = DesignTokens.Spacing.sm
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.lg,
                    trailing: DesignTokens.Spacing.lg
                )

                // Section header
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(32))
                let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                layoutSection.boundarySupplementaryItems = [sectionHeader]
                return layoutSection
            }
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        // Header cell
        let headerReg = UICollectionView.CellRegistration<NoteHeaderCell, UUID> { cell, _, noteId in
            guard let note = SampleData.notes.first(where: { $0.id == noteId }) else { return }
            cell.configure(with: note)
        }

        // Directive cell
        let directiveReg = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, data in
            cell.configure(with: data)
        }

        dataSource = UICollectionViewDiffableDataSource<NoteDetailSection, NoteDetailItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header(let id):
                return collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: id)
            case .directive(let data):
                return collectionView.dequeueConfiguredReusableCell(using: directiveReg, for: indexPath, item: data)
            }
        }

        // Section header supplementary
        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            if indexPath.section == NoteDetailSection.directives.rawValue {
                supplementaryView.configure(title: "Linked Directives")
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        guard let noteId else { return }

        let note = SampleData.notes.first { $0.id == noteId }
        navigationItem.title = note?.title

        let linkedDirectives = SampleData.directives(forNoteId: noteId)

        var snapshot = NSDiffableDataSourceSnapshot<NoteDetailSection, NoteDetailItem>()
        snapshot.appendSections([.header])
        snapshot.appendItems([.header(noteId)], toSection: .header)

        if !linkedDirectives.isEmpty {
            snapshot.appendSections([.directives])
            snapshot.appendItems(linkedDirectives.map { .directive($0) }, toSection: .directives)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UICollectionViewDelegate

extension NoteDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .directive(let data) = item {
            onDirectiveSelected?(data.directive.id)
        }
    }
}

// MARK: - NoteHeaderCell

private final class NoteHeaderCell: UICollectionViewCell {

    private let titleLabel = UILabel()
    private let tierLabel = TierLabel()
    private let kindLabel = UILabel()
    private let bodyLabel = UILabel()

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
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        titleLabel.font = DesignTokens.Typography.title2
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        kindLabel.font = DesignTokens.Typography.caption1
        kindLabel.textColor = DesignTokens.Colors.textSecondary

        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        let metaRow = UIStackView(arrangedSubviews: [tierLabel, kindLabel, UIView()])
        metaRow.axis = .horizontal
        metaRow.spacing = DesignTokens.Spacing.sm
        metaRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, metaRow, bodyLabel])
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

    func configure(with note: NotePage) {
        titleLabel.text = note.title
        tierLabel.configure(tier: note.tier)
        kindLabel.text = note.kind == .regular ? nil : note.kind.rawValue.capitalized
        kindLabel.isHidden = note.kind == .regular
        bodyLabel.text = note.body
    }
}

// MARK: - SectionHeaderView

final class SectionHeaderView: UICollectionReusableView {

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title.uppercased()
    }
}
