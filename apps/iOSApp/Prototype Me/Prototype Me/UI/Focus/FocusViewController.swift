import UIKit
import GRDB

nonisolated private enum FocusSection: Int, Hashable, Sendable {
    case directives
    case balloons
    case schedule
}

nonisolated private enum FocusItem: Hashable, Sendable {
    case directive(DirectiveRowData)  // Linked directives for active mode
    case emptyDirectives              // "No directives — tap to add"
    case balloon(DirectiveRowData)
    case viewAllBalloons(Int)         // Condensed row with count when > 4
    case scheduleRow(ScheduleInstanceRow)
}

// Separate section/item enums for the mode carousel
nonisolated private enum CarouselSection: Sendable { case main }
nonisolated private enum CarouselItem: Hashable, Sendable {
    case noMode
    case mode(NotePage)
}

class FocusViewController: BaseViewController {

    var onModeSelected: ((UUID) -> Void)?
    var onDirectiveSelected: ((UUID) -> Void)?
    var onBalloonSelected: ((UUID) -> Void)?
    var onViewAllBalloonsTapped: (() -> Void)?
    var balloonNotificationService: BalloonNotificationService?
    var modeService: ModeService?
    var onPickModesTapped: (() -> Void)?
    var onAskAIForDirective: ((UUID) -> Void)?
    var noteService: NoteService?

    private static let maxInlineBalloons = 4
    var onReplayOnboardingTapped: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<FocusSection, FocusItem>!

    // Mode carousel (separate from main collection view)
    private var modeCarousel: UICollectionView!
    private var modeDataSource: UICollectionViewDiffableDataSource<CarouselSection, CarouselItem>!
    private let modesHeaderView = SectionHeaderWithActionView(frame: .zero)
    private let carouselContainer = UIView()
    private let carouselFullHeight: CGFloat = 138
    private var collectionTopConstraint: NSLayoutConstraint!

    /// All mode notes (for the carousel)
    private var allModes: [NotePage] = []
    /// Currently active mode ID (nil = "No Mode")
    private var activeModeId: UUID?
    /// Whether initial scroll to active mode has happened
    private var didInitialScroll = false
    /// Suppress mode-switch during programmatic scrolls or snapshot applies
    private var suppressCarouselModeSwitch = false
    /// Debounce timer for carousel swipe mode changes
    private var carouselDebounceTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Focus", animated: false)
        navBar.setRightButtons([
            NavBarButton(systemImage: "wand.and.stars", action: { [weak self] in self?.onReplayOnboardingTapped?() }),
        ])

