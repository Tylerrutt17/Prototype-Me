import UIKit
import GRDB

nonisolated private enum NoteListSection: Int, Hashable, Sendable {
    case framework
    case folders
    case notes
}

nonisolated private enum NoteListRow: Hashable, Sendable {
    case framework(NotePage)
    case folder(Folder)
    case note(NoteListItem)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .framework(let n): hasher.combine("fw"); hasher.combine(n.id)
        case .folder(let f): hasher.combine("f"); hasher.combine(f.id)
        case .note(let n):   hasher.combine("n"); hasher.combine(n.note.id)
        }
    }

    static func == (lhs: NoteListRow, rhs: NoteListRow) -> Bool {
        switch (lhs, rhs) {
        case (.framework(let a), .framework(let b)): return a.id == b.id
        case (.folder(let a), .folder(let b)): return a.id == b.id
        case (.note(let a), .note(let b)):     return a.note.id == b.note.id
        default: return false
        }
    }
}

class NoteListViewController: BaseViewController {

    var onNoteSelected: ((UUID) -> Void)?
    var onEditNoteTapped: ((UUID) -> Void)?
    var onFolderSelected: ((UUID) -> Void)?
    var onEditFolderTapped: ((UUID) -> Void)?
    var onAddNoteTapped: (() -> Void)?
    var onAddFolderTapped: (() -> Void)?
    var onMoveNoteTapped: ((UUID) -> Void)?
    var onMoveFolderTapped: ((UUID) -> Void)?
    var onDirectivesTapped: (() -> Void)?
    var onBalloonsTapped: (() -> Void)?

    /// When embedded in LibraryContainerVC, hide own nav bar
    var isEmbedded = false

    var noteService: NoteService?
    var folderService: FolderService?

    /// The folder being viewed. nil = root level.
    var currentFolderId: UUID?
    var folderName: String?
    /// Optional filter by note kind (e.g. .situation to show only situations)
    var filterKind: NoteKind?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<NoteListSection, NoteListRow>!

