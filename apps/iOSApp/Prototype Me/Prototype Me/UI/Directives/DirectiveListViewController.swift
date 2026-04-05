import UIKit
import GRDB

nonisolated private enum DirectiveListSection: Sendable { case main }

nonisolated private enum DirectiveFilter: Int, CaseIterable, Sendable {
    case all, active, archived
    var title: String {
        switch self {
        case .all: "All"
        case .active: "Active"
        case .archived: "Archived"
        }
    }
}

class DirectiveListViewController: BaseViewController {

    var directiveService: DirectiveService?
    var onDirectiveSelected: ((UUID) -> Void)?
    var onAddTapped: (() -> Void)?
    var onAskAIForDirective: ((UUID) -> Void)?
    var isEmbedded = false

    private var searchBar: UISearchBar!
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DirectiveListSection, DirectiveRowData>!
    private var allItems: [DirectiveRowData] = []
    private var currentFilter: DirectiveFilter = .all
    private var searchText = ""

    private let infoPill = UIButton(type: .system)
    private let addBanner = UIButton(type: .system)
    private var searchTrailingToPill: NSLayoutConstraint!
    private var searchTrailingToView: NSLayoutConstraint!
    private static let hasSeenStoryKey = "hasSeenDirectiveStory"

    override func viewDidLoad() {
        if isEmbedded { hidesNavBar = true }
        super.viewDidLoad()
        if !isEmbedded {
            navBar.setRightButtons([
                NavBarButton(systemImage: "plus", action: { [weak self] in self?.addTapped() }),
            ])
        }
        configureSegmentedControl()
        configureInfoPill()
        configureSearchBar()
        configureAddBanner()
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !UserDefaults.standard.bool(forKey: Self.hasSeenStoryKey) {
            ShimmerBorder.restart(on: infoPill)
        }
    }

    // MARK: - Segmented Control

    private func configureSegmentedControl() {
        let segmented = UISegmentedControl(items: DirectiveFilter.allCases.map(\.title))
        segmented.selectedSegmentIndex = 0
        segmented.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
        navBar.setTitleView(segmented)
    }

    // MARK: - Info Pill