        configureCollectionView()
        configureModeCarousel()
        view.bringSubviewToFront(carouselContainer)
        configureCarouselDataSource()
        configureDataSource()
        loadData()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restartVisibleModeAnimations()
    }

    @objc private func appDidBecomeActive() {
        // Restart mode card animations after returning from background
        guard view.window != nil else { return }
        restartVisibleModeAnimations()
    }

    private func restartVisibleModeAnimations() {
        for cell in modeCarousel.visibleCells {
            if let modeCard = cell as? ModeCard {
                modeCard.restartAnimationsIfNeeded()
            }
        }
    }

    // MARK: - Mode Carousel (separate from main list)

    private func configureModeCarousel() {
        carouselContainer.backgroundColor = DesignTokens.Colors.background
        carouselContainer.clipsToBounds = false
        carouselContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(carouselContainer)

        // "Modes · See All" header
        modesHeaderView.configure(title: "Modes", actionTitle: "See All") { [weak self] in
            self?.onPickModesTapped?()
        }
        modesHeaderView.translatesAutoresizingMaskIntoConstraints = false
        carouselContainer.addSubview(modesHeaderView)

        // Horizontal paging layout — card width matches screen minus insets
        let screenWidth = UIScreen.main.bounds.width
        let inset: CGFloat = DesignTokens.Spacing.lg
        let cardWidth = screenWidth - inset * 2
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cardWidth),
            heightDimension: .estimated(80)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cardWidth),
            heightDimension: .estimated(80)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = DesignTokens.Spacing.md
        section.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.xs,
            leading: 0,
            bottom: DesignTokens.Spacing.xs,
            trailing: 0
        )
        section.visibleItemsInvalidationHandler = { [weak self] visibleItems, offset, env in
            self?.handleCarouselScroll(visibleItems: visibleItems, offset: offset, containerWidth: env.container.contentSize.width)
        }

        let layout = UICollectionViewCompositionalLayout { _, _ in section }

        modeCarousel = UICollectionView(frame: .zero, collectionViewLayout: layout)
        modeCarousel.backgroundColor = .clear
        modeCarousel.delegate = self
        modeCarousel.showsHorizontalScrollIndicator = false
        modeCarousel.isScrollEnabled = false // vertical scroll disabled; orthogonal handles horizontal
        modeCarousel.translatesAutoresizingMaskIntoConstraints = false
        carouselContainer.addSubview(modeCarousel)

        NSLayoutConstraint.activate([
            carouselContainer.topAnchor.constraint(equalTo: contentTopAnchor),
            carouselContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            carouselContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            carouselContainer.heightAnchor.constraint(equalToConstant: carouselFullHeight),

            modesHeaderView.topAnchor.constraint(equalTo: carouselContainer.topAnchor, constant: DesignTokens.Spacing.sm),
            modesHeaderView.leadingAnchor.constraint(equalTo: carouselContainer.leadingAnchor),
            modesHeaderView.trailingAnchor.constraint(equalTo: carouselContainer.trailingAnchor),
            modesHeaderView.heightAnchor.constraint(equalToConstant: 28),

            modeCarousel.topAnchor.constraint(equalTo: modesHeaderView.bottomAnchor),
            modeCarousel.leadingAnchor.constraint(equalTo: carouselContainer.leadingAnchor),
            modeCarousel.trailingAnchor.constraint(equalTo: carouselContainer.trailingAnchor),
            modeCarousel.heightAnchor.constraint(equalToConstant: 110),
        ])
    }

    // MARK: - Main Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.contentInset.top = carouselFullHeight
        collectionView.scrollIndicatorInsets.top = carouselFullHeight
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        // Collection view sits behind the carousel, full height from contentTop
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            let section = self?.dataSource.snapshot().sectionIdentifiers[sectionIndex]

            switch section {
            case .directives:
                var config = UICollectionLayoutListConfiguration(appearance: .plain)
                config.backgroundColor = .clear
                config.showsSeparators = false
                config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                    guard let self,
                          let item = self.dataSource.itemIdentifier(for: indexPath),
                          case .directive(let data) = item else { return nil }

                    let unlink = UIContextualAction(style: .normal, title: "Unlink") { [weak self] _, _, completion in
                        guard let self, let activeModeId = self.activeModeId else { completion(false); return }
                        Task {
                            try? await self.noteService?.unlinkDirective(noteId: activeModeId, directiveId: data.directive.id)
                            Haptics.success()
                        }
                        completion(true)
                    }
                    unlink.backgroundColor = DesignTokens.Colors.destructive
                    unlink.image = UIImage(systemName: "link.badge.minus")

                    let askAI = UIContextualAction(style: .normal, title: "Not Working?") { [weak self] _, _, completion in
                        self?.onAskAIForDirective?(data.directive.id)
                        completion(true)
                    }
                    askAI.backgroundColor = DesignTokens.Colors.warning
                    askAI.image = UIImage(systemName: "lightbulb.slash")

                    let swipeConfig = UISwipeActionsConfiguration(actions: [unlink, askAI])
                    swipeConfig.performsFirstActionWithFullSwipe = false
                    return swipeConfig
                }
                let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: environment)
                layoutSection.interGroupSpacing = DesignTokens.Spacing.xs
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.md,
                    trailing: DesignTokens.Spacing.lg
                )
                layoutSection.boundarySupplementaryItems = [Self.sectionHeader()]
                return layoutSection

            case .balloons:
                // Check if it's the condensed "view all" row vs balloon cards
                let items = self?.dataSource.snapshot().itemIdentifiers(inSection: .balloons) ?? []
                let isCondensed = items.count == 1 && items.first.map {
                    if case .viewAllBalloons = $0 { return true } else { return false }
                } ?? false

                if isCondensed {
                    // Full-width single row
                    let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(52))
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                    let layoutSection = NSCollectionLayoutSection(group: group)
                    layoutSection.contentInsets = NSDirectionalEdgeInsets(
                        top: DesignTokens.Spacing.sm,
                        leading: DesignTokens.Spacing.lg,
                        bottom: DesignTokens.Spacing.md,
                        trailing: DesignTokens.Spacing.lg
                    )
                    layoutSection.boundarySupplementaryItems = [Self.sectionHeader()]
                    return layoutSection
                } else {
                    // 2-column grid — uniform fixed height
                    let itemSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(0.5),
                        heightDimension: .fractionalHeight(1.0)
                    )
                    let item = NSCollectionLayoutItem(layoutSize: itemSize)
                    let groupSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(160)
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
                }

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

    // MARK: - Carousel Data Source

    private func configureCarouselDataSource() {
        let noModeReg = UICollectionView.CellRegistration<NoModeCard, Bool> { cell, _, isSelected in
            cell.configure(isSelected: isSelected)
        }

        let modeReg = UICollectionView.CellRegistration<ModeCard, (NotePage, Bool)> { cell, _, pair in
            cell.configure(with: pair.0, isSelected: pair.1)
        }

        modeDataSource = UICollectionViewDiffableDataSource(collectionView: modeCarousel) { [weak self] cv, indexPath, item in
            switch item {
            case .noMode:
                let isSelected = self?.activeModeId == nil
                return cv.dequeueConfiguredReusableCell(using: noModeReg, for: indexPath, item: isSelected)
            case .mode(let note):
                let isSelected = self?.activeModeId == note.id
                return cv.dequeueConfiguredReusableCell(using: modeReg, for: indexPath, item: (note, isSelected))
            }
        }
    }

    // MARK: - Main Data Source

    private func configureDataSource() {
        let directiveReg = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, data in
            cell.configure(with: data)
        }

        let balloonReg = UICollectionView.CellRegistration<BalloonCard, DirectiveRowData> { [weak self] cell, _, data in
            cell.dbQueue = self?.dbQueue
            cell.balloonNotificationService = self?.balloonNotificationService
            cell.configure(with: data)
        }

        let viewAllBalloonsReg = UICollectionView.CellRegistration<ViewAllBalloonsCell, Int> { cell, _, count in
            cell.configure(count: count)
        }

        let scheduleReg = UICollectionView.CellRegistration<ScheduleInstanceRowCell, ScheduleInstanceRow> { [weak self] cell, _, row in
            cell.dbQueue = self?.dbQueue
            cell.configure(with: row)
            cell.onChevronTapped = {
                self?.onDirectiveSelected?(row.rule.directiveId)
            }
        }

        let emptyDirectivesReg = UICollectionView.CellRegistration<EmptyDirectivesCell, Bool> { cell, _, _ in
            cell.configure()
        }

        dataSource = UICollectionViewDiffableDataSource<FocusSection, FocusItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .directive(let data):
                return collectionView.dequeueConfiguredReusableCell(using: directiveReg, for: indexPath, item: data)
            case .emptyDirectives:
                return collectionView.dequeueConfiguredReusableCell(using: emptyDirectivesReg, for: indexPath, item: true)
            case .balloon(let data):
                return collectionView.dequeueConfiguredReusableCell(using: balloonReg, for: indexPath, item: data)
            case .viewAllBalloons(let count):
                return collectionView.dequeueConfiguredReusableCell(using: viewAllBalloonsReg, for: indexPath, item: count)
            case .scheduleRow(let row):
                return collectionView.dequeueConfiguredReusableCell(using: scheduleReg, for: indexPath, item: row)
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { [weak self] supplementaryView, _, indexPath in
            let section = self?.dataSource.snapshot().sectionIdentifiers[indexPath.section]
            let title: String = switch section {
            case .directives: "Directives"
            case .balloons:   "Urgent Balloons"
            case .schedule:   "Today's Schedule"
            case .none:       ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        let observation = ValueObservation.tracking { db -> FocusSnapshot in
            // ALL mode notes (kind == .mode)
            let allModes = try NotePage
                .filter(Column("kind") == NoteKind.mode.rawValue)
                .order(Column("sortIndex"))
                .fetchAll(db)

            // Currently active mode (first one, or nil)
            let activeRecord = try ActiveMode.order(Column("activatedAt")).fetchOne(db)

            // Fetch all schedule rules once — used for scheduledToday checks
            let allRules = try ScheduleRule.fetchAll(db)

            // Linked directives for the active mode
            var modeDirectives: [DirectiveRowData] = []
            if let activeModeId = activeRecord?.noteId {
                let links = try NoteDirective
                    .filter(Column("noteId") == activeModeId)
                    .order(Column("sortIndex"))
                    .fetchAll(db)
                modeDirectives = links.compactMap { link in
                    guard let dir = try? Directive.fetchOne(db, key: link.directiveId),
                          dir.status != .archived else { return nil }
                    let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                    return DirectiveRowData(directive: dir, scheduledToday: scheduled)
                }
            }

            // Urgent balloons — active + balloon enabled, sorted by live remaining time (closest to expiry first)
            let allBalloonDirs = try Directive
                .filter(Column("balloonEnabled") == true && Column("status") == DirectiveStatus.active.rawValue)
                .fetchAll(db)
                .sorted { $0.liveRemainingSec < $1.liveRemainingSec }

            let urgentBalloons = allBalloonDirs.map { dir in
                let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                return DirectiveRowData(directive: dir, scheduledToday: scheduled)
            }

            // Today's schedule — query rules that match today
            let todayRules = allRules.filter { ScheduleRule.ruleMatchesToday($0) }
            let scheduleRows: [ScheduleInstanceRow] = todayRules.compactMap { rule in
                guard let dir = try? Directive.fetchOne(db, key: rule.directiveId),
                      dir.status == .active else { return nil }
                return ScheduleInstanceRow(rule: rule, directiveTitle: dir.title)
            }

            return FocusSnapshot(
                allModes: allModes,
                activeModeId: activeRecord?.noteId,
                modeDirectives: modeDirectives,
                urgentBalloons: urgentBalloons,
                todaySchedule: scheduleRows
            )
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] snapshot in
            guard let self else { return }
            let previousModeId = self.activeModeId
            let previousModes = self.allModes
            self.allModes = snapshot.allModes
            self.activeModeId = snapshot.activeModeId
            let modeChangedExternally = previousModeId != snapshot.activeModeId
            let modeOrderChanged = previousModes.map(\.id) != snapshot.allModes.map(\.id)
            let modeListChanged = Set(previousModes.map(\.id)) != Set(snapshot.allModes.map(\.id)) || modeOrderChanged

            // Only update carousel when modes list or selection actually changed
            if modeListChanged || modeChangedExternally {
                print("[Focus] observation updating carousel — modeChanged: \(modeChangedExternally), listChanged: \(modeListChanged)")
                self.suppressCarouselModeSwitch = true
                var carouselSnap = NSDiffableDataSourceSnapshot<CarouselSection, CarouselItem>()
                carouselSnap.appendSections([.main])
                var carouselItems: [CarouselItem] = [.noMode]
                carouselItems.append(contentsOf: snapshot.allModes.map { .mode($0) })
                carouselSnap.appendItems(carouselItems, toSection: .main)
                self.modeDataSource.apply(carouselSnap, animatingDifferences: false)

                var carouselReconfig = self.modeDataSource.snapshot()
                carouselReconfig.reconfigureItems(carouselReconfig.itemIdentifiers)
                self.modeDataSource.apply(carouselReconfig, animatingDifferences: false)

                // Re-scroll to active mode if order changed or mode changed externally
                if modeOrderChanged || modeChangedExternally {
                    // scrollCarouselToActiveMode manages its own suppress/unsuppress
                    self.scrollCarouselToActiveMode(animated: modeChangedExternally && !modeOrderChanged)
                } else {
                    self.suppressCarouselModeSwitch = false
                }
            }

            // Main list snapshot (no modes)
            var ds = NSDiffableDataSourceSnapshot<FocusSection, FocusItem>()

            if snapshot.activeModeId != nil {
                ds.appendSections([.directives])
                if snapshot.modeDirectives.isEmpty {
                    ds.appendItems([.emptyDirectives], toSection: .directives)
                } else {
                    ds.appendItems(snapshot.modeDirectives.map { .directive($0) }, toSection: .directives)
                }
            }

            // Show balloons that need attention on Focus
            // For long balloons (12h+): show when under 12 hours remaining
            // For short balloons (<12h): show when under 50% remaining
            let focusBalloons = snapshot.urgentBalloons.filter { item in
                let dir = item.directive
                let threshold: TimeInterval
                if dir.balloonDurationSec <= 12 * 3600 {
                    threshold = dir.balloonDurationSec * 0.5
                } else {
                    threshold = 12 * 3600
                }
                return dir.liveRemainingSec < threshold
            }
            let criticalCount = snapshot.urgentBalloons.filter { $0.directive.liveRemainingSec < 3600 }.count

            if !focusBalloons.isEmpty {
                ds.appendSections([.balloons])
                let badgeCount = criticalCount > 0 ? criticalCount : focusBalloons.count
                ds.appendItems([.viewAllBalloons(badgeCount)], toSection: .balloons)
            } else if criticalCount > 0 {
                ds.appendSections([.balloons])
                ds.appendItems([.viewAllBalloons(criticalCount)], toSection: .balloons)
            }

            if !snapshot.todaySchedule.isEmpty {
                ds.appendSections([.schedule])
                ds.appendItems(snapshot.todaySchedule.map { .scheduleRow($0) }, toSection: .schedule)
            }

            let isFirstLoad = !self.didInitialScroll

            if isFirstLoad {
                self.dataSource.apply(ds, animatingDifferences: false)

                var reconfigSnap = self.dataSource.snapshot()
                reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
                self.dataSource.apply(reconfigSnap, animatingDifferences: false)

                self.didInitialScroll = true
                self.scrollCarouselToActiveMode(animated: false)
            } else {
                self.dataSource.apply(ds, animatingDifferences: true) {
                    var reconfigSnap = self.dataSource.snapshot()
                    reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
                    self.dataSource.apply(reconfigSnap, animatingDifferences: false)

                    if modeChangedExternally {
                        self.scrollCarouselToActiveMode(animated: true)
                    }
                }
            }
        })
    }

    // MARK: - Mode Switching

    private func scrollCarouselToActiveMode(animated: Bool) {
        let targetIndex: Int
        if let activeId = activeModeId, let modeIdx = allModes.firstIndex(where: { $0.id == activeId }) {
            targetIndex = modeIdx + 1
        } else {
            targetIndex = 0
        } 
        let indexPath = IndexPath(item: targetIndex, section: 0)
        suppressCarouselModeSwitch = true
        modeCarousel.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.4 : 0.1)) { [weak self] in
            self?.suppressCarouselModeSwitch = false
        }
    }

    private func handleCarouselScroll(visibleItems: [NSCollectionLayoutVisibleItem], offset: CGPoint, containerWidth: CGFloat) {
        guard !suppressCarouselModeSwitch else { return }

        let centerX = offset.x + containerWidth / 2
        var closest: NSCollectionLayoutVisibleItem?
        var closestDist: CGFloat = .greatestFiniteMagnitude
        for item in visibleItems {
            let dist = abs(item.frame.midX - centerX)
            if dist < closestDist {
                closestDist = dist
                closest = item
            }
        }

        guard let snapped = closest else { return }
        let snappedIndex = snapped.indexPath.item

        let newActiveModeId: UUID?
        if snappedIndex == 0 {
            newActiveModeId = nil
        } else {
            let modeIndex = snappedIndex - 1
            guard modeIndex < allModes.count else { return }
            newActiveModeId = allModes[modeIndex].id
        }

        guard newActiveModeId != activeModeId else { return }
        print("[Focus] handleCarouselScroll wants mode \(String(describing: newActiveModeId)), current: \(String(describing: activeModeId))")
        carouselDebounceTimer?.invalidate()
        carouselDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            print("[Focus] debounce timer fired for \(String(describing: newActiveModeId))")
            self?.applyModeChange(newActiveModeId)
        }
    }

    private func applyModeChange(_ newModeId: UUID?) {
        guard newModeId != activeModeId else {
            print("[Focus] applyModeChange SKIPPED — already \(String(describing: newModeId))")
            return
        }
        print("[Focus] applyModeChange \(String(describing: activeModeId)) → \(String(describing: newModeId))")
        activeModeId = newModeId

        Task {
            do {
                try await modeService?.switchTo(noteId: newModeId)
                Haptics.selection()
            } catch {
                Haptics.error()
            }
        }

        // Update visible cells directly to avoid double-animation from reconfigure
        for cell in modeCarousel.visibleCells {
            if let indexPath = modeCarousel.indexPath(for: cell),
               let item = modeDataSource.itemIdentifier(for: indexPath) {
                switch item {
                case .noMode:
                    (cell as? NoModeCard)?.configure(isSelected: newModeId == nil)
                case .mode(let note):
                    (cell as? ModeCard)?.configure(with: note, isSelected: note.id == newModeId)
                }
            }
        }
    }

    // MARK: - Floating AI Button (placeholder)

    private func toggleScheduleRule(_ rule: ScheduleRule) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayStr = fmt.string(from: Date())
        let isCompleted = rule.lastCompletedDate == todayStr
        let newDate: String? = isCompleted ? nil : todayStr

        do {
            try dbQueue.write { db in
                guard var r = try ScheduleRule.fetchOne(db, key: rule.id) else { return }
                r.lastCompletedDate = newDate
                r.version += 1
                r.updatedAt = Date()
                try r.update(db)
                try OutboxOp.enqueue(entityType: "scheduleRule", entityId: r.id.uuidString, op: "update", patch: r.syncPatch(), baseUpdatedAt: r.updatedAt, in: db)
            }
            if newDate != nil {
                DirectiveLogger.logChecklistComplete(
                    directiveId: rule.directiveId,
                    date: todayStr,
                    dbQueue: dbQueue
                )
            } else {
                // User unchecked — retract the log entry for today
                DirectiveLogger.undoChecklistComplete(
                    directiveId: rule.directiveId,
                    date: todayStr,
                    dbQueue: dbQueue
                )
            }
            Haptics.selection()
        } catch {
            Haptics.error()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension FocusViewController: UICollectionViewDelegate, UIScrollViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }

        // contentOffset.y is negative when above rest position (due to contentInset)
        // At rest: contentOffset.y == -carouselFullHeight
        // Scrolled down past carousel: contentOffset.y >= 0
        let scrolledPast = scrollView.contentOffset.y + carouselFullHeight
        let collapseAmount = max(0, min(carouselFullHeight, scrolledPast))

        // Slide the carousel up and fade it out
        carouselContainer.transform = CGAffineTransform(translationX: 0, y: -collapseAmount)
        carouselContainer.alpha = 1 - (collapseAmount / carouselFullHeight)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        // Carousel taps
        if collectionView === modeCarousel {
            guard let item = modeDataSource.itemIdentifier(for: indexPath) else { return }
            switch item {
            case .noMode:
                guard activeModeId != nil else { break }
                applyModeChange(nil)
            case .mode(let note):
                if activeModeId == note.id {
                    onModeSelected?(note.id)
                } else {
                    applyModeChange(note.id)
                }
            }
            return
        }

        // Main list taps
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .directive(let data):
            onDirectiveSelected?(data.directive.id)
        case .emptyDirectives:
            if let activeModeId { onModeSelected?(activeModeId) }
        case .balloon(let data):
            onBalloonSelected?(data.directive.id)
        case .viewAllBalloons:
            onViewAllBalloonsTapped?()
        case .scheduleRow(let row):
            toggleScheduleRule(row.rule)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard collectionView === self.collectionView,
              let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        switch item {
        case .scheduleRow(let row):
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let viewDirective = UIAction(title: "View Directive", image: UIImage(systemName: "doc.text")) { _ in
                    self?.onDirectiveSelected?(row.rule.directiveId)
                }
                let toggleAction: UIAction
                if row.isCompletedToday {
                    toggleAction = UIAction(title: "Mark Pending", image: UIImage(systemName: "circle")) { _ in
                        self?.toggleScheduleRule(row.rule)
                    }
                } else {
                    toggleAction = UIAction(title: "Mark Done", image: UIImage(systemName: "checkmark.circle.fill")) { _ in
                        self?.toggleScheduleRule(row.rule)
                    }
                }
                return UIMenu(children: [toggleAction, viewDirective])
            }
        case .directive(let data):
            return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
                let view = UIAction(title: "View Directive", image: UIImage(systemName: "doc.text")) { _ in
                    self?.onDirectiveSelected?(data.directive.id)
                }
                return UIMenu(children: [view])
            }
        default:
            return nil
        }
    }
}

