import UIKit
import GRDB

nonisolated private enum DirectiveDetailSection: Int, Sendable {
    case header
    case balloon
    case schedule
    case history
}

nonisolated private enum DirectiveDetailItem: Hashable, Sendable {
    case header(Directive)
    case balloon(DirectiveRowData)
    case scheduleRule(ScheduleRule)
    case addScheduleButton
    case historyEntry(DirectiveHistory)
}

class DirectiveDetailViewController: BaseViewController {

    var directiveId: UUID?
    var onEditTapped: ((UUID) -> Void)?
    var onAddScheduleTapped: ((UUID) -> Void)?
    var onEditScheduleTapped: ((UUID, ScheduleRule) -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DirectiveDetailSection, DirectiveDetailItem>!

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
        guard let directiveId else { return }
        onEditTapped?(directiveId)
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
        let headerReg = UICollectionView.CellRegistration<DirectiveHeaderCell, Directive> { cell, _, directive in
            cell.configure(with: directive)
        }

        let balloonReg = UICollectionView.CellRegistration<BalloonCard, DirectiveRowData> { [weak self] cell, _, data in
            cell.dbQueue = self?.dbQueue
            cell.configure(with: data)
        }

        let scheduleReg = UICollectionView.CellRegistration<ScheduleRuleCell, ScheduleRule> { cell, _, rule in
            cell.configure(with: rule)
        }

        let historyReg = UICollectionView.CellRegistration<HistoryEntryCell, DirectiveHistory> { cell, _, entry in
            cell.configure(with: entry)
        }

        let addScheduleReg = UICollectionView.CellRegistration<LinkButtonCell, String> { cell, _, title in
            cell.configure(title: title, systemImage: "calendar.badge.plus")
        }

        dataSource = UICollectionViewDiffableDataSource<DirectiveDetailSection, DirectiveDetailItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header(let directive):
                return collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: directive)
            case .balloon(let data):
                return collectionView.dequeueConfiguredReusableCell(using: balloonReg, for: indexPath, item: data)
            case .scheduleRule(let rule):
                return collectionView.dequeueConfiguredReusableCell(using: scheduleReg, for: indexPath, item: rule)
            case .addScheduleButton:
                return collectionView.dequeueConfiguredReusableCell(using: addScheduleReg, for: indexPath, item: "Add Schedule")
            case .historyEntry(let entry):
                return collectionView.dequeueConfiguredReusableCell(using: historyReg, for: indexPath, item: entry)
            }
        }

        let sectionHeaderReg = UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind: UICollectionView.elementKindSectionHeader) { supplementaryView, _, indexPath in
            let section = DirectiveDetailSection(rawValue: indexPath.section)
            let title: String = switch section {
            case .balloon:  "Balloon"
            case .schedule: "Schedule"
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

        let observation = ValueObservation.tracking { db -> (Directive?, [ScheduleRule], [DirectiveHistory]) in
            let directive = try Directive.fetchOne(db, key: directiveId)
            let rules = try ScheduleRule
                .filter(Column("directiveId") == directiveId)
                .fetchAll(db)
            let history = try DirectiveHistory
                .filter(Column("directiveId") == directiveId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
            return (directive, rules, history)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] (directive, rules, history) in
            guard let directive else { return }
            self?.navBar.setTitle(directive.title)

            var snapshot = NSDiffableDataSourceSnapshot<DirectiveDetailSection, DirectiveDetailItem>()

            snapshot.appendSections([.header])
            snapshot.appendItems([.header(directive)], toSection: .header)

            if directive.balloonEnabled {
                snapshot.appendSections([.balloon])
                let row = DirectiveRowData(directive: directive, scheduledToday: false, instanceStatus: nil)
                snapshot.appendItems([.balloon(row)], toSection: .balloon)
            }

            snapshot.appendSections([.schedule])
            if let rule = rules.first {
                // One rule per directive — show it (tap to edit)
                snapshot.appendItems([.scheduleRule(rule)], toSection: .schedule)
            } else {
                snapshot.appendItems([.addScheduleButton], toSection: .schedule)
            }

            if !history.isEmpty {
                snapshot.appendSections([.history])
                snapshot.appendItems(history.map { .historyEntry($0) }, toSection: .history)
            }

            self?.dataSource.apply(snapshot, animatingDifferences: false)
            // Force cell refresh since models use id-only equality
            var reconfigSnap = self?.dataSource.snapshot() ?? snapshot
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self?.dataSource.apply(reconfigSnap, animatingDifferences: false)
        })
    }
}

