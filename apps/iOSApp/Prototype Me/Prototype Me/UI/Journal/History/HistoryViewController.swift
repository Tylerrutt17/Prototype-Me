import UIKit
import GRDB

/// Lists month summaries and weekly AI reviews. Pulls local stats from GRDB
/// and reviews from the PeriodicReview cache (also GRDB-observed).
class HistoryViewController: BaseViewController {

    var apiClient: APIClient?
    var periodicReviewService: PeriodicReviewService?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<HistorySection, HistoryItem>!

    // Local stats by month, populated from GRDB
    private var localSummaries: [HistoryMonthSummary] = []

    // AI reviews from the local cache, indexed by yyyy-MM
    private var monthlyReviews: [String: PeriodicReview] = [:]
    private var weeklyReviews: [String: [PeriodicReview]] = [:]

    private var reviewsObservationCancellable: AnyDatabaseCancellable?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("History", animated: false)
        showComingSoon()
    }

    private func showComingSoon() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .light)
        let iconView = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.textTertiary
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Intelligence Summaries"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Insights, trends, and weekly reviews — coming soon."
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentTopAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
        ])
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
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(160))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            // Tight spacing between weekly sub-cards within a month section
            section.interGroupSpacing = DesignTokens.Spacing.sm
            // First section gets top padding; subsequent sections just get bottom spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: sectionIndex == 0 ? DesignTokens.Spacing.lg : 0,
                leading: DesignTokens.Spacing.lg,
                bottom: DesignTokens.Spacing.md,
                trailing: DesignTokens.Spacing.lg
            )
            return section
        }
    }

    private func configureDataSource() {
        let monthReg = UICollectionView.CellRegistration<MonthSummaryCard, HistoryMonthSummary> { cell, _, summary in
            cell.configure(with: summary, review: self.monthlyReviews[summary.month])
        }

        let reviewReg = UICollectionView.CellRegistration<WeeklyReviewCard, PeriodicReview> { cell, _, review in
            cell.configure(with: review)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            switch item {
            case .monthSummary(let summary):
                return cv.dequeueConfiguredReusableCell(using: monthReg, for: indexPath, item: summary)
            case .aiReview(let review):
                return cv.dequeueConfiguredReusableCell(using: reviewReg, for: indexPath, item: review)
            }
        }
    }

    // MARK: - Data Loading

    private func loadLocalData() {
        let observation = ValueObservation.tracking { db -> [HistoryMonthSummary] in
            let entries = try DayEntry.order(Column("date").desc).fetchAll(db)
            return Self.buildMonthSummaries(from: entries)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] summaries in
            self?.localSummaries = summaries
            self?.applySnapshot()
        })
    }

    private func observeLocalReviews() {
        let observation = ValueObservation.tracking { db -> [PeriodicReview] in
            try PeriodicReview.order(Column("periodStart").desc).fetchAll(db)
        }

        reviewsObservationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] reviews in
            guard let self else { return }
            var monthly: [String: PeriodicReview] = [:]
            var weekly: [String: [PeriodicReview]] = [:]

            for review in reviews {
                let month = String(review.periodStart.prefix(7))
                if review.period == "monthly" {
                    monthly[month] = review
                } else {
                    weekly[month, default: []].append(review)
                }
            }

            self.monthlyReviews = monthly
            self.weeklyReviews = weekly
            self.applySnapshot()
        })
    }

    // MARK: - Snapshot

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<HistorySection, HistoryItem>()

        for summary in localSummaries {
            let section = HistorySection.month(summary.month)
            snapshot.appendSections([section])
            snapshot.appendItems([.monthSummary(summary)], toSection: section)
            if let weeklies = weeklyReviews[summary.month] {
                for review in weeklies {
                    snapshot.appendItems([.aiReview(review)], toSection: section)
                }
            }
        }

        dataSource.apply(snapshot, animatingDifferences: false)
        // HistoryMonthSummary / PeriodicReview use id-only equality, so diffing
        // alone won't re-render rows when their content changes.
        var reconfigSnap = dataSource.snapshot()
        reconfigSnap.reconfigureItems(reconfigSnap.itemIdentifiers)
        dataSource.apply(reconfigSnap, animatingDifferences: false)
    }

    // MARK: - Summary Builder

    private static func buildMonthSummaries(from entries: [DayEntry]) -> [HistoryMonthSummary] {
        var grouped: [String: [DayEntry]] = [:]
        for entry in entries {
            let month = String(entry.date.prefix(7))
            grouped[month, default: []].append(entry)
        }

        return grouped.keys.sorted(by: >).map { month in
            let monthEntries = grouped[month]!
            let ratings = monthEntries.compactMap(\.rating)
            let avgRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
            let best = monthEntries.filter { $0.rating != nil }.max { ($0.rating ?? 0) < ($1.rating ?? 0) }
            let worst = monthEntries.filter { $0.rating != nil }.min { ($0.rating ?? 0) < ($1.rating ?? 0) }

            var tagCounts: [String: Int] = [:]
            for entry in monthEntries {
                for tag in entry.tags { tagCounts[tag, default: 0] += 1 }
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

    // MARK: - Test Trigger (dev-only)

    private func triggerTestReview() {
        let alert = UIAlertController(title: "Generate Review", message: "Create a Prototype review for the current period?", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Weekly (this week)", style: .default) { [weak self] _ in
            self?.runTestTrigger(period: "weekly")
        })
        alert.addAction(UIAlertAction(title: "Monthly (this month)", style: .default) { [weak self] _ in
            self?.runTestTrigger(period: "monthly")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func runTestTrigger(period: String) {
        guard let apiClient else { return }

        let loading = UIAlertController(title: "Generating...", message: nil, preferredStyle: .alert)
        present(loading, animated: true)

        Task {
            struct TriggerResult: Decodable { let success: Bool; let message: String }
            do {
                let result: TriggerResult = try await apiClient.post("/v1/ai/reviews/test-trigger", body: ["period": period])
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        let done = UIAlertController(title: result.success ? "Done" : "Failed", message: result.message, preferredStyle: .alert)
                        done.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                            Task { try? await self?.periodicReviewService?.refreshFromServer() }
                        })
                        self.present(done, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    loading.dismiss(animated: true) {
                        let err = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)
                        err.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(err, animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension HistoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .monthSummary(let summary):
            let review = monthlyReviews[summary.month]
            let detail = ReviewDetailViewController(summary: summary, review: review)
            navigationController?.pushViewController(detail, animated: true)
        case .aiReview(let review):
            let detail = ReviewDetailViewController(summary: nil, review: review)
            navigationController?.pushViewController(detail, animated: true)
        }
    }
}
