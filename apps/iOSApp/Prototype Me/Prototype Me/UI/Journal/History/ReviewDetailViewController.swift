import UIKit

/// Full-screen detail view for a single month or weekly review.
final class ReviewDetailViewController: BaseViewController {

    private let summary: HistoryMonthSummary?
    private let review: PeriodicReview?
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(summary: HistoryMonthSummary?, review: PeriodicReview?) {
        self.summary = summary
        self.review = review
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle(navTitle(), animated: false)
        setupScrollView()
        populateContent()
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.lg
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -DesignTokens.Spacing.xxl),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -DesignTokens.Spacing.lg * 2),
        ])
    }

    private func populateContent() {
        // Stats header
        if let summary {
            let entryCount = review?.entryCount ?? summary.entryCount
            let avgRating = review?.avgRating ?? summary.averageRating
            contentStack.addArrangedSubview(makeStatsRow(entryCount: entryCount, avgRating: avgRating, topTags: summary.topTags))
        } else if let review {
            contentStack.addArrangedSubview(makeStatsRow(entryCount: review.entryCount, avgRating: review.avgRating, topTags: []))
        }

        guard let review else {
            let empty = UILabel()
            empty.text = "No AI review available yet for this period."
            empty.font = DesignTokens.Typography.body
            empty.textColor = DesignTokens.Colors.textTertiary
            empty.numberOfLines = 0
            empty.textAlignment = .center
            contentStack.addArrangedSubview(empty)
            return
        }

        // Summary
        contentStack.addArrangedSubview(makeSection(title: "Summary", body: review.summary, accentColor: DesignTokens.Colors.textPrimary))

        // Best Day
        if let bestNote = review.bestDayNote {
            let bestTitle = review.bestDay.map { "Best Day • \(HistoryDateFormat.shortDate($0))" } ?? "Best Day"
            contentStack.addArrangedSubview(makeSection(title: bestTitle, body: bestNote, accentColor: DesignTokens.Colors.success))
        }

        // Lowest Day
        if let lowestNote = review.lowestDayNote {
            let lowestTitle = review.lowestDay.map { "Lowest Day • \(HistoryDateFormat.shortDate($0))" } ?? "Lowest Day"
            contentStack.addArrangedSubview(makeSection(title: lowestTitle, body: lowestNote, accentColor: DesignTokens.Colors.warning))
        }

        // Suggestion
        if let suggestion = review.suggestion, !suggestion.isEmpty {
            contentStack.addArrangedSubview(makeSection(title: "💡 Suggestion", body: suggestion, accentColor: DesignTokens.Colors.accent))
        }

        // Directive Insights
        if let insights = review.directiveInsights, !insights.isEmpty {
            contentStack.addArrangedSubview(makeSection(title: "Habit Insights", body: insights, accentColor: DesignTokens.Colors.accent))
        }
    }

    // MARK: - Builders

    private func makeStatsRow(entryCount: Int, avgRating: Double?, topTags: [String]) -> UIView {
        let container = UIView()
        container.backgroundColor = DesignTokens.Colors.surfacePrimary
        container.layer.cornerRadius = DesignTokens.Radii.lg

        let entryStat = makeStat(value: "\(entryCount)", label: entryCount == 1 ? "Entry" : "Entries")
        let ratingStat = makeStat(value: avgRating.map { String(format: "%.1f", $0) } ?? "—", label: "Avg Rating")

        let statsRow = UIStackView(arrangedSubviews: [entryStat, ratingStat])
        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statsRow)

        var bottomAnchor: NSLayoutYAxisAnchor = statsRow.bottomAnchor

        if !topTags.isEmpty {
            let tagsLabel = UILabel()
            tagsLabel.text = "Top tags: " + topTags.joined(separator: ", ")
            tagsLabel.font = DesignTokens.Typography.caption1
            tagsLabel.textColor = DesignTokens.Colors.textSecondary
            tagsLabel.textAlignment = .center
            tagsLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(tagsLabel)
            NSLayoutConstraint.activate([
                tagsLabel.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: DesignTokens.Spacing.md),
                tagsLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.lg),
                tagsLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            ])
            bottomAnchor = tagsLabel.bottomAnchor
        }

        NSLayoutConstraint.activate([
            statsRow.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.lg),
            statsRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.lg),
            statsRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: DesignTokens.Spacing.lg),
        ])

        return container
    }

    private func makeStat(value: String, label: String) -> UIView {
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        valueLabel.textColor = DesignTokens.Colors.accent
        valueLabel.textAlignment = .center

        let captionLabel = UILabel()
        captionLabel.text = label
        captionLabel.font = DesignTokens.Typography.caption1
        captionLabel.textColor = DesignTokens.Colors.textTertiary
        captionLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xxs
        return stack
    }

    private func makeSection(title: String, body: String, accentColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = DesignTokens.Colors.surfacePrimary
        container.layer.cornerRadius = DesignTokens.Radii.lg

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        titleLabel.textColor = accentColor
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textPrimary
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -pad),
        ])

        return container
    }

    // MARK: - Title

    private func navTitle() -> String {
        if let summary { return HistoryDateFormat.monthTitle(summary.month) }
        if let review { return HistoryDateFormat.weekRange(start: review.periodStart, end: review.periodEnd) }
        return "Review"
    }
}
