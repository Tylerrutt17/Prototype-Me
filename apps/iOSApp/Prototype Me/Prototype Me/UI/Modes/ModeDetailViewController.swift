import UIKit
import GRDB

nonisolated private enum ModeDetailSection: Int, Sendable {
    case header
    case directives
}

nonisolated private enum ModeDetailItem: Hashable, Sendable {
    case header(NotePage, Bool)    // note + isActive
    case directive(DirectiveRowData)
    case linkDirectiveButton

    // id-only equality since isActive changes
    func hash(into hasher: inout Hasher) {
        switch self {
        case .header(let note, _):        hasher.combine("header"); hasher.combine(note.id)
        case .directive(let data):        hasher.combine("dir"); hasher.combine(data.directive.id)
        case .linkDirectiveButton:        hasher.combine("linkDir")
        }
    }
    static func == (lhs: ModeDetailItem, rhs: ModeDetailItem) -> Bool {
        switch (lhs, rhs) {
        case (.header(let a, _), .header(let b, _)):       return a.id == b.id
        case (.directive(let a), .directive(let b)):        return a.directive.id == b.directive.id
        case (.linkDirectiveButton, .linkDirectiveButton):  return true
        default: return false
        }
    }
}

class ModeDetailViewController: BaseViewController {

    var noteId: UUID?
    var onDirectiveSelected: ((UUID) -> Void)?
    var onEditTapped: ((UUID) -> Void)?
    var onLinkDirectiveTapped: ((UUID) -> Void)?