// MARK: - UICollectionViewDelegate

extension DirectiveDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .addScheduleButton:
            guard let directiveId else { return }
            onAddScheduleTapped?(directiveId)
        case .scheduleRule(let rule):
            guard let directiveId else { return }
            onEditScheduleTapped?(directiveId, rule)
        default:
            break
        }
    }
}

// MARK: - DirectiveHeaderCell

private final class DirectiveHeaderCell: UICollectionViewCell {

    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let statusBadge = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let divider = UIView()
    private let bodyLabel = UILabel()
    private let pressureIndicator = PressureIndicator()
    private let metaLabel = UILabel()

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

        // Accent bar
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        // Status badge pill
        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        statusBadge.configuration = badgeConfig
        statusBadge.isUserInteractionEnabled = false
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusBadge)

        // Title
        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        // Divider
        divider.layer.cornerRadius = 1.5

        // Body
        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        // Pressure indicator
        pressureIndicator.size = 16

        // Meta label (created date)
        metaLabel.font = DesignTokens.Typography.caption1
        metaLabel.textColor = DesignTokens.Colors.textTertiary

        // Pressure + meta row
        let bottomRow = UIStackView(arrangedSubviews: [pressureIndicator, metaLabel, UIView()])
        bottomRow.axis = .horizontal
        bottomRow.spacing = DesignTokens.Spacing.sm
        bottomRow.alignment = .center

        // Wrap divider so .fill alignment doesn't stretch it
        let dividerWrapper = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        dividerWrapper.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.leadingAnchor.constraint(equalTo: dividerWrapper.leadingAnchor),
            divider.topAnchor.constraint(equalTo: dividerWrapper.topAnchor),
            divider.bottomAnchor.constraint(equalTo: dividerWrapper.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 40),
            divider.heightAnchor.constraint(equalToConstant: 3),
        ])

        let stack = UIStackView(arrangedSubviews: [titleLabel, dividerWrapper, bodyLabel, bottomRow])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            statusBadge.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: DesignTokens.Spacing.lg),
            statusBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),

            pressureIndicator.widthAnchor.constraint(equalToConstant: 16),
            pressureIndicator.heightAnchor.constraint(equalToConstant: 16),

            stack.topAnchor.constraint(equalTo: statusBadge.bottomAnchor, constant: DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),
        ])
    }

    func configure(with directive: Directive) {
        // Status color
        let color: UIColor = switch directive.status {
        case .active:   DesignTokens.Colors.success
        case .archived: DesignTokens.Colors.textTertiary
        }

        // Accent bar
        accentBar.backgroundColor = color

        // Status badge
        var badgeCfg = statusBadge.configuration ?? .filled()
        badgeCfg.title = directive.status.rawValue.uppercased()
        badgeCfg.baseBackgroundColor = color.withAlphaComponent(0.15)
        badgeCfg.baseForegroundColor = color
        badgeCfg.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            return c
        }
        statusBadge.configuration = badgeCfg

        // Title
        titleLabel.text = directive.title

        // Divider
        divider.backgroundColor = color.withAlphaComponent(0.4)

        // Body
        bodyLabel.text = directive.body
        bodyLabel.isHidden = directive.body == nil

        // Pressure
        pressureIndicator.configure(level: directive.pressureLevel)
        pressureIndicator.isHidden = !directive.balloonEnabled

        // Meta
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        metaLabel.text = "Created " + fmt.localizedString(for: directive.createdAt, relativeTo: .now)
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
        case .create:      ("plus.circle.fill",           DesignTokens.Colors.accent)
        case .update:       ("pencil.circle.fill",         DesignTokens.Colors.accent)
        case .graduate:     ("checkmark.seal.fill",        DesignTokens.Colors.warning)
        case .snooze:       ("moon.zzz.fill",              DesignTokens.Colors.accentSecondary)
        case .balloonPump:  ("arrow.up.circle.fill",       DesignTokens.Colors.success)
        case .shrink:       ("arrow.down.circle.fill",     DesignTokens.Colors.warning)
        case .split:        ("arrow.triangle.branch",      DesignTokens.Colors.accent)
        }

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = color

        actionLabel.text = entry.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized

        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        dateLabel.text = fmt.localizedString(for: entry.createdAt, relativeTo: .now)
    }
}