    override func viewDidLoad() {
        if isEmbedded { hidesNavBar = true }
        super.viewDidLoad()

        if !isEmbedded {
            let title = folderName ?? "Notes"
            navBar.setTitle(title, animated: false)

            if currentFolderId != nil {
                navBar.setShowsBackButton(true)
                navBar.onBackTapped = { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            }

            navBar.setRightButtons([
                NavBarButton(systemImage: "folder.badge.plus", action: { [weak self] in self?.onAddFolderTapped?() }),
                NavBarButton(systemImage: "plus", action: { [weak self] in self?.onAddNoteTapped?() }),
            ])
        }

        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.contentInset.top = DesignTokens.Spacing.md
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
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        config.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self, let row = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
            switch row {
            case .framework(let note):
                let editAction = UIContextualAction(style: .normal, title: "Edit") { _, _, completion in
                    self.onEditNoteTapped?(note.id)
                    completion(true)
                }
                editAction.backgroundColor = DesignTokens.Colors.accent
                let moveAction = UIContextualAction(style: .normal, title: "Move") { _, _, completion in
                    self.onMoveNoteTapped?(note.id)
                    completion(true)
                }
                moveAction.backgroundColor = DesignTokens.Colors.textSecondary
                return UISwipeActionsConfiguration(actions: [editAction, moveAction])
            case .note(let item):
                let editAction = UIContextualAction(style: .normal, title: "Edit") { _, _, completion in
                    self.onEditNoteTapped?(item.note.id)
                    completion(true)
                }
                editAction.backgroundColor = DesignTokens.Colors.accent
                let moveAction = UIContextualAction(style: .normal, title: "Move") { _, _, completion in
                    self.onMoveNoteTapped?(item.note.id)
                    completion(true)
                }
                moveAction.backgroundColor = DesignTokens.Colors.textSecondary
                let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                    self.confirmDeleteNote(noteId: item.note.id)
                    completion(true)
                }
                deleteAction.backgroundColor = DesignTokens.Colors.destructive
                return UISwipeActionsConfiguration(actions: [deleteAction, editAction, moveAction])
            case .folder(let folder):
                let editAction = UIContextualAction(style: .normal, title: "Edit") { _, _, completion in
                    self.onEditFolderTapped?(folder.id)
                    completion(true)
                }
                editAction.backgroundColor = DesignTokens.Colors.accent
                let moveAction = UIContextualAction(style: .normal, title: "Move") { _, _, completion in
                    self.onMoveFolderTapped?(folder.id)
                    completion(true)
                }
                moveAction.backgroundColor = DesignTokens.Colors.textSecondary
                let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
                    self.confirmDeleteFolder(folderId: folder.id, name: folder.name)
                    completion(true)
                }
                deleteAction.backgroundColor = DesignTokens.Colors.destructive
                return UISwipeActionsConfiguration(actions: [deleteAction, editAction, moveAction])
            }
        }
        return UICollectionViewCompositionalLayout { _, layoutEnv in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnv)
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

    private func confirmDeleteNote(noteId: UUID) {
        let alert = UIAlertController(title: "Delete Note", message: "Are you sure?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                try? await self?.noteService?.delete(id: noteId)
                await MainActor.run { Haptics.success() }
            }
        })
        present(alert, animated: true)
    }

    private func confirmDeleteFolder(folderId: UUID, name: String) {
        let alert = UIAlertController(title: "Delete Folder", message: "Delete \"\(name)\" and all its contents?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            Task {
                try? await self?.folderService?.delete(id: folderId)
                await MainActor.run { Haptics.success() }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let frameworkCellReg = UICollectionView.CellRegistration<FrameworkCard, NotePage> { cell, _, note in
            cell.configure(with: note)
        }

        let folderCellReg = UICollectionView.CellRegistration<FolderCell, Folder> { cell, _, folder in
            cell.configure(with: folder)
        }

        let noteCellReg = UICollectionView.CellRegistration<NoteCell, NoteListItem> { cell, _, item in
            cell.configure(with: item)
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, row in
            switch row {
            case .framework(let note):
                return cv.dequeueConfiguredReusableCell(using: frameworkCellReg, for: indexPath, item: note)
            case .folder(let folder):
                return cv.dequeueConfiguredReusableCell(using: folderCellReg, for: indexPath, item: folder)
            case .note(let item):
                return cv.dequeueConfiguredReusableCell(using: noteCellReg, for: indexPath, item: item)
            }
        }

    }

    // MARK: - Observe Data

    private func loadData() {
        let parentId = currentFolderId
        let kindFilter = filterKind
        let isRoot = parentId == nil && kindFilter == nil

        let observation = ValueObservation.tracking { db -> (NotePage?, [Folder], [NoteListItem]) in
            // Framework note — only at root, not when filtering by kind
            let frameworkNote: NotePage?
            if isRoot {
                frameworkNote = try NotePage
                    .filter(Column("kind") == NoteKind.framework.rawValue)
                    .fetchOne(db)
            } else {
                frameworkNote = nil
            }

            // When filtering by kind, skip folders — show flat note list
            let folders: [Folder]
            if kindFilter != nil {
                folders = []
            } else if let parentId {
                folders = try Folder
                    .filter(Column("parentFolderId") == parentId)
                    .order(Column("sortIndex"))
                    .fetchAll(db)
            } else {
                folders = try Folder
                    .filter(Column("parentFolderId") == nil)
                    .order(Column("sortIndex"))
                    .fetchAll(db)
            }

            // Notes — either filtered by kind (all notes of that kind) or by folder level
            var query = NotePage.order(Column("sortIndex"))
            if let kindFilter {
                query = query.filter(Column("kind") == kindFilter.rawValue)
            } else if let parentId {
                query = query.filter(Column("folderId") == parentId)
            } else {
                // Root level: exclude framework notes (they're pinned above)
                query = query.filter(Column("folderId") == nil)
                    .filter(Column("kind") != NoteKind.framework.rawValue)
            }
            let notes = try query.fetchAll(db)

            let noteItems = notes.map { note in
                let dirCount = try! NoteDirective
                    .filter(Column("noteId") == note.id)
                    .fetchCount(db)
                return NoteListItem(note: note, directiveCount: dirCount, folderName: nil)
            }

            return (frameworkNote, folders, noteItems)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] (fw, folders, notes) in
            self?.applySnapshot(frameworkNote: fw, folders: folders, notes: notes)
        })
    }

    private func applySnapshot(frameworkNote: NotePage?, folders: [Folder], notes: [NoteListItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<NoteListSection, NoteListRow>()

        if let fw = frameworkNote {
            snapshot.appendSections([.framework])
            snapshot.appendItems([.framework(fw)], toSection: .framework)
        }

        if !folders.isEmpty {
            snapshot.appendSections([.folders])
            snapshot.appendItems(folders.map { .folder($0) }, toSection: .folders)
        }

        if !notes.isEmpty {
            snapshot.appendSections([.notes])
            snapshot.appendItems(notes.map { .note($0) }, toSection: .notes)
        }

        dataSource.apply(snapshot, animatingDifferences: true)

        var reconfigSnap = dataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        dataSource.apply(reconfigSnap, animatingDifferences: false)
    }

    // MARK: - Actions

    private func showAddMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Note", style: .default) { [weak self] _ in
            self?.onAddNoteTapped?()
        })
        sheet.addAction(UIAlertAction(title: "New Folder", style: .default) { [weak self] _ in
            self?.onAddFolderTapped?()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func showMoreMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Directives", style: .default) { [weak self] _ in
            self?.onDirectivesTapped?()
        })
        sheet.addAction(UIAlertAction(title: "Balloons", style: .default) { [weak self] _ in
            self?.onBalloonsTapped?()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}

// MARK: - UICollectionViewDelegate

extension NoteListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }
        switch row {
        case .framework(let note):
            onNoteSelected?(note.id)
        case .folder(let folder):
            onFolderSelected?(folder.id)
        case .note(let item):
            onNoteSelected?(item.note.id)
        }
    }
}