    private func configureInfoPill() {
        let hasSeen = UserDefaults.standard.bool(forKey: Self.hasSeenStoryKey)

        var config = UIButton.Configuration.filled()
        config.title = "What are Directives?"
        config.image = UIImage(systemName: "questionmark.circle.fill")
        config.imagePadding = DesignTokens.Spacing.xs
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12)
        config.cornerStyle = .capsule
        config.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
            return c
        }

        if hasSeen {
            config.background.backgroundColor = DesignTokens.Colors.surfaceSecondary
            config.baseForegroundColor = DesignTokens.Colors.textSecondary
        } else {
            config.background.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.15)
            config.baseForegroundColor = DesignTokens.Colors.accent
        }
        config.background.cornerRadius = DesignTokens.Radii.pill
        infoPill.configuration = config
        infoPill.addTarget(self, action: #selector(infoPillTapped), for: .touchUpInside)
        infoPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        infoPill.setContentHuggingPriority(.required, for: .horizontal)

        infoPill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoPill)

        NSLayoutConstraint.activate([
            infoPill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        if !hasSeen {
            startInfoPillPulse()
        }
    }

    private func startInfoPillPulse() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        infoPill.layer.shadowColor = DesignTokens.Colors.accent.cgColor
        infoPill.layer.shadowRadius = 8
        infoPill.layer.shadowOpacity = 0.4
        infoPill.layer.shadowOffset = .zero

        let glow = CABasicAnimation(keyPath: "shadowRadius")
        glow.fromValue = 4
        glow.toValue = 12
        glow.duration = 1.2
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        infoPill.layer.add(glow, forKey: "glowPulse")

        let opacityPulse = CABasicAnimation(keyPath: "shadowOpacity")
        opacityPulse.fromValue = 0.2
        opacityPulse.toValue = 0.5
        opacityPulse.duration = 1.2
        opacityPulse.autoreverses = true
        opacityPulse.repeatCount = .infinity
        opacityPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        infoPill.layer.add(opacityPulse, forKey: "opacityPulse")

        infoPill.clipsToBounds = false
        DispatchQueue.main.async {
            let pillHeight = self.infoPill.bounds.height
            ShimmerBorder.add(
                to: self.infoPill,
                color: DesignTokens.Colors.accent,
                cornerRadius: pillHeight / 2
            )
        }
    }

    @objc private func infoPillTapped() {
        Haptics.light()

        if !UserDefaults.standard.bool(forKey: Self.hasSeenStoryKey) {
            UserDefaults.standard.set(true, forKey: Self.hasSeenStoryKey)
            infoPill.layer.removeAnimation(forKey: "glowPulse")
            infoPill.layer.removeAnimation(forKey: "opacityPulse")
            infoPill.layer.shadowOpacity = 0
            ShimmerBorder.remove(from: infoPill)

            var config = infoPill.configuration
            config?.background.backgroundColor = DesignTokens.Colors.surfaceSecondary
            config?.baseForegroundColor = DesignTokens.Colors.textSecondary
            infoPill.configuration = config
        }

        let storyVC = DirectiveStoryViewController()
        storyVC.modalPresentationStyle = .overFullScreen
        storyVC.modalTransitionStyle = .coverVertical
        present(storyVC, animated: true)
    }

    // MARK: - Search Bar

    private func configureSearchBar() {
        searchBar = UISearchBar()
        searchBar.placeholder = "Search directives"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.tintColor = DesignTokens.Colors.accent
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        // Two mutually-exclusive trailing constraints
        searchTrailingToPill = searchBar.trailingAnchor.constraint(equalTo: infoPill.leadingAnchor, constant: -DesignTokens.Spacing.xs)
        searchTrailingToView = searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.sm)
        searchTrailingToPill.isActive = true
        searchTrailingToView.isActive = false

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentTopAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.sm),
            infoPill.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
        ])
    }

    private func setSearchActive(_ active: Bool) {
        searchBar.setShowsCancelButton(active, animated: true)
        searchTrailingToPill.isActive = !active
        searchTrailingToView.isActive = active

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.infoPill.alpha = active ? 0 : 1
            self.infoPill.transform = active ? CGAffineTransform(translationX: 40, y: 0) : .identity
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Add Banner

    private func configureAddBanner() {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "plus.circle.fill")
        config.title = "Add New Directive"
        config.imagePadding = DesignTokens.Spacing.sm
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.md,
            leading: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.md,
            trailing: DesignTokens.Spacing.lg
        )
        config.cornerStyle = .large
        config.background.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        config.baseForegroundColor = DesignTokens.Colors.accent
        config.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
            return c
        }

        addBanner.configuration = config
        addBanner.addTarget(self, action: #selector(addBannerTapped), for: .touchUpInside)
        addBanner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addBanner)

        NSLayoutConstraint.activate([
            addBanner.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: DesignTokens.Spacing.xs),
            addBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            addBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    @objc private func addBannerTapped() {
        Haptics.light()
        addTapped()
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: addBanner.bottomAnchor, constant: DesignTokens.Spacing.xs),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.confirmDelete(directiveId: item.directive.id)
                completion(true)
            }
            deleteAction.backgroundColor = DesignTokens.Colors.destructive
            deleteAction.image = UIImage(systemName: "trash")

            let askAction = UIContextualAction(style: .normal, title: "Not Working?") { [weak self] _, _, completion in
                self?.confirmAskAI(directiveId: item.directive.id)
                completion(true)
            }
            askAction.backgroundColor = DesignTokens.Colors.warning
            askAction.image = UIImage(systemName: "lightbulb.slash")

            let swipeConfig = UISwipeActionsConfiguration(actions: [deleteAction, askAction])
            swipeConfig.performsFirstActionWithFullSwipe = false
            return swipeConfig
        }
        return UICollectionViewCompositionalLayout { _, layoutEnv in
            let sectionConfig = config
            let section = NSCollectionLayoutSection.list(using: sectionConfig, layoutEnvironment: layoutEnv)
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

    private func confirmAskAI(directiveId: UUID) {
        let alert = UIAlertController(
            title: "Ask AI for an alternative?",
            message: "This opens the Speak tab and asks the AI to help figure out what's not working with this directive and suggest alternatives you could try.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Ask AI", style: .default) { [weak self] _ in
            self?.onAskAIForDirective?(directiveId)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func confirmDelete(directiveId: UUID) {
        let title = try? dbQueue.read { db in try Directive.fetchOne(db, key: directiveId)?.title }

        let alert = UIAlertController(
            title: "Permanently Delete Directive?",
            message: "This will permanently delete \"\(title ?? "this directive")\" and everything associated with it — including its balloon timer, schedule, linked notes, and all history.\n\nThis cannot be undone.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete Permanently", style: .destructive) { [weak self] _ in
            Task {
                try? await self?.directiveService?.delete(id: directiveId)
                await MainActor.run { Haptics.success() }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, item in
            cell.configure(with: item)
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource<DirectiveListSection, DirectiveRowData>(collectionView: collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        let observation = ValueObservation.tracking { db -> [DirectiveRowData] in
            let directives = try Directive.order(Column("createdAt").desc).fetchAll(db)
            let allRules = try ScheduleRule.fetchAll(db)
            return directives.map { dir in
                let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                return DirectiveRowData(
                    directive: dir,
                    scheduledToday: scheduled
                )
            }
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] items in
            self?.allItems = items
            self?.applyFilter()
        })
    }

    private func addTapped() { onAddTapped?() }

    @objc private func filterChanged(_ sender: UISegmentedControl) {
        currentFilter = DirectiveFilter(rawValue: sender.selectedSegmentIndex) ?? .all
        applyFilter()
    }

    private func applyFilter() {
        var filtered: [DirectiveRowData] = switch currentFilter {
        case .all:      allItems.filter { $0.directive.status != .archived }
        case .active:   allItems.filter { $0.directive.status == .active }
        case .archived: allItems.filter { $0.directive.status == .archived }
        }
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.directive.title.localizedCaseInsensitiveContains(searchText) }
        }
        var snapshot = NSDiffableDataSourceSnapshot<DirectiveListSection, DirectiveRowData>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filtered)
        dataSource.apply(snapshot, animatingDifferences: true)

        // Force cell reconfiguration since model equality is id-only
        var reconfigSnap = dataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        dataSource.apply(reconfigSnap, animatingDifferences: false)
    }
}

// MARK: - UISearchBarDelegate

extension DirectiveListViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        setSearchActive(true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        applyFilter()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchText = ""
        searchBar.resignFirstResponder()
        setSearchActive(false)
        applyFilter()
    }
}

// MARK: - UICollectionViewDelegate

extension DirectiveListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        onDirectiveSelected?(item.directive.id)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let askAI = UIAction(
                title: "Not Working?",
                image: UIImage(systemName: "lightbulb.slash")
            ) { _ in
                self?.confirmAskAI(directiveId: item.directive.id)
            }
            let delete = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self?.confirmDelete(directiveId: item.directive.id)
            }
            return UIMenu(children: [askAI, delete])
        }
    }
}