// MARK: - NoModeCard

private final class NoModeCard: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let glowLayer = CAGradientLayer()
    private var wasSelected = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        clipsToBounds = false
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true
        contentView.layer.borderWidth = 1.5

        // Glow layer behind the card
        glowLayer.colors = [
            DesignTokens.Colors.accent.withAlphaComponent(0.4).cgColor,
            UIColor.clear.cgColor,
        ]
        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.opacity = 0
        layer.insertSublayer(glowLayer, at: 0)

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "moon.zzz", withConfiguration: config)
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.text = "No Mode"

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glowLayer.frame = bounds.insetBy(dx: -12, dy: -12)
    }

    func configure(isSelected: Bool) {
        let shouldAnimate = wasSelected != isSelected
        wasSelected = isSelected

        let duration: CFTimeInterval = isSelected ? 0.5 : 0.3
        let newBorderColor = isSelected ? DesignTokens.Colors.accent.cgColor : DesignTokens.Colors.separator.cgColor

        let applyColors = {
            self.contentView.backgroundColor = isSelected
                ? DesignTokens.Colors.accent.withAlphaComponent(0.15)
                : DesignTokens.Colors.surfaceSecondary
            self.iconView.tintColor = isSelected
                ? DesignTokens.Colors.accent
                : DesignTokens.Colors.textTertiary
            self.titleLabel.textColor = isSelected
                ? DesignTokens.Colors.accent
                : DesignTokens.Colors.textSecondary
        }

        guard shouldAnimate else {
            applyColors()
            contentView.layer.borderColor = newBorderColor
            return
        }

        // Animate border color via Core Animation
        let borderAnim = CABasicAnimation(keyPath: "borderColor")
        borderAnim.fromValue = contentView.layer.borderColor
        borderAnim.toValue = newBorderColor
        borderAnim.duration = duration
        borderAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentView.layer.borderColor = newBorderColor
        contentView.layer.add(borderAnim, forKey: "borderColor")

        if isSelected {
            transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 8) {
                self.transform = .identity
            }
            UIView.transition(with: contentView, duration: duration, options: .transitionCrossDissolve) {
                applyColors()
            }
            playGlowPulse()
        } else {
            UIView.transition(with: contentView, duration: duration, options: .transitionCrossDissolve) {
                applyColors()
            }
        }
    }

    private func playGlowPulse() {
        glowLayer.opacity = 0
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.6, 0.0]
        fade.keyTimes = [0.0, 0.3, 1.0]
        fade.duration = 0.6
        fade.isRemovedOnCompletion = true
        glowLayer.add(fade, forKey: "glowPulse")
    }
}