    private var isBodyExpanded = false
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<ModeDetailSection, ModeDetailItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setRightButtons([
            NavBarButton(systemImage: "pencil", action: { [weak self] in self?.editTapped() }),
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
        UICollectionViewCompositionalLayout { sectionIndex, layoutEnv in
            let section = ModeDetailSection(rawValue: sectionIndex)
            switch section {
            case .header:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(400))
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
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
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

    // MARK: - Data Source

    private func configureDataSource() {
        let headerReg = UICollectionView.CellRegistration<ModeHeaderCell, (NotePage, Bool)> { [weak self] cell, _, pair in
            guard let self else { return }
            cell.configure(with: pair.0, isActive: pair.1, isBodyExpanded: self.isBodyExpanded)
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
            cell.onToggleActive = { [weak self] in
                guard let self, let noteId = self.noteId else { return }
                let isActive = pair.1
                self.toggleActiveMode(noteId: noteId, isCurrentlyActive: isActive)
            }
        }

        let directiveReg = UICollectionView.CellRegistration<DirectiveCell, DirectiveRowData> { cell, _, data in
            cell.configure(with: data)
        }

        let linkBtnReg = UICollectionView.CellRegistration<LinkButtonCell, String> { cell, _, title in
            cell.configure(title: title, systemImage: "link.badge.plus")
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            switch item {
            case .header(let note, let isActive):
                return cv.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: (note, isActive))
            case .directive(let data):
                return cv.dequeueConfiguredReusableCell(using: directiveReg, for: indexPath, item: data)
            case .linkDirectiveButton:
                return cv.dequeueConfiguredReusableCell(using: linkBtnReg, for: indexPath, item: "Add Directive")
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = ModeDetailSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .directives:  "Linked Directives"
            default:           ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { cv, kind, indexPath in
            cv.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        guard let noteId else { return }

        let observation = ValueObservation.tracking { db -> ModeDetailData? in
            guard let note = try NotePage.fetchOne(db, key: noteId) else { return nil }

            let isActive = try ActiveMode.fetchOne(db, key: noteId) != nil

            let links = try NoteDirective
                .filter(Column("noteId") == noteId)
                .order(Column("sortIndex"))
                .fetchAll(db)
            let directives: [DirectiveRowData] = links.compactMap { link in
                guard let dir = try? Directive.fetchOne(db, key: link.directiveId) else { return nil }
                return DirectiveRowData(directive: dir, scheduledToday: false, instanceStatus: nil)
            }

            return ModeDetailData(note: note, isActive: isActive, linkedDirectives: directives)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] data in
            guard let data else { return }
            self?.navBar.setTitle(data.note.title)

            var snapshot = NSDiffableDataSourceSnapshot<ModeDetailSection, ModeDetailItem>()

            snapshot.appendSections([.header])
            snapshot.appendItems([.header(data.note, data.isActive)], toSection: .header)

            snapshot.appendSections([.directives])
            var dirItems: [ModeDetailItem] = data.linkedDirectives.map { .directive($0) }
            dirItems.append(.linkDirectiveButton)
            snapshot.appendItems(dirItems, toSection: .directives)

            self?.dataSource.apply(snapshot, animatingDifferences: false)
            var reconfigSnap = self?.dataSource.snapshot() ?? snapshot
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self?.dataSource.apply(reconfigSnap, animatingDifferences: false)
        })
    }

    // MARK: - Active Mode Toggle

    private func toggleActiveMode(noteId: UUID, isCurrentlyActive: Bool) {
        do {
            try dbQueue.write { db in
                if isCurrentlyActive {
                    _ = try ActiveMode.deleteOne(db, key: noteId)
                } else {
                    // Deactivate all other modes first (single active mode)
                    _ = try ActiveMode.deleteAll(db)
                    let mode = ActiveMode(noteId: noteId, activatedAt: Date())
                    try mode.insert(db)
                }
            }
            Haptics.success()
        } catch {
            Haptics.error()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension ModeDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .header:
            break
        case .directive(let data):
            onDirectiveSelected?(data.directive.id)
        case .linkDirectiveButton:
            guard let noteId else { return }
            onLinkDirectiveTapped?(noteId)
        }
    }
}

// MARK: - ModeHeaderCell

private final class ModeHeaderCell: UICollectionViewCell {

    var onToggleExpand: (() -> Void)?
    var onToggleActive: (() -> Void)?

    private let glowLayer = CAGradientLayer()
    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let kindBadge = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let divider = UIView()
    private let bodyLabel = UILabel()
    private let showMoreButton = UIButton(type: .system)
    private var bodyStack: UIStackView!
    private let activateButton = UIView()
    private let activateIcon = UIImageView()
    private let activateLabel = UILabel()
    private let shimmerLayer = CAGradientLayer()
    private var wasActive = false
    private var isCurrentlyActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func toggleBodyExpand() {
        onToggleExpand?()
    }

    @objc private func activateButtonTapped() {
        // Immediate bounce on tap — don't wait for DB round-trip
        activateButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 10) {
            self.activateButton.transform = .identity
        }
        Haptics.medium()
        onToggleActive?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isCurrentlyActive {
            startActiveAnimations()
        }
    }

    @objc private func appDidBecomeActive() {
        if isCurrentlyActive {
            startActiveAnimations()
        }
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        let modeColor = NoteKind.mode.color
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.xl
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .medium)
        clipsToBounds = false

        // Glow layer behind everything
        glowLayer.colors = [
            modeColor.withAlphaComponent(0.5).cgColor,
            modeColor.withAlphaComponent(0.0).cgColor,
        ]
        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.opacity = 0
        layer.insertSublayer(glowLayer, at: 0)

        // Accent bar
        accentBar.backgroundColor = modeColor
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        // Icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        iconView.image = UIImage(systemName: "bolt.fill", withConfiguration: iconConfig)
        iconView.tintColor = modeColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // Kind badge
        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.title = "MODE"
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        badgeConfig.baseBackgroundColor = modeColor.withAlphaComponent(0.15)
        badgeConfig.baseForegroundColor = modeColor
        badgeConfig.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            return c
        }
        kindBadge.configuration = badgeConfig
        kindBadge.isUserInteractionEnabled = false
        kindBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(kindBadge)

        // Title
        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Divider
        divider.backgroundColor = modeColor.withAlphaComponent(0.4)
        divider.layer.cornerRadius = 1.5
        divider.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(divider)

        // Body
        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bodyLabel)

