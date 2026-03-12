import UIKit

nonisolated private enum FocusSection: Int, Hashable, Sendable {
    case modes
    case balloons
    case schedule
}

nonisolated private enum FocusItem: Hashable, Sendable {
    case mode(NotePage)
    case balloon(DirectiveRowData)
    case scheduleRow(ScheduleInstanceRow)
}

class FocusViewController: BaseViewController {

    var onModeSelected: ((UUID) -> Void)?
    var onBalloonSelected: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<FocusSection, FocusItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Focus"
        navigationController?.navigationBar.prefersLargeTitles = true

        configureCollectionView()
        configureDataSource()
        loadData()
        addAIButton()
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
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            let section = FocusSection(rawValue: sectionIndex)

            switch section {
            case .modes:
                // Horizontal scroll cards
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.75),
                    heightDimension: .estimated(120)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.75),
                    heightDimension: .estimated(120)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.orthogonalScrollingBehavior = .groupPaging
                layoutSection.interGroupSpacing = DesignTokens.Spacing.md
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.lg,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.md,
                    trailing: DesignTokens.Spacing.lg
                )
                layoutSection.boundarySupplementaryItems = [Self.sectionHeader()]
                return layoutSection

            case .balloons:
                // 2-column grid
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .estimated(200)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .estimated(200)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])
                group.interItemSpacing = .fixed(DesignTokens.Spacing.md)
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = DesignTokens.Spacing.md
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.md,
                    trailing: DesignTokens.Spacing.lg
                )
                layoutSection.boundarySupplementaryItems = [Self.sectionHeader()]
                return layoutSection

            default:
                // Vertical list for schedule
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(48))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = DesignTokens.Spacing.xs
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.xxxl,
                    trailing: DesignTokens.Spacing.lg
                )
                layoutSection.boundarySupplementaryItems = [Self.sectionHeader()]
                return layoutSection
            }
        }
    }

    private static func sectionHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(32))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: size,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let modeReg = UICollectionView.CellRegistration<ModeCard, NotePage> { cell, _, note in
            cell.configure(with: note)
        }

        let balloonReg = UICollectionView.CellRegistration<BalloonCard, DirectiveRowData> { cell, _, data in
            cell.configure(with: data)
        }

        let scheduleReg = UICollectionView.CellRegistration<ScheduleInstanceRowCell, ScheduleInstanceRow> { cell, _, row in
            cell.configure(with: row)
        }

        dataSource = UICollectionViewDiffableDataSource<FocusSection, FocusItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .mode(let note):
                return collectionView.dequeueConfiguredReusableCell(using: modeReg, for: indexPath, item: note)
            case .balloon(let data):
                return collectionView.dequeueConfiguredReusableCell(using: balloonReg, for: indexPath, item: data)
            case .scheduleRow(let row):
                return collectionView.dequeueConfiguredReusableCell(using: scheduleReg, for: indexPath, item: row)
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = FocusSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .modes:    "Active Modes"
            case .balloons: "Urgent Balloons"
            case .schedule: "Today's Schedule"
            case .none:     ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Load Data

    private func loadData() {
        let snapshot = SampleData.focusSnapshot

        var ds = NSDiffableDataSourceSnapshot<FocusSection, FocusItem>()

        if !snapshot.activeModes.isEmpty {
            ds.appendSections([.modes])
            ds.appendItems(snapshot.activeModes.map { .mode($0) }, toSection: .modes)
        }

        if !snapshot.urgentBalloons.isEmpty {
            ds.appendSections([.balloons])
            ds.appendItems(snapshot.urgentBalloons.map { .balloon($0) }, toSection: .balloons)
        }

        if !snapshot.todaySchedule.isEmpty {
            ds.appendSections([.schedule])
            ds.appendItems(snapshot.todaySchedule.map { .scheduleRow($0) }, toSection: .schedule)
        }

        dataSource.apply(ds, animatingDifferences: false)
    }

    // MARK: - Floating AI Button (placeholder)

    private func addAIButton() {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "sparkle")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = DesignTokens.Colors.accent
        config.baseForegroundColor = DesignTokens.Colors.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        DesignTokens.Shadows.apply(to: button.layer, elevation: .high)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
}

// MARK: - UICollectionViewDelegate

extension FocusViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .mode(let note):
            onModeSelected?(note.id)
        case .balloon(let data):
            onBalloonSelected?(data.directive.id)
        case .scheduleRow:
            break
        }
    }
}

// MARK: - ModeCard

private final class ModeCard: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .low)

        iconView.image = UIImage(systemName: "bolt.fill")
        iconView.tintColor = DesignTokens.Colors.accentTertiary
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 3

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xs

        let topRow = UIStackView(arrangedSubviews: [iconView, textStack])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.md
        topRow.alignment = .top
        topRow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(topRow)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            topRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with note: NotePage) {
        titleLabel.text = note.title
        bodyLabel.text = String(note.body.prefix(120))
    }
}
