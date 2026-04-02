import UIKit
import GRDB

nonisolated private enum NoteDetailSection: Int, Sendable {
    case header
    case directives
}

nonisolated private enum NoteDetailItem: Hashable, Sendable {
    case header(NotePage)
    case directive(DirectiveRowData)
    case linkButton
}

class NoteDetailViewController: BaseViewController {

    var noteId: UUID?
    var noteService: NoteService?
    var onDirectiveSelected: ((UUID) -> Void)?
    var onEditTapped: ((UUID) -> Void)?
    var onLinkDirectiveTapped: ((UUID) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<NoteDetailSection, NoteDetailItem>!
    private var isBodyExpanded = false

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

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
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
                var config = UICollectionLayoutListConfiguration(appearance: .plain)
                config.backgroundColor = .clear
                config.showsSeparators = false
                config.trailingSwipeActionsConfigurationProvider = { indexPath in
                    guard let self,
                          let item = self.dataSource.itemIdentifier(for: indexPath),
                          case .directive(let data) = item else { return nil }
                    let unlink = UIContextualAction(style: .destructive, title: "Unlink") { _, _, completion in
                        self.unlinkDirective(directiveId: data.directive.id)
                        completion(true)
                    }
                    unlink.backgroundColor = DesignTokens.Colors.warning
                    unlink.image = UIImage(systemName: "link.badge.minus")
                    return UISwipeActionsConfiguration(actions: [unlink])
                }
                let layoutSection = NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnv)
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

    private func showUnlinkConfirmation(for directiveId: UUID, in cell: UICollectionViewCell) {
        // Check if unlink button already showing
        if cell.contentView.viewWithTag(999) != nil { return }

        let unlinkBtn = UIButton(type: .system)
        unlinkBtn.tag = 999
        var config = UIButton.Configuration.filled()
        config.title = "Unlink"
        config.image = UIImage(systemName: "link.badge.minus")
        config.imagePadding = DesignTokens.Spacing.xs
        config.baseBackgroundColor = DesignTokens.Colors.warning
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        config.titleTextAttributesTransformer = .init { attr in
            var a = attr; a.font = DesignTokens.Typography.rounded(style: .caption1, weight: .bold); return a
        }
        unlinkBtn.configuration = config
        unlinkBtn.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(unlinkBtn)

        NSLayoutConstraint.activate([
            unlinkBtn.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -DesignTokens.Spacing.md),
            unlinkBtn.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        ])

