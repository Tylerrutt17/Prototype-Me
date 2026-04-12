import UIKit
import GRDB

// MARK: - Shared Section / Item enums

nonisolated enum NoteDetailSection: Int, Sendable {
    case header
    case directives
}

nonisolated enum NoteDetailItem: Hashable, Sendable {
    case header
    case directive(DirectiveRowData)
    case linkButton

    func hash(into hasher: inout Hasher) {
        switch self {
        case .header:              hasher.combine("header")
        case .directive(let data): hasher.combine("dir"); hasher.combine(data.directive.id)
        case .linkButton:          hasher.combine("linkBtn")
        }
    }
    static func == (lhs: NoteDetailItem, rhs: NoteDetailItem) -> Bool {
        switch (lhs, rhs) {
        case (.header, .header):                              return true
        case (.directive(let a), .directive(let b)):          return a.directive.id == b.directive.id
        case (.linkButton, .linkButton):                      return true
        default:                                              return false
        }
    }
}

// MARK: - Base VC

/// Shared base for NoteDetailViewController and ModeDetailViewController.
/// Handles the entire directives section (layout, swipe, context menu, drag/drop,
/// link/unlink, reorder). Subclasses only provide their header cell and data loading.
class NoteDetailBaseViewController: BaseViewController {

    var noteId: UUID?
    var noteService: NoteService?
    var onDirectiveSelected: ((UUID) -> Void)?
    var onEditTapped: ((UUID) -> Void)?
    var onLinkDirectiveTapped: ((UUID) -> Void)?
    var onAskAIForDirective: ((UUID) -> Void)?

    private(set) var collectionView: UICollectionView!
    private(set) var dataSource: UICollectionViewDiffableDataSource<NoteDetailSection, NoteDetailItem>!

    // MARK: - Subclass Hooks

    /// Estimated height for the header section. Override in subclass.
    var headerEstimatedHeight: CGFloat { 200 }

    /// Label for unlink alerts — "note" or "mode". Override in subclass.
    var entityLabel: String { "note" }

    /// Subclass must override to dequeue its specific header cell.
    func dequeueHeaderCell(for collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        fatalError("Subclasses must override dequeueHeaderCell")
    }

    /// Subclass must override to start its GRDB observation and call `applySnapshot`.
    func loadData() {
        fatalError("Subclasses must override loadData")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setRightButtons([
            NavBarButton(assetImage: "edit", action: { [weak self] in self?.editTapped() }),
        ])
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    private func editTapped() {
        guard let noteId else { return }
        onEditTapped?(noteId)
    }

    /// Persists inline title/body edits from the header cell.
    func saveInlineEdit(title: String, body: String) {
        guard let noteId, let noteService else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                var note = try await noteService.fetch(id: noteId)
                guard var note else { return }
                note.title = trimmedTitle
                note.body = trimmedBody
                try await noteService.update(note)
            } catch {
                print("Inline note edit save failed: \(error)")
            }
        }
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnv in
            let section = NoteDetailSection(rawValue: sectionIndex)
            switch section {
            case .header:
                let height = self?.headerEstimatedHeight ?? 200
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(height))
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
                var config = UICollectionLayoutListConfiguration(appearance: .plain)
                config.backgroundColor = .clear
                config.showsSeparators = false
                config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                    guard let self,
                          let item = self.dataSource.itemIdentifier(for: indexPath),
                          case .directive(let data) = item else { return nil }
                    let unlink = UIContextualAction(style: .normal, title: "Unlink") { [weak self] _, _, completion in
                        self?.confirmUnlink(directiveId: data.directive.id)
                        completion(true)
                    }
                    unlink.backgroundColor = DesignTokens.Colors.destructive
                    unlink.image = UIImage(systemName: "link.badge.minus")

                    let askAI = UIContextualAction(style: .normal, title: "Not Working?") { [weak self] _, _, completion in
                        self?.confirmAskAI(directiveId: data.directive.id)
                        completion(true)
                    }
                    askAI.backgroundColor = DesignTokens.Colors.warning
                    askAI.image = UIImage(systemName: "lightbulb.slash")

