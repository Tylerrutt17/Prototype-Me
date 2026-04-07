import UIKit
import GRDB

nonisolated private enum DirectiveDetailSection: Int, Sendable {
    case header
    case balloon
    case settings  // Balloon + checklist summary
    case history
}

nonisolated private enum DirectiveDetailItem: Hashable, Sendable {
    case header(Directive)
    case settingRow(String, String, String)  // icon, title, subtitle
    case balloon(DirectiveRowData)
    case historyEntry(DirectiveHistory)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .header(let d): hasher.combine("h"); hasher.combine(d.id)
        case .settingRow(_, let t, _): hasher.combine("s"); hasher.combine(t)
        case .balloon(let d): hasher.combine("b"); hasher.combine(d.directive.id)
        case .historyEntry(let e): hasher.combine("hi"); hasher.combine(e.id)
        }
    }
    static func == (lhs: DirectiveDetailItem, rhs: DirectiveDetailItem) -> Bool {
        switch (lhs, rhs) {
        case (.header(let a), .header(let b)): return a.id == b.id
        case (.settingRow(_, let a, _), .settingRow(_, let b, _)): return a == b
        case (.balloon(let a), .balloon(let b)): return a.directive.id == b.directive.id
        case (.historyEntry(let a), .historyEntry(let b)): return a.id == b.id
        default: return false
        }
    }
}

class DirectiveDetailViewController: BaseViewController {

