import UIKit
import GRDB

nonisolated private enum HistorySection: Sendable { case main }

class HistoryViewController: BaseViewController {

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<HistorySection, HistoryMonthSummary>!

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("History", animated: false)

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
            collectionView.topAnchor.constraint(equalTo: contentTopAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = DesignTokens.Spacing.md
            section.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.lg,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.lg,
                trailing: DesignTokens.Spacing.lg
            )
            return section
        }
    }

    // MARK: - Data Source

    private func configureDataSource() {
        let cellReg = UICollectionView.CellRegistration<MonthSummaryCard, HistoryMonthSummary> { cell, _, summary in
            cell.configure(with: summary)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, summary in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: summary)
        }
    }

    // MARK: - Observe Data

    private func loadData() {
        let observation = ValueObservation.tracking { db -> [HistoryMonthSummary] in
            let entries = try DayEntry
                .order(Column("date").desc)
                .fetchAll(db)

            // Group by yyyy-MM
            var grouped: [String: [DayEntry]] = [:]
            for entry in entries {
                let month = String(entry.date.prefix(7)) // yyyy-MM
                grouped[month, default: []].append(entry)
            }

            let sortedMonths = grouped.keys.sorted(by: >)
            return sortedMonths.map { month in
                let monthEntries = grouped[month]!
                let ratings = monthEntries.compactMap(\.rating)
                let avgRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                let best = monthEntries.filter { $0.rating != nil }.max(by: { ($0.rating ?? 0) < ($1.rating ?? 0) })
                let worst = monthEntries.filter { $0.rating != nil }.min(by: { ($0.rating ?? 0) < ($1.rating ?? 0) })

                // Count tag frequencies
                var tagCounts: [String: Int] = [:]
                for entry in monthEntries {
                    for tag in entry.tags {
                        tagCounts[tag, default: 0] += 1
                    }
                }
                let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(3).map(\.key)

                return HistoryMonthSummary(
                    month: month,
                    entryCount: monthEntries.count,
                    averageRating: avgRating,
                    bestDay: best,
                    worstDay: worst,
                    topTags: topTags
                )
            }
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] summaries in
            var snapshot = NSDiffableDataSourceSnapshot<HistorySection, HistoryMonthSummary>()
            snapshot.appendSections([.main])
            snapshot.appendItems(summaries)
            self?.dataSource.apply(snapshot, animatingDifferences: false)

            var reconfigSnap = self?.dataSource.snapshot() ?? snapshot
            reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
            self?.dataSource.apply(reconfigSnap, animatingDifferences: false)
        })
    }
}

// MARK: - MonthSummaryCard

private final class MonthSummaryCard: UICollectionViewCell {

    private let monthLabel = UILabel()
    private let entryCountLabel = UILabel()
    private let avgRatingLabel = UILabel()
    private let bestLabel = UILabel()
    private let worstLabel = UILabel()
    private let tagsLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        monthLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        monthLabel.textColor = DesignTokens.Colors.textPrimary

        entryCountLabel.font = DesignTokens.Typography.caption1
        entryCountLabel.textColor = DesignTokens.Colors.textSecondary

        avgRatingLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        avgRatingLabel.textColor = DesignTokens.Colors.accent

        bestLabel.font = DesignTokens.Typography.caption1
        bestLabel.textColor = DesignTokens.Colors.success
        bestLabel.numberOfLines = 1

        worstLabel.font = DesignTokens.Typography.caption1
        worstLabel.textColor = DesignTokens.Colors.warning
        worstLabel.numberOfLines = 1

        tagsLabel.font = DesignTokens.Typography.caption1
        tagsLabel.textColor = DesignTokens.Colors.textTertiary

        let topRow = UIStackView(arrangedSubviews: [monthLabel, UIView(), avgRatingLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, entryCountLabel, bestLabel, worstLabel, tagsLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with summary: HistoryMonthSummary) {
        // Format yyyy-MM as "March 2026"
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        if let date = fmt.date(from: summary.month) {
            let displayFmt = DateFormatter()
            displayFmt.dateFormat = "MMMM yyyy"
            monthLabel.text = displayFmt.string(from: date)
        } else {
            monthLabel.text = summary.month
        }

        entryCountLabel.text = "\(summary.entryCount) entr\(summary.entryCount == 1 ? "y" : "ies")"

        if let avg = summary.averageRating {
            avgRatingLabel.text = String(format: "%.1f avg", avg)
            avgRatingLabel.isHidden = false
        } else {
            avgRatingLabel.isHidden = true
        }

        if let best = summary.bestDay {
            bestLabel.text = "Best: \(best.date) (\(best.rating ?? 0)/10)"
            bestLabel.isHidden = false
        } else {
            bestLabel.isHidden = true
        }

        if let worst = summary.worstDay, worst.id != summary.bestDay?.id {
            worstLabel.text = "Worst: \(worst.date) (\(worst.rating ?? 0)/10)"
            worstLabel.isHidden = false
        } else {
            worstLabel.isHidden = true
        }

        if !summary.topTags.isEmpty {
            tagsLabel.text = "Top tags: " + summary.topTags.joined(separator: ", ")
            tagsLabel.isHidden = false
        } else {
            tagsLabel.isHidden = true
        }
    }
}
