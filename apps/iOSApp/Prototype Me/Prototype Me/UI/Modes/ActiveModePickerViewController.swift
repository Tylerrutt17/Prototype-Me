import UIKit
import GRDB

/// Lets the user pick a single active mode, or "No Mode" to deactivate.
final class ActiveModePickerViewController: BaseViewController {

    var modeService: ModeService?
    var noteService: NoteService?
    var onDone: (() -> Void)?
    var onCreateMode: (() -> Void)?
    var onModeSelected: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, ModePickerRow>!
    private var activeModeId: UUID?

    nonisolated private enum Section: Sendable { case main }

    nonisolated private enum ModePickerRow: Hashable, Sendable {
        case noMode
        case mode(NotePage)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .noMode:         hasher.combine("noMode")
            case .mode(let n):    hasher.combine(n.id)
            }
        }

        static func == (lhs: ModePickerRow, rhs: ModePickerRow) -> Bool {
            switch (lhs, rhs) {
            case (.noMode, .noMode):                   return true
            case (.mode(let a), .mode(let b)):         return a.id == b.id
            default:                                   return false
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Select Mode", animated: false)
        navBar.setLeftButton(title: "Done", systemImage: nil, action: { [weak self] in
            self?.onDone?()
        })
        navBar.setRightButtons([
            NavBarButton(systemImage: "plus", action: { [weak self] in
                self?.onCreateMode?()
            }),
        ])

        buildUI()
        configureDataSource()
        loadData()

        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
    }

    // MARK: - UI

    private func buildUI() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
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

    // MARK: - Data Source

    private func configureDataSource() {
        let cellReg = UICollectionView.CellRegistration<ModePickerCell, ModePickerRow> { [weak self] cell, _, row in
            let activeId = self?.activeModeId
            switch row {
            case .noMode:
                cell.configureNoMode(isSelected: activeId == nil)
                cell.onChevronTapped = nil
            case .mode(let note):
                cell.configure(with: note, isActive: note.id == activeId)
                cell.onChevronTapped = { [weak self] in
                    self?.onDone?()
                    self?.onModeSelected?(note.id)
                }
            }
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, row in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: row)
        }
    }

    // MARK: - Observation

    private func loadData() {
        let observation = ValueObservation.tracking { db -> (UUID?, [NotePage]) in
            let modes = try NotePage
                .filter(Column("kind") == NoteKind.mode.rawValue)
                .order(Column("sortIndex"))
                .fetchAll(db)
            let activeId = try ActiveMode.fetchOne(db)?.noteId
            return (activeId, modes)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] (activeId, modes) in
            guard let self else { return }
            self.activeModeId = activeId

            var rows: [ModePickerRow] = [.noMode]
            rows.append(contentsOf: modes.map { .mode($0) })

            var snapshot = NSDiffableDataSourceSnapshot<Section, ModePickerRow>()
            snapshot.appendSections([.main])
            snapshot.appendItems(rows)
            self.dataSource.apply(snapshot, animatingDifferences: false)

            var reconfigSnap = self.dataSource.snapshot()
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self.dataSource.apply(reconfigSnap, animatingDifferences: false)
        })
    }

    // MARK: - Select

    private func selectMode(_ row: ModePickerRow) {
        let newModeId: UUID? = if case .mode(let note) = row { note.id } else { nil }
        Task {
            do {
                try await modeService?.switchTo(noteId: newModeId)
                Haptics.success()
                // Brief delay so the Focus carousel processes the change before dismiss
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run { onDone?() }
            } catch {
                Haptics.error()
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension ActiveModePickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }
        selectMode(row)
    }
}

// MARK: - UICollectionViewDragDelegate

extension ActiveModePickerViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let row = dataSource.itemIdentifier(for: indexPath),
              case .mode = row else { return [] }
        let provider = NSItemProvider(object: "\(indexPath)" as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = row
        return [dragItem]
    }
}

// MARK: - UICollectionViewDropDelegate

extension ActiveModePickerViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // Don't allow dropping at index 0 (the "No Mode" row)
        if let dest = destinationIndexPath, dest.item == 0 {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let dragItem = coordinator.items.first,
              let sourceRow = dragItem.dragItem.localObject as? ModePickerRow,
              let sourceIndexPath = dragItem.sourceIndexPath else { return }

        // Don't allow drop onto index 0
        guard destinationIndexPath.item > 0, sourceIndexPath.section == destinationIndexPath.section else { return }

        var snapshot = dataSource.snapshot()
        var items = snapshot.itemIdentifiers(inSection: .main)
        guard let sourceIndex = items.firstIndex(of: sourceRow) else { return }

        items.remove(at: sourceIndex)
        let destIndex = min(destinationIndexPath.item, items.count)
        items.insert(sourceRow, at: destIndex)

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .main))
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)

        coordinator.drop(dragItem.dragItem, toItemAt: destinationIndexPath)

        // Persist new order (skip the .noMode row)
        let modeIds = items.compactMap { row -> UUID? in
            if case .mode(let note) = row { return note.id }
            return nil
        }
        Task { try? await noteService?.reorderNotes(ids: modeIds) }
    }
}

// MARK: - ModePickerCell

private final class ModePickerCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let checkmark = UIImageView()
    private let chevronButton = UIButton(type: .system)
    var onChevronTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = DesignTokens.Typography.headline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1

        checkmark.contentMode = .scaleAspectFit
        checkmark.setContentHuggingPriority(.required, for: .horizontal)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        chevronButton.setImage(UIImage(systemName: "chevron.right", withConfiguration: chevronConfig), for: .normal)
        chevronButton.tintColor = DesignTokens.Colors.textTertiary
        chevronButton.setContentHuggingPriority(.required, for: .horizontal)
        chevronButton.addTarget(self, action: #selector(chevronTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), checkmark, chevronButton])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            checkmark.widthAnchor.constraint(equalToConstant: 24),
            checkmark.heightAnchor.constraint(equalToConstant: 24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    @objc private func chevronTapped() {
        onChevronTapped?()
    }

    func configureNoMode(isSelected: Bool) {
        titleLabel.text = "No Mode"
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: "moon.zzz", withConfiguration: iconConfig)
        chevronButton.isHidden = true
        applySelectedState(isSelected)
    }

    func configure(with note: NotePage, isActive: Bool) {
        titleLabel.text = note.title
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: "bolt.fill", withConfiguration: iconConfig)
        chevronButton.isHidden = false
        applySelectedState(isActive)
    }

    private func applySelectedState(_ isSelected: Bool) {
        iconView.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: isSelected ? .semibold : .regular)
        if isSelected {
            checkmark.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
            checkmark.tintColor = DesignTokens.Colors.success
            contentView.layer.borderWidth = 2.5
            contentView.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.6).cgColor
        } else {
            checkmark.image = UIImage(systemName: "circle", withConfiguration: checkConfig)
            checkmark.tintColor = DesignTokens.Colors.textTertiary
            contentView.layer.borderWidth = 0
        }
    }
}