    var directiveId: UUID?
    var onEditTapped: ((UUID) -> Void)?
    var balloonNotificationService: BalloonNotificationService?
    /// Set to true when arriving from a balloon expiry notification.
    var fromNotification = false

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DirectiveDetailSection, DirectiveDetailItem>!

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
        guard let directiveId else { return }
        onEditTapped?(directiveId)
    }

    private func saveInlineEdit(title: String, body: String?) {
        guard let directiveId else { return }
        Task {
            do {
                try await dbQueue.write { db in
                    guard var directive = try Directive.fetchOne(db, key: directiveId) else { return }
                    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedTitle.isEmpty else { return }
                    directive.title = trimmedTitle
                    let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
                    directive.body = (trimmedBody?.isEmpty ?? true) ? nil : trimmedBody
                    directive.updatedAt = Date()
                    directive.version += 1
                    try directive.update(db)
                    try OutboxOp.enqueue(entityType: "directive", entityId: directive.id.uuidString, op: "update", patch: directive.syncPatch(), baseUpdatedAt: directive.updatedAt, in: db)
                }
            } catch {
                print("Inline edit save failed: \(error)")
            }
        }
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
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let detailSection = DirectiveDetailSection(rawValue: sectionIndex)

            // Balloon card needs more height for title + timer + pump button
            let estimatedHeight: CGFloat = detailSection == .balloon ? 180 : 80

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = DesignTokens.Spacing.sm
            section.contentInsets = NSDirectionalEdgeInsets(
                top: sectionIndex == 0 ? DesignTokens.Spacing.lg : DesignTokens.Spacing.sm,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.md,
                trailing: DesignTokens.Spacing.lg
            )

            if sectionIndex > 0 {
                let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(32))
                let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [sectionHeader]
            }
            return section
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let headerReg = UICollectionView.CellRegistration<DirectiveHeaderCell, Directive> { [weak self] cell, _, directive in
            cell.configure(with: directive)
            cell.onFieldEdited = { title, body in
                self?.saveInlineEdit(title: title, body: body)
            }
        }

        let balloonReg = UICollectionView.CellRegistration<BalloonCard, DirectiveRowData> { [weak self] cell, _, data in
            cell.dbQueue = self?.dbQueue
            cell.balloonNotificationService = self?.balloonNotificationService
            cell.configure(with: data)

            // Shimmer border only when balloon has expired (0 remaining)
            DispatchQueue.main.async {
                ShimmerBorder.remove(from: cell.contentView)
                cell.contentView.layer.removeAnimation(forKey: "pressureGlow")

                if data.directive.liveRemainingSec <= 0 {
                    let color = DesignTokens.Colors.destructive
                    ShimmerBorder.add(to: cell.contentView, color: color, cornerRadius: DesignTokens.Radii.lg, borderWidth: 2.5)

                    cell.contentView.layer.shadowColor = color.cgColor
                    cell.contentView.layer.shadowRadius = 8
                    cell.contentView.layer.shadowOpacity = 0.3
                    cell.contentView.layer.shadowOffset = .zero

                    let glow = CABasicAnimation(keyPath: "shadowRadius")
                    glow.fromValue = 4
                    glow.toValue = 12
                    glow.duration = 1.2
                    glow.autoreverses = true
                    glow.repeatCount = .infinity
                    glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    cell.contentView.layer.add(glow, forKey: "pressureGlow")
                } else {
                    cell.contentView.layer.shadowOpacity = 0
                }
            }
        }

        let historyReg = UICollectionView.CellRegistration<HistoryEntryCell, DirectiveHistory> { cell, _, entry in
            cell.configure(with: entry)
        }

        let settingReg = UICollectionView.CellRegistration<UICollectionViewListCell, (String, String, String)> { cell, _, data in
            var content = UIListContentConfiguration.valueCell()
            content.text = data.1
            content.secondaryText = data.2
            content.textProperties.color = DesignTokens.Colors.textPrimary
            content.textProperties.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
            content.secondaryTextProperties.color = DesignTokens.Colors.textSecondary
            content.secondaryTextProperties.font = DesignTokens.Typography.caption1
            content.image = UIImage(systemName: data.0)
            content.imageProperties.tintColor = DesignTokens.Colors.accent
            cell.contentConfiguration = content
            var bg = UIBackgroundConfiguration.listCell()
            bg.backgroundColor = DesignTokens.Colors.surfacePrimary
            bg.cornerRadius = DesignTokens.Radii.md
            cell.backgroundConfiguration = bg
        }

        dataSource = UICollectionViewDiffableDataSource<DirectiveDetailSection, DirectiveDetailItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header(let directive):
                return collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: directive)
            case .settingRow(let icon, let title, let subtitle):
                return collectionView.dequeueConfiguredReusableCell(using: settingReg, for: indexPath, item: (icon, title, subtitle))
            case .balloon(let data):
                return collectionView.dequeueConfiguredReusableCell(using: balloonReg, for: indexPath, item: data)
            case .historyEntry(let entry):
                return collectionView.dequeueConfiguredReusableCell(using: historyReg, for: indexPath, item: entry)
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = DirectiveDetailSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .settings: "Active Features"
            case .balloon:  "Balloon Timer"
            case .history:  "History"
            default:        ""
            }
            supplementaryView.configure(title: title)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: sectionHeaderReg, for: indexPath)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        guard let directiveId else { return }

        let observation = ValueObservation.tracking { db -> (Directive?, ScheduleRule?, [DirectiveHistory]) in
            let directive = try Directive.fetchOne(db, key: directiveId)
            let rule = try ScheduleRule
                .filter(Column("directiveId") == directiveId)
                .fetchOne(db)
            let history = try DirectiveHistory
                .filter(Column("directiveId") == directiveId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return (directive, rule, history)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] (directive, rule, history) in
            guard let directive else { return }
            self?.navBar.setTitle(directive.title)

            var snapshot = NSDiffableDataSourceSnapshot<DirectiveDetailSection, DirectiveDetailItem>()

            snapshot.appendSections([.header])
            snapshot.appendItems([.header(directive)], toSection: .header)

            // Settings summary rows
            var settingRows: [DirectiveDetailItem] = []

            if directive.balloonEnabled {
                let durationHours = directive.balloonDurationSec / 3600
                let durationText: String
                let days = Int(durationHours) / 24
                let remaining = Int(durationHours) % 24
                if days == 0 {
                    durationText = "\(Int(durationHours)) hour\(Int(durationHours) == 1 ? "" : "s")"
                } else if remaining == 0 {
                    durationText = "\(days) day\(days == 1 ? "" : "s")"
                } else {
                    durationText = "\(days)d \(remaining)h"
                }
                settingRows.append(.settingRow("timer", "Balloon", "Every \(durationText)"))
            }

            if let rule {
                let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                var parts: [String] = []
                if let weekdays = rule.params["weekdays"] ?? (rule.ruleType == .weekly ? rule.params["days"] : nil), !weekdays.isEmpty {
                    parts.append(weekdays.compactMap { (1...7).contains($0) ? dayNames[$0 - 1] : nil }.joined(separator: ", "))
                }
                if let monthDays = rule.params["monthDays"], !monthDays.isEmpty {
                    parts.append("Monthly")
                }
                if let flat = rule.params["oneOffs"], flat.count >= 3 {
                    let count = flat.count / 3
                    parts.append("\(count) date\(count == 1 ? "" : "s")")
                }
                settingRows.append(.settingRow("checklist", "Checklist", parts.joined(separator: " · ")))
            }

            if directive.balloonEnabled {
                snapshot.appendSections([.balloon])
                let row = DirectiveRowData(directive: directive, scheduledToday: false)
                snapshot.appendItems([.balloon(row)], toSection: .balloon)
            }

            if !settingRows.isEmpty {
                snapshot.appendSections([.settings])
                snapshot.appendItems(settingRows, toSection: .settings)
            }

            if !history.isEmpty {
                snapshot.appendSections([.history])
                snapshot.appendItems(history.map { .historyEntry($0) }, toSection: .history)
            }

            self?.dataSource.apply(snapshot, animatingDifferences: false)
            var reconfigSnap = self?.dataSource.snapshot() ?? snapshot
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self?.dataSource.apply(reconfigSnap, animatingDifferences: false)

        })
    }

    // MARK: - Entrance Animation

}

