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
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.md
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let frameGuide = scrollView.frameLayoutGuide
        let contentGuide = scrollView.contentLayoutGuide
        let pad = DesignTokens.Spacing.lg

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: pad),
            contentStack.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: pad),
            contentStack.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -pad),
            contentStack.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -DesignTokens.Spacing.xxl),
            // Lock width to frame so subviews fill correctly
            contentStack.widthAnchor.constraint(equalTo: frameGuide.widthAnchor, constant: -pad * 2),
        ])
    }

    private func populateContent() {
        // Period label
        contentStack.addArrangedSubview(makePeriodHeader())

        // Stats row
        let entryCount = review?.entryCount ?? summary?.entryCount ?? 0
        let avgRating = review?.avgRating ?? summary?.averageRating
        let topTags = summary?.topTags ?? []
        contentStack.addArrangedSubview(makeStatsCard(entryCount: entryCount, avgRating: avgRating, topTags: topTags))

        guard let review else {
            contentStack.addArrangedSubview(makeEmptyState())
            return
        }

        // Summary (prominent, first piece of AI content)
        contentStack.addArrangedSubview(makeSummaryCard(text: review.summary))

        // Best/Lowest day cards side by side
        if review.bestDayNote != nil || review.lowestDayNote != nil {
            contentStack.addArrangedSubview(makeDayCards(review: review))
        }

        // Suggestion — accented card
        if let suggestion = review.suggestion, !suggestion.isEmpty {
            contentStack.addArrangedSubview(makeSuggestionCard(text: suggestion))
        }

        // Directive insights
        if let insights = review.directiveInsights, !insights.isEmpty {
            contentStack.addArrangedSubview(makeInsightsCard(text: insights))
        }
    }

    // MARK: - Builders

    private func makePeriodHeader() -> UIView {
        let label = UILabel()
        label.font = DesignTokens.Typography.caption1
        label.textColor = DesignTokens.Colors.textTertiary
        if let r = review {
            let fmt = r.period == "monthly" ? "MONTHLY REVIEW" : "WEEKLY REVIEW"
            label.text = fmt
        } else if summary != nil {
            label.text = "MONTH SUMMARY"
        }
        label.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)

        let container = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
        ])
        return container
    }

    private func makeStatsCard(entryCount: Int, avgRating: Double?, topTags: [String]) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.translatesAutoresizingMaskIntoConstraints = false

        let entryStat = makeStat(value: "\(entryCount)", label: entryCount == 1 ? "Entry" : "Entries")
        let ratingStat = makeStat(value: avgRating.map { String(format: "%.1f", $0) } ?? "—", label: "Avg Rating")

        let divider = UIView()
        divider.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        let statsRow = UIStackView(arrangedSubviews: [entryStat, divider, ratingStat])
        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        statsRow.alignment = .center
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statsRow)

        var bottomAnchor: NSLayoutYAxisAnchor = statsRow.bottomAnchor
        let pad = DesignTokens.Spacing.lg

        if !topTags.isEmpty {
            let tagsLabel = UILabel()
            tagsLabel.text = "Top tags: " + topTags.joined(separator: ", ")
            tagsLabel.font = DesignTokens.Typography.caption1
            tagsLabel.textColor = DesignTokens.Colors.textSecondary
            tagsLabel.textAlignment = .center
            tagsLabel.numberOfLines = 0
            tagsLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(tagsLabel)

            let separator = UIView()
            separator.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
            separator.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(separator)

            NSLayoutConstraint.activate([
                separator.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: DesignTokens.Spacing.md),
                separator.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
                separator.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
                separator.heightAnchor.constraint(equalToConstant: 1),

                tagsLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: DesignTokens.Spacing.md),
                tagsLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
                tagsLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            ])
            bottomAnchor = tagsLabel.bottomAnchor
        }

        NSLayoutConstraint.activate([
            statsRow.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            statsRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            statsRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            divider.heightAnchor.constraint(equalTo: statsRow.heightAnchor, multiplier: 0.6),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: pad),
        ])

        return card
    }

    private func makeStat(value: String, label: String) -> UIView {
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        valueLabel.textColor = DesignTokens.Colors.accent
        valueLabel.textAlignment = .center

        let captionLabel = UILabel()
        captionLabel.text = label.uppercased()
        captionLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .semibold)
        captionLabel.textColor = DesignTokens.Colors.textTertiary
        captionLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLabel, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    private func makeSummaryCard(text: String) -> UIView {
        makeTextCard(
            header: nil,
            body: text,
            bodyFont: DesignTokens.Typography.body,
            bodyColor: DesignTokens.Colors.textPrimary,
            background: DesignTokens.Colors.surfacePrimary
        )
    }

    private func makeDayCards(review: PeriodicReview) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm

        if let note = review.bestDayNote {
            let title = review.bestDay.map { "↑ Best Day · \(HistoryDateFormat.shortDate($0))" } ?? "↑ Best Day"
            stack.addArrangedSubview(makeDayCard(title: title, body: note, accent: DesignTokens.Colors.success))
        }
        if let note = review.lowestDayNote {
            let title = review.lowestDay.map { "↓ Lowest Day · \(HistoryDateFormat.shortDate($0))" } ?? "↓ Lowest Day"
            stack.addArrangedSubview(makeDayCard(title: title, body: note, accent: DesignTokens.Colors.warning))
        }
        return stack
    }

    private func makeDayCard(title: String, body: String, accent: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = accent.withAlphaComponent(0.08)
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = 1
        card.layer.borderColor = accent.withAlphaComponent(0.2).cgColor

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .bold)
        titleLabel.textColor = accent

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = DesignTokens.Typography.subheadline
        bodyLabel.textColor = DesignTokens.Colors.textPrimary
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])
        return card
    }

    private func makeSuggestionCard(text: String) -> UIView {
        makeTextCard(
            header: "💡 SUGGESTION",
            body: text,
            bodyFont: DesignTokens.Typography.subheadline,
            bodyColor: DesignTokens.Colors.textPrimary,
            background: DesignTokens.Colors.accent.withAlphaComponent(0.08),
            headerColor: DesignTokens.Colors.accent,
            borderColor: DesignTokens.Colors.accent.withAlphaComponent(0.2)
        )
    }

    private func makeInsightsCard(text: String) -> UIView {
        makeTextCard(
            header: "HABIT INSIGHTS",
            body: text,
            bodyFont: DesignTokens.Typography.subheadline,
            bodyColor: DesignTokens.Colors.textSecondary,
            background: DesignTokens.Colors.surfacePrimary,
            headerColor: DesignTokens.Colors.textTertiary
        )
    }

    private func makeTextCard(
        header: String?,
        body: String,
        bodyFont: UIFont,
        bodyColor: UIColor,
        background: UIColor,
        headerColor: UIColor = DesignTokens.Colors.textTertiary,
        borderColor: UIColor? = nil
    ) -> UIView {
        let card = UIView()
        card.backgroundColor = background
        card.layer.cornerRadius = DesignTokens.Radii.lg
        if let borderColor {
            card.layer.borderWidth = 1
            card.layer.borderColor = borderColor.cgColor
        }

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = bodyFont
        bodyLabel.textColor = bodyColor
        bodyLabel.numberOfLines = 0

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false

        if let header {
            let headerLabel = UILabel()
            headerLabel.text = header
            headerLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            headerLabel.textColor = headerColor
            stack.addArrangedSubview(headerLabel)
        }
        stack.addArrangedSubview(bodyLabel)
        card.addSubview(stack)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])
        return card
    }

    private func makeEmptyState() -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg

        let icon = UIImageView(image: UIImage(systemName: "sparkles"))
        icon.tintColor = DesignTokens.Colors.textTertiary
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = "No AI review for this period yet."
        label.font = DesignTokens.Typography.subheadline
        label.textColor = DesignTokens.Colors.textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let pad = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
            icon.heightAnchor.constraint(equalToConstant: 28),
        ])
        return card
    }

    // MARK: - Title

    private func navTitle() -> String {
        if let summary { return HistoryDateFormat.monthTitle(summary.month) }
        if let review { return HistoryDateFormat.weekRange(start: review.periodStart, end: review.periodEnd) }
        return "Review"
    }
}
