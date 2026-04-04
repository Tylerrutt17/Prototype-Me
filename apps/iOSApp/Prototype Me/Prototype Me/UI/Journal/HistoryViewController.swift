import UIKit
import GRDB

// MARK: - Section / Item

private enum HistorySection: Sendable {
    case month(String) // yyyy-MM
}
extension HistorySection: @preconcurrency Hashable {}

private enum HistoryItem: Sendable {
    case monthSummary(HistoryMonthSummary)
    case aiReview(PeriodicReview)
}
extension HistoryItem: @preconcurrency Hashable {}

// MARK: - HistoryViewController

class HistoryViewController: BaseViewController {

    var apiClient: APIClient?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<HistorySection, HistoryItem>!

    /// Local stats by month, populated from GRDB
    private var localSummaries: [HistoryMonthSummary] = []

    /// AI reviews fetched from backend, keyed by "period:periodStart"
    private var monthlyReviews: [String: PeriodicReview] = [:]  // key = yyyy-MM
    private var weeklyReviews: [String: [PeriodicReview]] = [:] // key = yyyy-MM, sorted by date

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("History", animated: false)

        configureCollectionView()
        configureDataSource()
        loadLocalData()
        if AuthService.isPro {
            fetchAIReviews()
            // Test trigger button (pro only for now)
            navBar.setRightButtons([
                NavBarButton(systemImage: "sparkles") { [weak self] in
                    self?.triggerTestReview()
                }
            ])
        }
    }

    // MARK: - Test Trigger

    private func triggerTestReview() {
        guard let apiClient else { return }

        let alert = UIAlertController(title: "Generate Review", message: "Create an AI review for the current period?", preferredStyle: .actionSheet)
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
                            self?.fetchAIReviews()
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

    // MARK: - Local Data (GRDB)

    private func loadLocalData() {
        let observation = ValueObservation.tracking { db -> [HistoryMonthSummary] in
            let entries = try DayEntry
                .order(Column("date").desc)
                .fetchAll(db)

            var grouped: [String: [DayEntry]] = [:]
            for entry in entries {
                let month = String(entry.date.prefix(7))
                grouped[month, default: []].append(entry)
            }

            let sortedMonths = grouped.keys.sorted(by: >)
            return sortedMonths.map { month in
                let monthEntries = grouped[month]!
                let ratings = monthEntries.compactMap(\.rating)
                let avgRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)
                let best = monthEntries.filter { $0.rating != nil }.max(by: { ($0.rating ?? 0) < ($1.rating ?? 0) })
                let worst = monthEntries.filter { $0.rating != nil }.min(by: { ($0.rating ?? 0) < ($1.rating ?? 0) })

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
            self?.localSummaries = summaries
            self?.applySnapshot()
        })
    }

    // MARK: - AI Reviews (Backend)

    private func fetchAIReviews() {
        guard let apiClient else { return }

        Task {
            do {
                let reviews: [PeriodicReview] = try await apiClient.get("/v1/ai/reviews")

                await MainActor.run {
                    // Index monthly reviews by yyyy-MM
                    self.monthlyReviews = [:]
                    self.weeklyReviews = [:]

                    for review in reviews {
                        let month = String(review.periodStart.prefix(7))
                        if review.period == "monthly" {
                            self.monthlyReviews[month] = review
                        } else {
                            self.weeklyReviews[month, default: []].append(review)
                        }
                    }

                    // Sort weekly reviews within each month
                    for (month, weeklies) in self.weeklyReviews {
                        self.weeklyReviews[month] = weeklies.sorted { $0.periodStart > $1.periodStart }
                    }

                    self.applySnapshot()
                }
            } catch {
                // Silently fail — local data still shows
            }
        }
    }

    // MARK: - Snapshot

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<HistorySection, HistoryItem>()

        for summary in localSummaries {
            let section = HistorySection.month(summary.month)
            snapshot.appendSections([section])

            // Month summary card (enhanced with AI review if available)
            snapshot.appendItems([.monthSummary(summary)], toSection: section)

            // Weekly review cards for this month
            if let weeklies = weeklyReviews[summary.month] {
                for review in weeklies {
                    snapshot.appendItems([.aiReview(review)], toSection: section)
                }
            }
        }

        dataSource.apply(snapshot, animatingDifferences: false)
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

    // AI review fields
    private let aiSummaryLabel = UILabel()
    private let aiSuggestionLabel = UILabel()
    private let aiDirectiveLabel = UILabel()
    private let aiDivider = UIView()

    private var mainStack: UIStackView!

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
        bestLabel.numberOfLines = 0

        worstLabel.font = DesignTokens.Typography.caption1
        worstLabel.textColor = DesignTokens.Colors.warning
        worstLabel.numberOfLines = 0

        tagsLabel.font = DesignTokens.Typography.caption1
        tagsLabel.textColor = DesignTokens.Colors.textTertiary

        // AI fields
        aiDivider.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        aiDivider.translatesAutoresizingMaskIntoConstraints = false
        aiDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        aiSummaryLabel.font = DesignTokens.Typography.body
        aiSummaryLabel.textColor = DesignTokens.Colors.textPrimary
        aiSummaryLabel.numberOfLines = 0

        aiSuggestionLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiSuggestionLabel.textColor = DesignTokens.Colors.accent
        aiSuggestionLabel.numberOfLines = 0

        aiDirectiveLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiDirectiveLabel.textColor = DesignTokens.Colors.textSecondary
        aiDirectiveLabel.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [monthLabel, UIView(), avgRatingLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        mainStack = UIStackView(arrangedSubviews: [
            topRow, entryCountLabel, bestLabel, worstLabel, tagsLabel,
            aiDivider, aiSummaryLabel, aiSuggestionLabel, aiDirectiveLabel,
        ])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with summary: HistoryMonthSummary, review: PeriodicReview?) {
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

        // Use AI review notes if available, fall back to raw data
        if let review, let bestNote = review.bestDayNote {
            bestLabel.text = "↑ \(bestNote)"
            bestLabel.isHidden = false
        } else if let best = summary.bestDay {
            bestLabel.text = "Best: \(best.date) (\(best.rating ?? 0)/10)"
            bestLabel.isHidden = false
        } else {
            bestLabel.isHidden = true
        }

        if let review, let lowestNote = review.lowestDayNote {
            worstLabel.text = "↓ \(lowestNote)"
            worstLabel.isHidden = false
        } else if let worst = summary.worstDay, worst.id != summary.bestDay?.id {
            worstLabel.text = "Lowest: \(worst.date) (\(worst.rating ?? 0)/10)"
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

        // AI review content
        let hasReview = review != nil
        aiDivider.isHidden = !hasReview
        aiSummaryLabel.isHidden = !hasReview
        aiSuggestionLabel.isHidden = true
        aiDirectiveLabel.isHidden = true

        if let review {
            aiSummaryLabel.text = review.summary

            if let suggestion = review.suggestion, !suggestion.isEmpty {
                aiSuggestionLabel.text = "💡 \(suggestion)"
                aiSuggestionLabel.isHidden = false
            }

            if let insights = review.directiveInsights, !insights.isEmpty {
                aiDirectiveLabel.text = insights
                aiDirectiveLabel.isHidden = false
            }
        }
    }
}