// MARK: - ModeCard

private final class ModeCard: UICollectionViewCell {

    private static let modeColor = NoteKind.mode.color

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let glowLayer = CAGradientLayer()
    private let shimmerLayer = CAGradientLayer()
    private let checkBadge = UIImageView()
    private var wasSelected = false
    private var isCurrentlySelected = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        NotificationCenter.default.addObserver(self, selector: #selector(resumeAnimations), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isCurrentlySelected { startActiveAnimations() }
    }

    @objc private func resumeAnimations() {
        if isCurrentlySelected { startActiveAnimations() }
    }

    func restartAnimationsIfNeeded() {
        guard isCurrentlySelected else { return }
        stopActiveAnimations()
        startActiveAnimations()
    }

    private func setupCell() {
        let mc = Self.modeColor
        clipsToBounds = false
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true
        contentView.layer.borderWidth = 1.5

        // Glow layer
        glowLayer.colors = [
            mc.withAlphaComponent(0.5).cgColor,
            UIColor.clear.cgColor,
        ]
        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.opacity = 0
        layer.insertSublayer(glowLayer, at: 0)

        // Shimmer layer (subtle)
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.08).cgColor,
            UIColor.clear.cgColor,
        ]
        shimmerLayer.locations = [0.0, 0.5, 1.0]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.cornerRadius = DesignTokens.Radii.lg
        shimmerLayer.isHidden = true
        contentView.layer.addSublayer(shimmerLayer)

        iconView.image = UIImage(systemName: "bolt.fill")
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)

        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.numberOfLines = 2

        // Check badge (top-right, hidden until selected)
        let badgeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        checkBadge.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: badgeConfig)
        checkBadge.tintColor = mc
        checkBadge.alpha = 0
        checkBadge.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        checkBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkBadge)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xs

        let topRow = UIStackView(arrangedSubviews: [iconView, textStack])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.md
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(topRow)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            topRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            topRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            topRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            topRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            checkBadge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.sm),
            checkBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.sm),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let newGlowFrame = bounds.insetBy(dx: -12, dy: -12)
        let glowChanged = glowLayer.frame != newGlowFrame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = newGlowFrame
        shimmerLayer.frame = contentView.bounds
        CATransaction.commit()

        // Restart animations if the frame changed so they render at the correct position
        if glowChanged && isCurrentlySelected {
            stopActiveAnimations()
            startActiveAnimations()
        }
    }

    func configure(with note: NotePage, isSelected: Bool) {
        let mc = Self.modeColor
        titleLabel.text = note.title
        bodyLabel.text = String(note.body.prefix(80))

        let shouldAnimate = wasSelected != isSelected
        print("[ModeCard] configure \(note.title) selected=\(isSelected) wasSelected=\(String(describing: wasSelected)) shouldAnimate=\(shouldAnimate)")
        wasSelected = isSelected
        isCurrentlySelected = isSelected

        let duration: CFTimeInterval = isSelected ? 0.55 : 0.3
        let newBorderColor = isSelected ? mc.cgColor : DesignTokens.Colors.separator.cgColor

        let applyColors = {
            self.contentView.backgroundColor = isSelected
                ? mc.withAlphaComponent(0.08)
                : DesignTokens.Colors.surfaceSecondary
            self.iconView.tintColor = isSelected ? mc : DesignTokens.Colors.textTertiary
            self.titleLabel.textColor = isSelected ? mc : DesignTokens.Colors.textPrimary
            self.bodyLabel.textColor = isSelected
                ? mc.withAlphaComponent(0.7)
                : DesignTokens.Colors.textSecondary
            DesignTokens.Shadows.apply(to: self.layer, elevation: isSelected ? .medium : .low)
            if isSelected {
                self.layer.shadowColor = mc.cgColor
                self.layer.shadowRadius = 10
                self.layer.shadowOpacity = 0.2
            }
        }

        let applyBadge = {
            self.checkBadge.alpha = isSelected ? 1 : 0
            self.checkBadge.transform = isSelected ? .identity : CGAffineTransform(scaleX: 0.3, y: 0.3)
        }

        if isSelected {
            startActiveAnimations()
        } else {
            stopActiveAnimations()
        }

        guard shouldAnimate else {
            applyColors()
            applyBadge()
            contentView.layer.borderColor = newBorderColor
            return
        }

        // Animate border color
        let borderAnim = CABasicAnimation(keyPath: "borderColor")
        borderAnim.fromValue = contentView.layer.borderColor
        borderAnim.toValue = newBorderColor
        borderAnim.duration = duration
        borderAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentView.layer.borderColor = newBorderColor
        contentView.layer.add(borderAnim, forKey: "borderColor")

        if isSelected {
            UIView.transition(with: contentView, duration: duration, options: .transitionCrossDissolve) {
                applyColors()
            }

            UIView.animate(withDuration: 0.4, delay: 0.05, usingSpringWithDamping: 0.5, initialSpringVelocity: 12) {
                applyBadge()
            }

            playGlowPulse()

            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2
            spin.duration = 0.4
            spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iconView.layer.add(spin, forKey: "selectSpin")
        } else {
            UIView.transition(with: contentView, duration: duration, options: .transitionCrossDissolve) {
                applyColors()
            }
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
                applyBadge()
            }
        }
    }

    // MARK: - Active Animations

    private func startActiveAnimations() {
        let mc = Self.modeColor

        // Icon pulse
        if iconView.layer.animation(forKey: "activePulse") == nil {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.08
            pulse.duration = 1.5
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iconView.layer.add(pulse, forKey: "activePulse")
        }

        // Border glow pulse
        if contentView.layer.animation(forKey: "glowPulse") == nil {
            let glow = CABasicAnimation(keyPath: "borderColor")
            glow.fromValue = mc.withAlphaComponent(0.6).cgColor
            glow.toValue = mc.withAlphaComponent(0.2).cgColor
            glow.duration = 2.0
            glow.autoreverses = true
            glow.repeatCount = .infinity
            glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            contentView.layer.add(glow, forKey: "glowPulse")
        }

        // Gradient border shimmer
        ShimmerBorder.add(to: contentView, color: mc, cornerRadius: DesignTokens.Radii.lg, borderWidth: 3)
    }

    private func stopActiveAnimations() {
        iconView.layer.removeAnimation(forKey: "activePulse")
        contentView.layer.removeAnimation(forKey: "glowPulse")
        shimmerLayer.removeAllAnimations()
        shimmerLayer.isHidden = true
        ShimmerBorder.remove(from: contentView)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
    }

    private func playGlowPulse() {
        glowLayer.opacity = 0
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.7, 0.0]
        fade.keyTimes = [0.0, 0.3, 1.0]
        fade.duration = 0.8
        fade.isRemovedOnCompletion = true
        glowLayer.add(fade, forKey: "glowFlash")
    }
}