// MARK: - UICollectionViewDelegate

extension DirectiveDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .settingRow:
            guard let directiveId else { return }
            onEditTapped?(directiveId)
        default:
            break
        }
    }
}

// MARK: - DirectiveHeaderCell

private final class DirectiveHeaderCell: UICollectionViewCell, UITextViewDelegate {

    var onFieldEdited: ((String, String?) -> Void)?

    private let statusBadge = UIButton(type: .system)
    private let titleView = UITextView()
    private let titlePlaceholder = UILabel()
    private let bodyView = UITextView()
    private let bodyPlaceholder = UILabel()
    private let metaLabel = UILabel()

    private var currentDirectiveId: UUID?

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

        // Status badge pill
        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        statusBadge.configuration = badgeConfig
        statusBadge.isUserInteractionEnabled = false

        // Title (editable, multi-line)
        titleView.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleView.textColor = DesignTokens.Colors.textPrimary
        titleView.backgroundColor = .clear
        titleView.isScrollEnabled = false
        titleView.textContainerInset = .zero
        titleView.textContainer.lineFragmentPadding = 0
        titleView.delegate = self
        titleView.returnKeyType = .done

        // Placeholder for title
        titlePlaceholder.text = "Title"
        titlePlaceholder.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titlePlaceholder.textColor = DesignTokens.Colors.textTertiary
        titlePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(titlePlaceholder)
        NSLayoutConstraint.activate([
            titlePlaceholder.topAnchor.constraint(equalTo: titleView.topAnchor),
            titlePlaceholder.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
        ])

        // Body (editable)
        bodyView.font = DesignTokens.Typography.body
        bodyView.textColor = DesignTokens.Colors.textSecondary
        bodyView.backgroundColor = .clear
        bodyView.isScrollEnabled = false
        bodyView.textContainerInset = .zero
        bodyView.textContainer.lineFragmentPadding = 0
        bodyView.delegate = self

        // Placeholder for body
        bodyPlaceholder.text = "Add a description…"
        bodyPlaceholder.font = DesignTokens.Typography.body
        bodyPlaceholder.textColor = DesignTokens.Colors.textTertiary
        bodyPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(bodyPlaceholder)
        NSLayoutConstraint.activate([
            bodyPlaceholder.topAnchor.constraint(equalTo: bodyView.topAnchor),
            bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
        ])

        // Meta label (created date)
        metaLabel.font = DesignTokens.Typography.caption1
        metaLabel.textColor = DesignTokens.Colors.textTertiary

        // Top pill row: [status badge] | spacer, so the pill stays left-aligned.
        let pillSpacer = UIView()
        pillSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let pillRow = UIStackView(arrangedSubviews: [statusBadge, pillSpacer])
        pillRow.axis = .horizontal
        pillRow.alignment = .center
        statusBadge.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [pillRow, titleView, bodyView, metaLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.setCustomSpacing(DesignTokens.Spacing.lg, after: pillRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
        ])
    }

    func configure(with directive: Directive) {
        currentDirectiveId = directive.id

        // Status badge: always visible; color reflects active/archived.
        let badgeColor: UIColor = switch directive.status {
        case .active:   DesignTokens.Colors.success
        case .archived: DesignTokens.Colors.textTertiary
        }
        var badgeCfg = statusBadge.configuration ?? .filled()
        badgeCfg.title = directive.status.rawValue.uppercased()
        badgeCfg.baseBackgroundColor = badgeColor.withAlphaComponent(0.15)
        badgeCfg.baseForegroundColor = badgeColor
        badgeCfg.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            return c
        }
        statusBadge.configuration = badgeCfg

        // Title — only update if not currently being edited
        if !titleView.isFirstResponder {
            titleView.text = directive.title
            titlePlaceholder.isHidden = !directive.title.isEmpty
        }

        // Body — only update if not currently being edited
        if !bodyView.isFirstResponder {
            bodyView.text = directive.body
            bodyPlaceholder.isHidden = !(directive.body ?? "").isEmpty
        }

        // Meta
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        metaLabel.text = "Created " + fmt.localizedString(for: directive.createdAt, relativeTo: .now)
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Title: pressing Return dismisses the keyboard instead of inserting a newline
        if textView === titleView, text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView === titleView {
            titlePlaceholder.isHidden = !textView.text.isEmpty
        } else {
            bodyPlaceholder.isHidden = !textView.text.isEmpty
        }
        // Invalidate layout so the cell resizes as the title/body grows
        invalidateIntrinsicContentSize()
        // Ask the collection view to re-measure this cell
        if let collectionView = self.superview as? UICollectionView {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView === titleView {
            titlePlaceholder.isHidden = !textView.text.isEmpty
        } else {
            bodyPlaceholder.isHidden = !textView.text.isEmpty
        }
        commitEdit()
    }

    private func commitEdit() {
        let title = titleView.text ?? ""
        let body = bodyView.text
        onFieldEdited?(title, body)
    }
}

