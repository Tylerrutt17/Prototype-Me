import UIKit

nonisolated private enum DirectiveDetailSection: Int, Sendable {
    case header
    case balloon
    case schedule
    case history
}

nonisolated private enum DirectiveDetailItem: Hashable, Sendable {
    case header(UUID)
    case balloon(UUID)
    case scheduleRule(ScheduleRule)
    case historyEntry(DirectiveHistory)
}

class DirectiveDetailViewController: BaseViewController {

    var directiveId: UUID?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<DirectiveDetailSection, DirectiveDetailItem>!

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        loadData()
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
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
        let headerReg = UICollectionView.CellRegistration<DirectiveHeaderCell, UUID> { cell, _, directiveId in
            guard let dir = SampleData.directives.first(where: { $0.id == directiveId }) else { return }
            cell.configure(with: dir)
        }

        let balloonReg = UICollectionView.CellRegistration<BalloonCard, UUID> { cell, _, directiveId in
            guard let dir = SampleData.directives.first(where: { $0.id == directiveId }) else { return }
            let row = DirectiveRowData(directive: dir, scheduledToday: false, instanceStatus: nil)
            cell.configure(with: row)
        }

        let scheduleReg = UICollectionView.CellRegistration<ScheduleRuleCell, ScheduleRule> { cell, _, rule in
            cell.configure(with: rule)
        }

        let historyReg = UICollectionView.CellRegistration<HistoryEntryCell, DirectiveHistory> { cell, _, entry in
            cell.configure(with: entry)
        }

        dataSource = UICollectionViewDiffableDataSource<DirectiveDetailSection, DirectiveDetailItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .header(let id):
                return collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: id)
            case .balloon(let id):
                return collectionView.dequeueConfiguredReusableCell(using: balloonReg, for: indexPath, item: id)
            case .scheduleRule(let rule):
                return collectionView.dequeueConfiguredReusableCell(using: scheduleReg, for: indexPath, item: rule)
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

    // MARK: - Load Data

    private func loadData() {
        guard let directiveId else { return }
        guard let directive = SampleData.directives.first(where: { $0.id == directiveId }) else { return }

        navigationItem.title = directive.title

        var snapshot = NSDiffableDataSourceSnapshot<DirectiveDetailSection, DirectiveDetailItem>()

        // Header
        snapshot.appendSections([.header])
        snapshot.appendItems([.header(directiveId)], toSection: .header)

        // Balloon (if enabled)
        if directive.balloonEnabled {
            snapshot.appendSections([.balloon])
            snapshot.appendItems([.balloon(directiveId)], toSection: .balloon)
        }

        // Schedule rules
        let rules = SampleData.scheduleRules.filter { $0.directiveId == directiveId }
        if !rules.isEmpty {
            snapshot.appendSections([.schedule])
            snapshot.appendItems(rules.map { .scheduleRule($0) }, toSection: .schedule)
        }

        // History
        let history = SampleData.history(forDirectiveId: directiveId)
        if !history.isEmpty {
            snapshot.appendSections([.history])
            snapshot.appendItems(history.map { .historyEntry($0) }, toSection: .history)
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - DirectiveHeaderCell

private final class DirectiveHeaderCell: UICollectionViewCell {

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let statusBadge = StatusBadgeView()
    private let pressureIndicator = PressureIndicator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        titleLabel.font = DesignTokens.Typography.title2
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        pressureIndicator.size = 14

        let metaRow = UIStackView(arrangedSubviews: [statusBadge, pressureIndicator, UIView()])
        metaRow.axis = .horizontal
        metaRow.spacing = DesignTokens.Spacing.sm
        metaRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, metaRow, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            pressureIndicator.widthAnchor.constraint(equalToConstant: 14),
            pressureIndicator.heightAnchor.constraint(equalToConstant: 14),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.xl),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with directive: Directive) {
        titleLabel.text = directive.title
        bodyLabel.text = directive.body
        bodyLabel.isHidden = directive.body == nil
        statusBadge.configure(status: directive.status)
        pressureIndicator.configure(level: directive.pressureLevel)
        pressureIndicator.isHidden = !directive.balloonEnabled
    }
}

// MARK: - ScheduleRuleCell

private final class ScheduleRuleCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let descLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.sm
        contentView.clipsToBounds = true

        iconView.image = UIImage(systemName: "calendar.badge.clock")
        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        descLabel.font = DesignTokens.Typography.subheadline
        descLabel.textColor = DesignTokens.Colors.textPrimary
        descLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, descLabel])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.md
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

    func configure(with rule: ScheduleRule) {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let text: String = switch rule.ruleType {
        case .weekly:
            "Weekly: " + (rule.params["days"] ?? []).compactMap { d in
                (1...7).contains(d) ? dayNames[d - 1] : nil
            }.joined(separator: ", ")
        case .monthly:
            "Monthly: " + (rule.params["dates"] ?? []).map { "\($0)" }.joined(separator: ", ")
        case .oneOff:
            "One-off"
        }
        descLabel.text = text
    }
}

// MARK: - HistoryEntryCell

private final class HistoryEntryCell: UICollectionViewCell {

    private let actionLabel = UILabel()
    private let dateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.sm
        contentView.clipsToBounds = true

        actionLabel.font = DesignTokens.Typography.subheadline
        actionLabel.textColor = DesignTokens.Colors.textPrimary

        dateLabel.font = DesignTokens.Typography.caption1
        dateLabel.textColor = DesignTokens.Colors.textTertiary

        let stack = UIStackView(arrangedSubviews: [actionLabel, UIView(), dateLabel])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.sm),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with entry: DirectiveHistory) {
        actionLabel.text = entry.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized

        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        dateLabel.text = fmt.string(from: entry.createdAt)
    }
}