// MARK: - ViewAllBalloonsCell

private final class ViewAllBalloonsCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countBadge = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: "balloon.2.fill", withConfiguration: config)
        iconView.tintColor = DesignTokens.Colors.warning
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        countBadge.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold)
        countBadge.textColor = .white
        countBadge.textAlignment = .center
        countBadge.backgroundColor = DesignTokens.Colors.warning
        countBadge.layer.cornerRadius = 10
        countBadge.clipsToBounds = true

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, spacer, countBadge, chevron])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            countBadge.heightAnchor.constraint(equalToConstant: 20),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(count: Int) {
        countBadge.text = " \(count) "
        titleLabel.text = count == 1 ? "1 balloon needs attention" : "\(count) balloons need attention"
        countBadge.backgroundColor = DesignTokens.Colors.destructive
    }
}

// MARK: - EmptyDirectivesCell

private final class EmptyDirectivesCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private let chevron = UIImageView()

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.5)
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: "plus.circle", withConfiguration: config)
        iconView.tintColor = DesignTokens.Colors.textTertiary
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        label.textColor = DesignTokens.Colors.textTertiary

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, label, UIView(), chevron])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure() {
        label.text = "No directives yet — tap to add"
    }
}

// MARK: - SectionHeaderWithActionView

final class SectionHeaderWithActionView: UICollectionReusableView {