                    let swipeConfig = UISwipeActionsConfiguration(actions: [unlink, askAI])
                    swipeConfig.performsFirstActionWithFullSwipe = false
                    return swipeConfig
                }
                let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnv)
                layoutSection.interGroupSpacing = DesignTokens.Spacing.sm
                layoutSection.contentInsets = NSDirectionalEdgeInsets(
                    top: DesignTokens.Spacing.sm,
                    leading: DesignTokens.Spacing.lg,
                    bottom: DesignTokens.Spacing.lg,
                    trailing: DesignTokens.Spacing.lg
                )

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

    // MARK: - Alerts

    private func confirmAskAI(directiveId: UUID) {
        let alert = UIAlertController(
            title: "Ask Feature for an alternative?",
            message: "This opens Ask Feature to help figure out what's not working with this directive and suggest alternatives you could try.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Ask Feature", style: .default) { [weak self] _ in
            self?.onAskAIForDirective?(directiveId)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func confirmUnlink(directiveId: UUID) {
        let alert = UIAlertController(
            title: "Unlink Directive?",
            message: "This removes it from this \(entityLabel). The directive itself won't be deleted.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Unlink", style: .destructive) { [weak self] _ in
            self?.unlinkDirective(directiveId: directiveId)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func unlinkDirective(directiveId: UUID) {
        guard let noteId else { return }
        Task {
            do {
                try await noteService?.unlinkDirective(noteId: noteId, directiveId: directiveId)
                await MainActor.run { Haptics.success() }
            } catch {
                await MainActor.run { Haptics.error() }
            }
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let directiveReg = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, data in
            cell.configure(with: data)
        }

        let linkBtnReg = UICollectionView.CellRegistration<LinkButtonCell, String> { cell, _, title in
            cell.configure(title: title, systemImage: "plus.circle.fill")
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] cv, indexPath, item in
            guard let self else { return UICollectionViewCell() }
            switch item {
            case .header:
                return self.dequeueHeaderCell(for: cv, at: indexPath)
            case .directive(let data):
                return cv.dequeueConfiguredReusableCell(using: directiveReg, for: indexPath, item: data)
            case .linkButton:
                return cv.dequeueConfiguredReusableCell(using: linkBtnReg, for: indexPath, item: "Add Directive")
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = NoteDetailSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .directives: "Linked Directives"
            default:          ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { cv, kind, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Snapshot (called by subclasses)

    /// Subclasses call this from their `loadData` observation to apply the shared snapshot.
    func applySnapshot(directives: [DirectiveRowData]) {
        var snapshot = NSDiffableDataSourceSnapshot<NoteDetailSection, NoteDetailItem>()

        snapshot.appendSections([.header])
        snapshot.appendItems([.header], toSection: .header)

        snapshot.appendSections([.directives])
        var dirItems: [NoteDetailItem] = directives.map { .directive($0) }
        dirItems.append(.linkButton)
        snapshot.appendItems(dirItems, toSection: .directives)

        dataSource.apply(snapshot, animatingDifferences: false)

        var reconfigSnap = dataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        dataSource.apply(reconfigSnap, animatingDifferences: false)
    }

}

// MARK: - UICollectionViewDelegate

extension NoteDetailBaseViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .header:
            break
        case .directive(let data):
            onDirectiveSelected?(data.directive.id)
        case .linkButton:
            guard let noteId else { return }
            onLinkDirectiveTapped?(noteId)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .directive(let data) = item else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let askAI = UIAction(
                title: "Not Working?",
                image: UIImage(systemName: "lightbulb.slash")
            ) { _ in
                self?.confirmAskAI(directiveId: data.directive.id)
            }
            let unlink = UIAction(
                title: "Unlink from \(self?.entityLabel.capitalized ?? "Note")",
                image: UIImage(systemName: "link.badge.minus"),
                attributes: .destructive
            ) { _ in
                self?.confirmUnlink(directiveId: data.directive.id)
            }
            return UIMenu(children: [askAI, unlink])
        }
    }
}

// MARK: - UICollectionViewDragDelegate

extension NoteDetailBaseViewController: UICollectionViewDragDelegate {
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

extension NoteDetailBaseViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        if let dest = destinationIndexPath, dest.section == NoteDetailSection.directives.rawValue {
            return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UICollectionViewDropProposal(operation: .cancel)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let dragItem = coordinator.items.first,
              let sourceRow = dragItem.dragItem.localObject as? NoteDetailItem,
              let sourceIndexPath = dragItem.sourceIndexPath else { return }

        let directivesSection = NoteDetailSection.directives.rawValue
        guard sourceIndexPath.section == directivesSection,
              destinationIndexPath.section == directivesSection else { return }

        var snapshot = dataSource.snapshot()
        let section = NoteDetailSection.directives
        var sectionItems = snapshot.itemIdentifiers(inSection: section)
        guard let sourceIndex = sectionItems.firstIndex(of: sourceRow) else { return }

        sectionItems.remove(at: sourceIndex)
        let linkButtonIndex = sectionItems.firstIndex {
            if case .linkButton = $0 { return true }
            return false
        }
        let maxIndex = linkButtonIndex ?? sectionItems.count
        let destIndex = min(destinationIndexPath.item, maxIndex)
        sectionItems.insert(sourceRow, at: destIndex)

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: section))
        snapshot.appendItems(sectionItems, toSection: section)
        dataSource.apply(snapshot, animatingDifferences: true)

        coordinator.drop(dragItem.dragItem, toItemAt: destinationIndexPath)

        // Persist reorder
        guard let noteId, let noteService else { return }
        let directiveIds = sectionItems.compactMap { item -> UUID? in
            if case .directive(let data) = item { return data.directive.id }
            return nil
        }
        Task { try? await noteService.reorderDirectives(noteId: noteId, directiveIds: directiveIds) }
    }
}
