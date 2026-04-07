import UIKit
import GRDB

/// Presents a searchable list of directives to link to a note.
/// Directives already linked to the note are excluded.
final class DirectivePickerViewController: BaseViewController {

    // MARK: - Public

    var noteId: UUID!
    var noteService: NoteService?
    var directiveService: DirectiveService?
    var onDirectiveLinked: (() -> Void)?

    // MARK: - Private

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Directive>!
    private let searchBar = UISearchBar()
    private let addBanner = UIButton(type: .system)
    private var searchText = ""

    nonisolated private enum Section: Sendable { case main }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Add Directive", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in
            self?.dismiss(animated: true)
        })
        navBar.setRightButtons([NavBarButton(systemImage: "plus") { [weak self] in
            self?.showCreateDirective()
        }])

        buildUI()
        configureDataSource()
        loadData()
    }

    // MARK: - UI

    private func buildUI() {
        searchBar.placeholder = "Search directives…"
        searchBar.searchBarStyle = .minimal
        searchBar.tintColor = DesignTokens.Colors.accent
        searchBar.barTintColor = DesignTokens.Colors.background
        searchBar.searchTextField.textColor = DesignTokens.Colors.textPrimary
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)

        configureAddBanner()

        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentTopAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.sm),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.sm),

            addBanner.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: DesignTokens.Spacing.xs),
            addBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.lg),
            addBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.lg),

            collectionView.topAnchor.constraint(equalTo: addBanner.bottomAnchor, constant: DesignTokens.Spacing.xs),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

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
    }

    @objc private func addBannerTapped() {
        Haptics.light()
        showCreateDirective()
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        return UICollectionViewCompositionalLayout { _, layoutEnv in
            let section = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnv)
            section.interGroupSpacing = DesignTokens.Spacing.xs
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
        let cellReg = UICollectionView.CellRegistration<PickerCell, Directive> { cell, _, directive in
            cell.configure(with: directive)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, directive in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: directive)
        }
    }

    // MARK: - Observation

    private func loadData() {
        let noteId = self.noteId!
        let observation = ValueObservation.tracking { db -> [Directive] in
            // IDs already linked to this note
            let linkedIds = try NoteDirective
                .filter(Column("noteId") == noteId)
                .select(Column("directiveId"))
                .asRequest(of: UUID.self)
                .fetchSet(db)

            // All non-retired directives, excluding already-linked — most recently touched first
            return try Directive
                .filter(!linkedIds.contains(Column("id")))
                .filter(Column("status") != DirectiveStatus.archived.rawValue)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] directives in
            self?.applySnapshot(directives)
        })
    }

    private func applySnapshot(_ directives: [Directive]) {
        let filtered: [Directive]
        if searchText.isEmpty {
            filtered = directives
        } else {
            let query = searchText.lowercased()
            filtered = directives.filter { $0.title.lowercased().contains(query) }
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Directive>()
        snapshot.appendSections([.main])
        snapshot.appendItems(filtered)
        dataSource.apply(snapshot, animatingDifferences: true)
        // Directive uses id-only equality — reconfigure to reflect content changes.
        var reconfigSnap = dataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        dataSource.apply(reconfigSnap, animatingDifferences: false)
    }

    // MARK: - Create New Directive

    private func showCreateDirective() {
        let editor = DirectiveEditorViewController()
        editor.directiveId = nil // create mode
        editor.directiveService = directiveService
        editor.onSave = { [weak self] in
            // New directive is now in the DB — ValueObservation will pick it up in the list
            self?.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.isNavigationBarHidden = true
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    // MARK: - Link Action

    private func linkDirective(_ directive: Directive) {
        guard let noteId else { return }

        Task {
            do {
                try await noteService?.linkDirective(noteId: noteId, directiveId: directive.id)
                Haptics.success()
                onDirectiveLinked?()
            } catch {
                Haptics.error()
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension DirectivePickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let directive = dataSource.itemIdentifier(for: indexPath) else { return }
        linkDirective(directive)
    }
}

// MARK: - UISearchBarDelegate

extension DirectivePickerViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText
        // Re-trigger snapshot with current data
        if let snapshot = dataSource?.snapshot() {
            let items = snapshot.itemIdentifiers
            applySnapshot(items)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - PickerCell

private final class PickerCell: UICollectionViewCell {

    private let titleLabel = UILabel()
    private let linkIcon = UIImageView()

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
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        titleLabel.font = DesignTokens.Typography.body
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 2

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        linkIcon.image = UIImage(systemName: "link.badge.plus", withConfiguration: config)
        linkIcon.tintColor = DesignTokens.Colors.accent
        linkIcon.contentMode = .scaleAspectFit
        linkIcon.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [titleLabel, UIView(), linkIcon])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with directive: Directive) {
        titleLabel.text = directive.title
    }
}