        showMoreButton.setTitle("Show more", for: .normal)
        showMoreButton.setTitle("Show more", for: .normal)
        showMoreButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        showMoreButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        showMoreButton.contentHorizontalAlignment = .leading
        showMoreButton.addTarget(self, action: #selector(toggleBodyExpand), for: .touchUpInside)
        showMoreButton.isHidden = true
        showMoreButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(showMoreButton)

        // Activate button
        activateButton.layer.cornerRadius = DesignTokens.Radii.lg
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(activateButtonTapped)))
        contentView.addSubview(activateButton)

        activateIcon.contentMode = .scaleAspectFit
        activateIcon.translatesAutoresizingMaskIntoConstraints = false
        activateButton.addSubview(activateIcon)

        activateLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        activateLabel.translatesAutoresizingMaskIntoConstraints = false
        activateButton.addSubview(activateLabel)

        // Shimmer gradient (hidden until active)
        let lighter = modeColor.withAlphaComponent(0.0).cgColor
        let highlight = UIColor.white.withAlphaComponent(0.25).cgColor
        shimmerLayer.colors = [lighter, highlight, lighter]
        shimmerLayer.locations = [0.0, 0.5, 1.0]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.cornerRadius = DesignTokens.Radii.lg
        shimmerLayer.isHidden = true
        activateButton.layer.addSublayer(shimmerLayer)

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

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            divider.widthAnchor.constraint(equalToConstant: 40),
            divider.heightAnchor.constraint(equalToConstant: 3),

        ])

        // .fill gives labels correct width during sizing pass
        bodyStack = UIStackView(arrangedSubviews: [bodyLabel, showMoreButton, activateButton])
        bodyStack.axis = .vertical
        bodyStack.spacing = DesignTokens.Spacing.md
        bodyStack.alignment = .fill
        bodyStack.setCustomSpacing(DesignTokens.Spacing.xs, after: bodyLabel)
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bodyStack)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: DesignTokens.Spacing.md),
            bodyStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            bodyStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            bodyStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),

            showMoreButton.heightAnchor.constraint(equalToConstant: 36),
            activateButton.heightAnchor.constraint(equalToConstant: 48),

            activateIcon.leadingAnchor.constraint(equalTo: activateButton.leadingAnchor, constant: DesignTokens.Spacing.lg),
            activateIcon.centerYAnchor.constraint(equalTo: activateButton.centerYAnchor),
            activateIcon.widthAnchor.constraint(equalToConstant: 20),
            activateIcon.heightAnchor.constraint(equalToConstant: 20),

            activateLabel.leadingAnchor.constraint(equalTo: activateIcon.trailingAnchor, constant: DesignTokens.Spacing.sm),
            activateLabel.centerYAnchor.constraint(equalTo: activateButton.centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = activateButton.bounds
        glowLayer.frame = bounds.insetBy(dx: -20, dy: -20)
    }


    func setBodyExpanded(_ expanded: Bool, body: String) {
        bodyLabel.text = body
        bodyLabel.numberOfLines = expanded ? 0 : 3
        showMoreButton.setTitle(expanded ? "Show less" : "Show more", for: .normal)

        layoutIfNeeded()
        let isTruncated = bodyLabel.isTruncated
        showMoreButton.isHidden = !isTruncated && !expanded
        bodyStack.setCustomSpacing(isTruncated || expanded ? DesignTokens.Spacing.xs : DesignTokens.Spacing.xl, after: bodyLabel)
    }

    func configure(with note: NotePage, isActive: Bool, isBodyExpanded: Bool = false) {
        let modeColor = NoteKind.mode.color
        isCurrentlyActive = isActive
        titleLabel.text = note.title
        if note.body.isEmpty {
            bodyLabel.isHidden = true
            showMoreButton.isHidden = true
        } else {
            bodyLabel.isHidden = false
            setBodyExpanded(isBodyExpanded, body: note.body)
        }

        let shouldAnimate = wasActive != isActive && window != nil
        wasActive = isActive

        let btnIconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        if isActive {
            // Button
            activateButton.backgroundColor = modeColor
            activateButton.layer.borderWidth = 0
            activateIcon.image = UIImage(systemName: "bolt.fill", withConfiguration: btnIconConfig)
            activateIcon.tintColor = .white
            activateLabel.text = "Active — Tap to Deactivate"
            activateLabel.textColor = .white

            // Card glows active
            contentView.backgroundColor = modeColor.withAlphaComponent(0.06)
            contentView.layer.borderWidth = 1.5
            contentView.layer.borderColor = modeColor.withAlphaComponent(0.4).cgColor
            accentBar.backgroundColor = modeColor

            if shouldAnimate {
                playActivateAnimation()
            } else {
                startActiveAnimations()
            }
        } else {
            // Button
            activateButton.backgroundColor = DesignTokens.Colors.surfaceSecondary
            activateButton.layer.borderWidth = 1
            activateButton.layer.borderColor = modeColor.withAlphaComponent(0.4).cgColor
            activateIcon.image = UIImage(systemName: "bolt.fill", withConfiguration: btnIconConfig)
            activateIcon.tintColor = modeColor.withAlphaComponent(0.6)
            activateLabel.text = "Tap to Activate"
            activateLabel.textColor = DesignTokens.Colors.textPrimary

            // Card goes neutral
            contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
            contentView.layer.borderWidth = 0
            accentBar.backgroundColor = modeColor.withAlphaComponent(0.4)

            stopActiveAnimations()

            if shouldAnimate {
                playDeactivateAnimation()
            }
        }
    }

    // MARK: - Animations

    private func playActivateAnimation() {
        let modeColor = NoteKind.mode.color

        // Button spring scale
        activateButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 8) {
            self.activateButton.transform = .identity
        }

        // Icon spin
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = 0.4
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconView.layer.add(spin, forKey: "spin")

        // Card border flash
        let borderFlash = CABasicAnimation(keyPath: "borderColor")
        borderFlash.fromValue = modeColor.cgColor
        borderFlash.toValue = modeColor.withAlphaComponent(0.4).cgColor
        borderFlash.duration = 0.3
        borderFlash.autoreverses = true
        contentView.layer.add(borderFlash, forKey: "borderFlash")

        // Accent bar expand flash
        UIView.animate(withDuration: 0.15) {
            self.accentBar.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
                self.accentBar.transform = .identity
            }
        }

        // Background glow flash
        playGlowPulse()

        startActiveAnimations()
        Haptics.success()
    }

    private func playDeactivateAnimation() {
        // Quick glow flash — like the activate glow but faster
        glowLayer.opacity = 0
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.0, 0.6, 0.0]
        flash.keyTimes = [0.0, 0.2, 1.0]
        flash.duration = 0.5
        flash.isRemovedOnCompletion = true
        glowLayer.add(flash, forKey: "deactivateFlash")

        // Everything fades to inactive state together
        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.activateButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.activateButton.transform = .identity
            }
        }

        Haptics.light()
    }

    private func startActiveAnimations() {
        let modeColor = NoteKind.mode.color

        // Gentle icon pulse
        let iconPulse = CABasicAnimation(keyPath: "transform.scale")
        iconPulse.fromValue = 1.0
        iconPulse.toValue = 1.15
        iconPulse.duration = 1.5
        iconPulse.autoreverses = true
        iconPulse.repeatCount = .infinity
        iconPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconView.layer.add(iconPulse, forKey: "activePulse")

        // Subtle border glow pulse
        let borderGlow = CABasicAnimation(keyPath: "borderColor")
        borderGlow.fromValue = modeColor.withAlphaComponent(0.4).cgColor
        borderGlow.toValue = modeColor.withAlphaComponent(0.15).cgColor
        borderGlow.duration = 2.0
        borderGlow.autoreverses = true
        borderGlow.repeatCount = .infinity
        borderGlow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentView.layer.add(borderGlow, forKey: "glowPulse")

        // Shadow glow
        layer.shadowColor = modeColor.cgColor
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.25

        // Button shimmer sweep
        startShimmer()
    }

    private func stopActiveAnimations() {
        iconView.layer.removeAnimation(forKey: "activePulse")
        contentView.layer.removeAnimation(forKey: "glowPulse")
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        stopShimmer()
    }

    private func startShimmer() {
        shimmerLayer.isHidden = false
        shimmerLayer.frame = activateButton.bounds

        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.5, -0.25, 0.0]
        sweep.toValue = [1.0, 1.25, 1.5]
        sweep.duration = 2.0
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerLayer.add(sweep, forKey: "shimmer")
    }

    private func stopShimmer() {
        shimmerLayer.removeAllAnimations()
        shimmerLayer.isHidden = true
    }

    private func playGlowPulse() {
        glowLayer.opacity = 0
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.7, 0.0]
        fade.keyTimes = [0.0, 0.3, 1.0]
        fade.duration = 0.8
        fade.isRemovedOnCompletion = true
        glowLayer.add(fade, forKey: "glowPulse")
    }
}

// MARK: - LinkButtonCell

final class LinkButtonCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary.withAlphaComponent(0.5)
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor

        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
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

    func configure(title: String, systemImage: String) {
        label.text = title
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: systemImage, withConfiguration: config)
    }
}