    private let titleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var action: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textSecondary

        actionButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        actionButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        let dot = UILabel()
        dot.text = "·"
        dot.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        dot.textColor = DesignTokens.Colors.textTertiary

        let stack = UIStackView(arrangedSubviews: [titleLabel, dot, actionButton, UIView()])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.xs),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, actionTitle: String, action: @escaping () -> Void) {
        titleLabel.text = title.uppercased()
        actionButton.setTitle(actionTitle, for: .normal)
        self.action = action
    }

    @objc private func actionTapped() {
        action?()
    }
}

// MARK: - UICollectionViewDragDelegate

extension FocusViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .directive = item else { return [] }
        let provider = NSItemProvider(object: "\(indexPath)" as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = item
        return [dragItem]
    }
}

// MARK: - UICollectionViewDropDelegate

extension FocusViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // Only allow drops within the directives section
        if let dest = destinationIndexPath,
           let sectionIndex = dataSource.snapshot().sectionIdentifiers.firstIndex(of: .directives),
           dest.section == sectionIndex {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .cancel)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let dragItem = coordinator.items.first,
              let sourceRow = dragItem.dragItem.localObject as? FocusItem,
              let sourceIndexPath = dragItem.sourceIndexPath else { return }

        let snapshot = dataSource.snapshot()
        guard let directivesSectionIndex = snapshot.sectionIdentifiers.firstIndex(of: .directives),
              sourceIndexPath.section == directivesSectionIndex,
              destinationIndexPath.section == directivesSectionIndex else { return }

        var currentSnapshot = dataSource.snapshot()
        var sectionItems = currentSnapshot.itemIdentifiers(inSection: .directives)
        guard let sourceIndex = sectionItems.firstIndex(of: sourceRow) else { return }

        sectionItems.remove(at: sourceIndex)
        let destIndex = min(destinationIndexPath.item, sectionItems.count)
        sectionItems.insert(sourceRow, at: destIndex)

        currentSnapshot.deleteItems(currentSnapshot.itemIdentifiers(inSection: .directives))
        currentSnapshot.appendItems(sectionItems, toSection: .directives)
        dataSource.apply(currentSnapshot, animatingDifferences: true)

        coordinator.drop(dragItem.dragItem, toItemAt: destinationIndexPath)

        // Persist reorder
        guard let activeModeId, let noteService else { return }
        let directiveIds = sectionItems.compactMap { item -> UUID? in
            if case .directive(let data) = item { return data.directive.id }
            return nil
        }
        Task { try? await noteService.reorderDirectives(noteId: activeModeId, directiveIds: directiveIds) }
    }
}