// MARK: - WeeklyReviewCard

private final class WeeklyReviewCard: UICollectionViewCell {

    private let weekLabel = UILabel()
    private let summaryLabel = UILabel()
    private let suggestionLabel = UILabel()
    private let ratingLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary.withAlphaComponent(0.5)
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        weekLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        weekLabel.textColor = DesignTokens.Colors.textSecondary

        ratingLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        ratingLabel.textColor = DesignTokens.Colors.accent

        summaryLabel.font = DesignTokens.Typography.footnote
        summaryLabel.textColor = DesignTokens.Colors.textPrimary
        summaryLabel.numberOfLines = 0

        suggestionLabel.font = DesignTokens.Typography.rounded(style: .caption1, weight: .medium)
        suggestionLabel.textColor = DesignTokens.Colors.accent
        suggestionLabel.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [weekLabel, UIView(), ratingLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, summaryLabel, suggestionLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
        ])
    }

    func configure(with review: PeriodicReview) {
        // Format week range
        weekLabel.text = formatWeekRange(start: review.periodStart, end: review.periodEnd)

        summaryLabel.text = review.summary

        if let avg = review.avgRating {
            ratingLabel.text = String(format: "%.1f avg", avg)
            ratingLabel.isHidden = false
        } else {
            ratingLabel.isHidden = true
        }

        if let suggestion = review.suggestion, !suggestion.isEmpty {
            suggestionLabel.text = "💡 \(suggestion)"
            suggestionLabel.isHidden = false
        } else {
            suggestionLabel.isHidden = true
        }
    }

    private func formatWeekRange(start: String, end: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let startDate = fmt.date(from: start), let endDate = fmt.date(from: end) else {
            return "Week of \(start)"
        }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return "\(display.string(from: startDate)) – \(display.string(from: endDate))"
    }
}