// MARK: - UICollectionViewDragDelegate

extension NoteListViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return [] }
        // Framework note can't be dragged
        if case .framework = row { return [] }
        let itemProvider = NSItemProvider(object: "\(indexPath)" as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = row
        return [dragItem]
    }
}

// MARK: - UICollectionViewDropDelegate

extension NoteListViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // Only allow reordering within the same section
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        // The diffable data source handles the visual reorder via the drop coordinator.
        // We need to manually update our snapshot and persist.
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let dragItem = coordinator.items.first,
              let sourceRow = dragItem.dragItem.localObject as? NoteListRow,
              let sourceIndexPath = dragItem.sourceIndexPath else { return }

        // Only allow drops within the same section
        guard sourceIndexPath.section == destinationIndexPath.section else { return }

        var snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[sourceIndexPath.section]

        // Get current items in this section
        var sectionItems = snapshot.itemIdentifiers(inSection: section)
        guard let sourceIndex = sectionItems.firstIndex(of: sourceRow) else { return }

        // Move the item
        sectionItems.remove(at: sourceIndex)
        let destIndex = min(destinationIndexPath.item, sectionItems.count)
        sectionItems.insert(sourceRow, at: destIndex)

        // Rebuild just this section in the snapshot
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: section))
        snapshot.appendItems(sectionItems, toSection: section)
        dataSource.apply(snapshot, animatingDifferences: true)

        coordinator.drop(dragItem.dragItem, toItemAt: destinationIndexPath)

        // Persist the new order
        switch section {
        case .folders:
            let folderIds = sectionItems.compactMap { row -> UUID? in
                if case .folder(let f) = row { return f.id }
                return nil
            }
            Task { try? await folderService?.reorderFolders(ids: folderIds) }
        case .notes:
            let noteIds = sectionItems.compactMap { row -> UUID? in
                if case .note(let item) = row { return item.note.id }
                return nil
            }
            Task { try? await noteService?.reorderNotes(ids: noteIds) }
        case .framework:
            break
        }
    }
}

// MARK: - FolderCell

private final class FolderCell: InteractiveCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "folder.fill", withConfiguration: config)
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        countLabel.font = DesignTokens.Typography.caption1
        countLabel.textColor = DesignTokens.Colors.textTertiary

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconView, titleLabel, spacer, countLabel, chevron])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with folder: Folder) {
        titleLabel.text = folder.name
    }
}

// MARK: - FrameworkCard

private final class FrameworkCard: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        let gold = NoteKind.framework.color
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        // Gradient background
        let gradient = CAGradientLayer()
        gradient.colors = [
            gold.withAlphaComponent(0.15).cgColor,
            gold.withAlphaComponent(0.05).cgColor,
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        contentView.layer.insertSublayer(gradient, at: 0)

        // Border
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = gold.withAlphaComponent(0.3).cgColor

        let starConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        iconView.image = UIImage(systemName: "star.fill", withConfiguration: starConfig)
        iconView.tintColor = gold
        iconView.contentMode = .scaleAspectFit

        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.text = "Your personal values and principles"

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor = gold
        chevron.contentMode = .scaleAspectFit

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconView, textStack, spacer, chevron])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 36),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let gradient = contentView.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = contentView.bounds
        }
    }

    func configure(with note: NotePage) {
        titleLabel.text = note.title.isEmpty ? "My Framework" : note.title
    }
}