        // Slide in from right
        unlinkBtn.transform = CGAffineTransform(translationX: 80, y: 0)
        unlinkBtn.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            unlinkBtn.transform = .identity
            unlinkBtn.alpha = 1
        }

        unlinkBtn.addAction(UIAction { [weak self] _ in
            self?.unlinkDirective(directiveId: directiveId)
        }, for: .touchUpInside)

        // Auto-dismiss after 3 seconds if not tapped
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak unlinkBtn] in
            guard let btn = unlinkBtn, btn.superview != nil else { return }
            UIView.animate(withDuration: 0.2) {
                btn.alpha = 0
                btn.transform = CGAffineTransform(translationX: 80, y: 0)
            } completion: { _ in
                btn.removeFromSuperview()
            }
        }
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
        // Header cell
        let headerReg = UICollectionView.CellRegistration<NoteHeaderCell, NotePage> { [weak self] cell, _, note in
            guard let self else { return }
            cell.configure(with: note, isExpanded: self.isBodyExpanded)
            cell.onToggleExpand = { [weak self] in
                guard let self else { return }
                self.isBodyExpanded.toggle()

                var snapshot = self.dataSource.snapshot()
                if let headerItem = snapshot.itemIdentifiers.first(where: {
                    if case .header = $0 { return true }; return false
                }) {
                    snapshot.reloadItems([headerItem])
                }
                self.dataSource.apply(snapshot, animatingDifferences: false)
                self.collectionView.performBatchUpdates(nil)
            }
        }

        // Directive cell with swipe-to-unlink
        let directiveReg = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { [weak self] cell, _, data in
            cell.configure(with: data)

            // Remove any existing swipe recognizers (cell reuse)
            cell.gestureRecognizers?.filter { $0 is UISwipeGestureRecognizer }.forEach { cell.removeGestureRecognizer($0) }

            let directiveId = data.directive.id
            let swipe = BlockSwipeGesture(direction: .left) { [weak self, weak cell] in
                guard let self, let cell else { return }
                self.showUnlinkConfirmation(for: directiveId, in: cell)
            }
            cell.addGestureRecognizer(swipe)
        }

        // Link button cell
        let linkBtnReg = UICollectionView.CellRegistration<LinkDirectiveButtonCell, Bool> { cell, _, _ in
            cell.backgroundConfiguration = .clear()
        }

        dataSource = UICollectionViewDiffableDataSource<NoteDetailSection, NoteDetailItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header(let note):
                return collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: note)
            case .directive(let data):
                return collectionView.dequeueConfiguredReusableCell(using: directiveReg, for: indexPath, item: data)
            case .linkButton:
                return collectionView.dequeueConfiguredReusableCell(using: linkBtnReg, for: indexPath, item: true)
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

    // MARK: - Observe Data

    private func loadData() {
        guard let noteId else { return }

        let observation = ValueObservation.tracking { db -> (NotePage?, [DirectiveRowData]) in
            guard let note = try NotePage.fetchOne(db, key: noteId) else { return (nil, []) }

            let links = try NoteDirective
                .filter(Column("noteId") == noteId)
                .order(Column("sortIndex"))
                .fetchAll(db)

            let allRules = try ScheduleRule.fetchAll(db)
            let rows: [DirectiveRowData] = links.compactMap { link in
                guard let dir = try? Directive.fetchOne(db, key: link.directiveId) else { return nil }
                let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                return DirectiveRowData(directive: dir, scheduledToday: scheduled)
            }
            return (note, rows)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] (note, linkedDirectives) in
            self?.navBar.setTitle(note?.title)

            var snapshot = NSDiffableDataSourceSnapshot<NoteDetailSection, NoteDetailItem>()

            if let note {
                snapshot.appendSections([.header])
                snapshot.appendItems([.header(note)], toSection: .header)
            }

            // Always show directives section with link button at the end
            snapshot.appendSections([.directives])
            var directiveItems: [NoteDetailItem] = linkedDirectives.map { .directive($0) }
            directiveItems.append(.linkButton)
            snapshot.appendItems(directiveItems, toSection: .directives)

            self?.dataSource.apply(snapshot, animatingDifferences: false)
            // Force full cell reload since models use id-only equality
            if let note {
                var reloadSnap = self?.dataSource.snapshot() ?? snapshot
                reloadSnap.reloadItems([.header(note)])
                self?.dataSource.apply(reloadSnap, animatingDifferences: false)
            }
        })
    }
}

// MARK: - UICollectionViewDragDelegate

extension NoteDetailViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .directive = item else { return [] }
        let provider = NSItemProvider(object: "\(indexPath)" as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = item
        return [dragItem]
    }
}

// MARK: - UICollectionViewDelegate

extension NoteDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .directive(let data):
            onDirectiveSelected?(data.directive.id)
        case .linkButton:
            guard let noteId else { return }
            onLinkDirectiveTapped?(noteId)
        case .header:
            break
        }
    }
}

// MARK: - UICollectionViewDropDelegate

