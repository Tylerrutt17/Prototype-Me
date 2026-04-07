import UIKit
import GRDB

/// Lets the user pick a single active mode, or "No Mode" to deactivate.
final class ActiveModePickerViewController: BaseViewController {

    var modeService: ModeService?
    var onDone: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, ModePickerRow>!

    nonisolated private enum Section: Sendable { case main }

    nonisolated private enum ModePickerRow: Hashable, Sendable {
        case noMode(Bool)           // isSelected
        case mode(NotePage, Bool)   // note, isSelected

        func hash(into hasher: inout Hasher) {
            switch self {
            case .noMode:          hasher.combine("noMode")
            case .mode(let n, _):  hasher.combine(n.id)
            }
        }

        static func == (lhs: ModePickerRow, rhs: ModePickerRow) -> Bool {
            switch (lhs, rhs) {
            case (.noMode, .noMode):                   return true
            case (.mode(let a, _), .mode(let b, _)):   return a.id == b.id
            default:                                    return false
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

        buildUI()
        configureDataSource()
        loadData()
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
        let cellReg = UICollectionView.CellRegistration<ModePickerCell, ModePickerRow> { cell, _, row in
            switch row {
            case .noMode(let isSelected):
                cell.configureNoMode(isSelected: isSelected)
            case .mode(let note, let isSelected):
                cell.configure(with: note, isActive: isSelected)
            }
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, row in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: row)
        }
    }

    // MARK: - Observation

    private func loadData() {
        let observation = ValueObservation.tracking { db -> [ModePickerRow] in
            let modes = try NotePage
                .filter(Column("kind") == NoteKind.mode.rawValue)
                .order(Column("sortIndex"))
                .fetchAll(db)
            let activeId = try ActiveMode.fetchOne(db)?.noteId

            var rows: [ModePickerRow] = [.noMode(activeId == nil)]
            rows.append(contentsOf: modes.map { .mode($0, $0.id == activeId) })
            return rows
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] rows in
            var snapshot = NSDiffableDataSourceSnapshot<Section, ModePickerRow>()
            snapshot.appendSections([.main])
            snapshot.appendItems(rows)
            self?.dataSource.apply(snapshot, animatingDifferences: false)

            var reconfigSnap = self?.dataSource.snapshot() ?? snapshot
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self?.dataSource.apply(reconfigSnap, animatingDifferences: false)
        })
    }

    // MARK: - Select

    private func selectMode(_ row: ModePickerRow) {
        Task {
            do {
                try await modeService?.deactivateAll()
                if case .mode(let note, _) = row {
                    try await modeService?.activate(noteId: note.id)
                }
                Haptics.success()
                onDone?()
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

// MARK: - ModePickerCell

private final class ModePickerCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let checkmark = UIImageView()

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

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), checkmark])
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

    func configureNoMode(isSelected: Bool) {
        titleLabel.text = "No Mode"
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: "moon.zzz", withConfiguration: iconConfig)
        applySelectedState(isSelected)
    }

    func configure(with note: NotePage, isActive: Bool) {
        titleLabel.text = note.title
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.image = UIImage(systemName: "bolt.fill", withConfiguration: iconConfig)
        applySelectedState(isActive)
    }

    private func applySelectedState(_ isSelected: Bool) {
        iconView.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: isSelected ? .semibold : .regular)
        if isSelected {
            checkmark.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
            checkmark.tintColor = DesignTokens.Colors.success
            contentView.layer.borderWidth = 2
            contentView.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.5).cgColor
        } else {
            checkmark.image = UIImage(systemName: "circle", withConfiguration: checkConfig)
            checkmark.tintColor = DesignTokens.Colors.textTertiary
            contentView.layer.borderWidth = 0
        }
    }
}
