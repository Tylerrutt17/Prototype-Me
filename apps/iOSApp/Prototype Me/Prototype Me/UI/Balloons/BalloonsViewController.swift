import UIKit
import GRDB

nonisolated private enum BalloonsSection: Int, Hashable, Sendable {
    case urgent  // < 5 hours remaining
    case later   // 5+ hours remaining
}

private let urgentThreshold: TimeInterval = 12 * 3600 // 12 hours — matches green/yellow pressure boundary

private enum ViewMode: Int { case grid = 0, sky = 1 }

class BalloonsViewController: BaseViewController {

    var onDirectiveSelected: ((UUID) -> Void)?
    var isEmbedded = false

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<BalloonsSection, DirectiveRowData>!
    private var skyView: BalloonSkyView!
    private var currentItems: [DirectiveRowData] = []

    private let debugSlider = UISlider()
    private let debugLabel = UILabel()

    override func viewDidLoad() {
        if isEmbedded { hidesNavBar = true }
        super.viewDidLoad()
        configureSegmentedControl()
        configureCollectionView()
        configureSkyView()
        // configureDebugSlider()  // Uncomment to test time-of-day sky
        configureDataSource()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshAnimations()
    }

    // MARK: - Debug Time Slider

    private func configureDebugSlider() {
        debugLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        debugLabel.textColor = .white
        debugLabel.textAlignment = .center
        debugLabel.text = "Time: Auto"
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(debugLabel)

        debugSlider.minimumValue = -1
        debugSlider.maximumValue = 23
        debugSlider.value = -1
        debugSlider.tintColor = DesignTokens.Colors.accent
        debugSlider.addTarget(self, action: #selector(debugSliderChanged), for: .valueChanged)
        debugSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(debugSlider)

        NSLayoutConstraint.activate([
            debugLabel.bottomAnchor.constraint(equalTo: debugSlider.topAnchor, constant: -DesignTokens.Spacing.xs),
            debugLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            debugSlider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            debugSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            debugSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    @objc private func debugSliderChanged() {
        let val = Int(debugSlider.value)
        if val < 0 {
            skyView.debugHour = nil
            debugLabel.text = "Time: Auto"
        } else {
            skyView.debugHour = val
            let ampm = val >= 12 ? "PM" : "AM"
            let display = val == 0 ? 12 : (val > 12 ? val - 12 : val)
            debugLabel.text = "Time: \(display):00 \(ampm)"
        }
        skyView.setNeedsLayout()
    }

    /// Called by LibraryContainerVC when switching to the balloons tab.
    func refreshAnimations() {
        guard isViewLoaded else { return }
        if !skyView.isHidden {
            skyView.resetEntrance()
            skyView.update(with: currentItems)
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeSegment: UISegmentedControl!

    private func configureSegmentedControl() {
        let sc = UISegmentedControl(items: ["Cards", "Sky"])
        sc.selectedSegmentIndex = 0  // Default to Cards
        sc.selectedSegmentTintColor = DesignTokens.Colors.accent
        sc.setTitleTextAttributes([
            .foregroundColor: DesignTokens.Colors.textSecondary,
            .font: DesignTokens.Typography.rounded(style: .subheadline, weight: .medium),
        ], for: .normal)
        sc.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold),
        ], for: .selected)
        sc.addTarget(self, action: #selector(viewModeChanged(_:)), for: .valueChanged)
        viewModeSegment = sc

        if isEmbedded {
            // Add directly to view when nav bar is hidden
            sc.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sc)
            NSLayoutConstraint.activate([
                sc.topAnchor.constraint(equalTo: view.topAnchor, constant: DesignTokens.Spacing.sm),
                sc.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                sc.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            ])
        } else {
            sc.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
            navBar.setTitleView(sc)
        }
    }

    @objc private func viewModeChanged(_ sender: UISegmentedControl) {
        let mode = ViewMode(rawValue: sender.selectedSegmentIndex) ?? .grid
        collectionView.isHidden = (mode == .sky)
        skyView.isHidden = (mode == .grid)
        Haptics.selection()

        // Re-trigger the rise-from-ground entrance when switching to sky
        if mode == .sky {
            skyView.resetEntrance()
            skyView.update(with: currentItems)
        }
    }

    // MARK: - Sky View

    private func configureSkyView() {
        skyView = BalloonSkyView()
        skyView.isHidden = true  // Cards is default
        skyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skyView)

        let skyTop = isEmbedded ? viewModeSegment.bottomAnchor : contentTopAnchor
        NSLayoutConstraint.activate([
            skyView.topAnchor.constraint(equalTo: skyTop, constant: DesignTokens.Spacing.sm),
            skyView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            skyView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skyView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        skyView.onBalloonTapped = { [weak self] directiveId in
            self?.onDirectiveSelected?(directiveId)
        }
    }

    // MARK: - Collection View (2-column grid)

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.isHidden = false  // Cards is the default view
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: isEmbedded ? viewModeSegment.bottomAnchor : contentTopAnchor, constant: DesignTokens.Spacing.sm),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
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

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = DesignTokens.Spacing.md
            section.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.lg,
                trailing: DesignTokens.Spacing.lg
            )

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(32))
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            section.boundarySupplementaryItems = [header]
            return section
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<BalloonCard, DirectiveRowData> { [weak self] cell, indexPath, item in
            cell.dbQueue = self?.dbQueue
            cell.configure(with: item)

            // Gray out "later" section cards
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            cell.contentView.alpha = section == .later ? 0.45 : 1.0
        }

        dataSource = UICollectionViewDiffableDataSource<BalloonsSection, DirectiveRowData>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }

        let headerReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] supplementaryView, _, indexPath in
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            let title: String = switch section {
            case .urgent: "Needs Attention"
            case .later:  "On Track"
            case .none:   ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerReg, for: indexPath)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        let today = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: .now)
        }()

        let observation = ValueObservation.tracking { db -> [DirectiveRowData] in
            let directives = try Directive
                .filter(Column("balloonEnabled") == true && Column("status") == DirectiveStatus.active.rawValue)
                .fetchAll(db)
                .sorted { $0.liveRemainingSec < $1.liveRemainingSec }
            return directives.map { dir in
                let todayInstance = try? ScheduleInstance
                    .filter(Column("directiveId") == dir.id && Column("date") == today)
                    .fetchOne(db)
                return DirectiveRowData(directive: dir, scheduledToday: todayInstance != nil, instanceStatus: todayInstance?.status)
            }
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] items in
            guard let self else { return }
            self.currentItems = items

            let urgent = items.filter { $0.directive.liveRemainingSec < urgentThreshold }
            let later = items.filter { $0.directive.liveRemainingSec >= urgentThreshold }

            // Update grid view
            var snapshot = NSDiffableDataSourceSnapshot<BalloonsSection, DirectiveRowData>()
            if !urgent.isEmpty {
                snapshot.appendSections([.urgent])
                snapshot.appendItems(urgent, toSection: .urgent)
            }
            if !later.isEmpty {
                snapshot.appendSections([.later])
                snapshot.appendItems(later, toSection: .later)
            }
            self.dataSource.apply(snapshot, animatingDifferences: true)

            // Force cell reconfiguration since model equality is id-only
            var reconfigSnap = self.dataSource.snapshot()
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self.dataSource.apply(reconfigSnap, animatingDifferences: false)

            // Update sky view
            self.skyView.update(with: items)
        })
    }

}

// MARK: - UICollectionViewDelegate

extension BalloonsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onDirectiveSelected?(item.directive.id)
    }
}