extension NoteDetailViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // Only allow drops in the directives section
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

        // Only within directives section
        let directivesSection = NoteDetailSection.directives.rawValue
        guard sourceIndexPath.section == directivesSection,
              destinationIndexPath.section == directivesSection else { return }

        var snapshot = dataSource.snapshot()
        let section = NoteDetailSection.directives
        var sectionItems = snapshot.itemIdentifiers(inSection: section)
        guard let sourceIndex = sectionItems.firstIndex(of: sourceRow) else { return }

        sectionItems.remove(at: sourceIndex)
        let destIndex = min(destinationIndexPath.item, sectionItems.count)
        sectionItems.insert(sourceRow, at: destIndex)

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: section))
        snapshot.appendItems(sectionItems, toSection: section)
        dataSource.apply(snapshot, animatingDifferences: true)

        coordinator.drop(dragItem.dragItem, toItemAt: destinationIndexPath)

        // Persist — extract only directive IDs (skip linkButton)
        guard let noteId else { return }
        let directiveIds = sectionItems.compactMap { item -> UUID? in
            if case .directive(let data) = item { return data.directive.id }
            return nil
        }
        Task { try? await noteService?.reorderDirectives(noteId: noteId, directiveIds: directiveIds) }
    }
}

// MARK: - NoteHeaderCell

private final class NoteHeaderCell: UICollectionViewCell {

    var onToggleExpand: (() -> Void)?

    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let kindBadge = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let showMoreButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.xl
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .medium)
        clipsToBounds = false

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        kindBadge.configuration = badgeConfig
        kindBadge.isUserInteractionEnabled = false
        kindBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(kindBadge)

        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        showMoreButton.setTitle("Show more", for: .normal)
        showMoreButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        showMoreButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        showMoreButton.contentHorizontalAlignment = .leading
        showMoreButton.addTarget(self, action: #selector(tappedShowMore), for: .touchUpInside)
        showMoreButton.isHidden = true

        // .fill alignment gives labels correct width during sizing pass
        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, showMoreButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.setCustomSpacing(DesignTokens.Spacing.xs, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            iconView.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: DesignTokens.Spacing.lg),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            kindBadge.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            kindBadge.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DesignTokens.Spacing.md),

            stack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),

            showMoreButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @objc private func tappedShowMore() {
        onToggleExpand?()
    }

    func setExpanded(_ expanded: Bool, body: String) {
        bodyLabel.text = body
        bodyLabel.numberOfLines = expanded ? 0 : 3
        showMoreButton.setTitle(expanded ? "Show less" : "Show more", for: .normal)

        layoutIfNeeded()
        showMoreButton.isHidden = !bodyLabel.isTruncated && !expanded
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ShimmerBorder.updateFrame(on: contentView, cornerRadius: DesignTokens.Radii.xl)
    }

    func configure(with note: NotePage, isExpanded: Bool) {
        let color = note.kind.color
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        iconView.image = UIImage(systemName: note.kind.iconName, withConfiguration: iconConfig)
        iconView.tintColor = color

        accentBar.backgroundColor = color

        var badgeConfig = kindBadge.configuration ?? .filled()
        badgeConfig.title = note.kind.displayName.uppercased()
        badgeConfig.baseBackgroundColor = color.withAlphaComponent(0.15)
        badgeConfig.baseForegroundColor = color
        badgeConfig.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            return c
        }
        kindBadge.configuration = badgeConfig

        titleLabel.text = note.title

        if note.body.isEmpty {
            bodyLabel.isHidden = true
            showMoreButton.isHidden = true
        } else {
            bodyLabel.isHidden = false
            setExpanded(isExpanded, body: note.body)
        }

        // Shimmer border for modes
        if note.kind == .mode {
            // Defer to next layout pass so bounds are set
            DispatchQueue.main.async {
                ShimmerBorder.add(to: self.contentView, color: color, cornerRadius: DesignTokens.Radii.xl)
            }
        } else {
            ShimmerBorder.remove(from: contentView)
        }
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
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
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

// MARK: - LinkDirectiveButtonCell

private final class LinkDirectiveButtonCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.image = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        label.text = "Add Directive"
        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.accent

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
        ])
    }
}

// MARK: - UILabel Truncation Check

extension UILabel {
    var isTruncated: Bool {
        guard let text, numberOfLines > 0, bounds.width > 0 else { return false }
        let maxSize = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        let fullHeight = (text as NSString).boundingRect(
            with: maxSize, options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font as Any], context: nil
        ).height
        return fullHeight > bounds.height + 2
    }
}