// MARK: - ScheduleRuleCell

private final class ScheduleRuleCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let descLabel = UILabel()
    private let editLabel = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        iconView.image = UIImage(systemName: "calendar.badge.clock")
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        descLabel.font = DesignTokens.Typography.body
        descLabel.textColor = DesignTokens.Colors.textPrimary
        descLabel.numberOfLines = 0

        editLabel.text = "Edit"
        editLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        editLabel.textColor = DesignTokens.Colors.accent

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        chevron.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit

        let stack = UIStackView(arrangedSubviews: [iconView, descLabel, editLabel, chevron])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with rule: ScheduleRule) {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var parts: [String] = []

        // Weekly (new key "weekdays" or legacy "days")
        let weekdays = rule.params["weekdays"] ?? (rule.ruleType == .weekly ? rule.params["days"] : nil) ?? []
        if !weekdays.isEmpty {
            let names = weekdays.compactMap { d in (1...7).contains(d) ? dayNames[d - 1] : nil }
            parts.append(names.joined(separator: ", "))
        }

        // Monthly
        if let monthDays = rule.params["monthDays"], !monthDays.isEmpty {
            parts.append("Monthly: " + monthDays.map { ordinal($0) }.joined(separator: ", "))
        }

        // One-offs (new flattened format)
        if let flat = rule.params["oneOffs"], flat.count >= 3 {
            var dates: [String] = []
            for i in stride(from: 0, to: flat.count - 2, by: 3) {
                dates.append("\(flat[i+1])/\(flat[i+2])/\(flat[i])")
            }
            parts.append(dates.joined(separator: ", "))
        }
        // Legacy single oneOff
        if let oneOff = rule.params["oneOff"], oneOff.count == 3 {
            parts.append("\(oneOff[1])/\(oneOff[2])/\(oneOff[0])")
        }

        descLabel.text = parts.isEmpty ? "No schedule" : parts.joined(separator: " · ")
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

// MARK: - HistoryEntryCell

private final class HistoryEntryCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let actionLabel = UILabel()
    private let dateLabel = UILabel()

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

        actionLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        actionLabel.textColor = DesignTokens.Colors.textPrimary

        dateLabel.font = DesignTokens.Typography.caption1
        dateLabel.textColor = DesignTokens.Colors.textTertiary
        dateLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [iconView, actionLabel, UIView(), dateLabel])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with entry: DirectiveHistory) {
        let (icon, color): (String, UIColor) = switch entry.action {
        case .create:             ("plus.circle.fill",           DesignTokens.Colors.accent)
        case .update:              ("pencil.circle.fill",         DesignTokens.Colors.accent)
        case .graduate:            ("checkmark.seal.fill",        DesignTokens.Colors.warning)
        case .snooze:              ("moon.zzz.fill",              DesignTokens.Colors.accentSecondary)
        case .balloonPump:         ("arrow.up.circle.fill",       DesignTokens.Colors.success)
        case .shrink:              ("arrow.down.circle.fill",     DesignTokens.Colors.warning)
        case .split:               ("arrow.triangle.branch",      DesignTokens.Colors.accent)
        case .checklistComplete:   ("checkmark.circle.fill",      DesignTokens.Colors.success)
        }

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = color

        let actionText: String = switch entry.action {
        case .checklistComplete: "Completed"
        case .balloonPump:      "Balloon Pump"
        default: entry.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
        actionLabel.text = actionText

        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        dateLabel.text = fmt.localizedString(for: entry.createdAt, relativeTo: .now)
    }
}
