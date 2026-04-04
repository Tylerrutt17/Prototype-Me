import UIKit

/// Card shown in the History list for a single month. Combines local stats
/// (entry count, avg rating, top tags) with optional AI-generated review content.
final class MonthSummaryCard: UICollectionViewCell {

    // Header
    private let monthLabel = UILabel()
    private let avgRatingPill = UILabel()
    private let subtitleLabel = UILabel()

    // Non-AI stats
    private let bestLabel = UILabel()
    private let worstLabel = UILabel()
    private let statsRow = UIStackView()

    // AI review content
    private let aiDivider = UIView()
    private let aiSummaryLabel = UILabel()
    private let aiDaysRow = UIStackView()
    private let aiBestPill = PaddedLabel()
    private let aiWorstPill = PaddedLabel()
    private let aiSuggestionContainer = UIView()
    private let aiSuggestionLabel = UILabel()
    private let aiDirectiveLabel = UILabel()

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

        // ── Header ──
        monthLabel.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        monthLabel.textColor = DesignTokens.Colors.textPrimary

        avgRatingPill.font = DesignTokens.Typography.rounded(style: .footnote, weight: .bold)
        avgRatingPill.textColor = DesignTokens.Colors.accent
        avgRatingPill.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        avgRatingPill.layer.cornerRadius = 10
        avgRatingPill.clipsToBounds = true
        avgRatingPill.textAlignment = .center
        avgRatingPill.setContentHuggingPriority(.required, for: .horizontal)

        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.numberOfLines = 0

        let topRow = UIStackView(arrangedSubviews: [monthLabel, UIView(), avgRatingPill])
        topRow.axis = .horizontal
        topRow.alignment = .center

        let headerStack = UIStackView(arrangedSubviews: [topRow, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = DesignTokens.Spacing.xxs

        // ── Non-AI stats (inline compact) ──
        bestLabel.font = DesignTokens.Typography.caption1
        bestLabel.textColor = DesignTokens.Colors.success
        bestLabel.numberOfLines = 0

        worstLabel.font = DesignTokens.Typography.caption1
        worstLabel.textColor = DesignTokens.Colors.warning
        worstLabel.numberOfLines = 0

        statsRow.addArrangedSubview(bestLabel)
        statsRow.addArrangedSubview(worstLabel)
        statsRow.axis = .vertical
        statsRow.spacing = DesignTokens.Spacing.xxs

        // ── AI: divider ──
        aiDivider.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        aiDivider.translatesAutoresizingMaskIntoConstraints = false
        aiDivider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        // ── AI: summary ──
        aiSummaryLabel.font = DesignTokens.Typography.subheadline
        aiSummaryLabel.textColor = DesignTokens.Colors.textPrimary
        aiSummaryLabel.numberOfLines = 0

        // ── AI: day pills ──
        configureDayPill(aiBestPill, color: DesignTokens.Colors.success)
        configureDayPill(aiWorstPill, color: DesignTokens.Colors.warning)

        aiDaysRow.addArrangedSubview(aiBestPill)
        aiDaysRow.addArrangedSubview(aiWorstPill)
        aiDaysRow.axis = .vertical
        aiDaysRow.spacing = DesignTokens.Spacing.xs
        aiDaysRow.alignment = .leading

        // ── AI: suggestion box ──
        aiSuggestionContainer.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.08)
        aiSuggestionContainer.layer.cornerRadius = DesignTokens.Radii.md

        aiSuggestionLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        aiSuggestionLabel.textColor = DesignTokens.Colors.accent
        aiSuggestionLabel.numberOfLines = 0
        aiSuggestionLabel.translatesAutoresizingMaskIntoConstraints = false
        aiSuggestionContainer.addSubview(aiSuggestionLabel)

        let sp = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            aiSuggestionLabel.topAnchor.constraint(equalTo: aiSuggestionContainer.topAnchor, constant: sp),
            aiSuggestionLabel.bottomAnchor.constraint(equalTo: aiSuggestionContainer.bottomAnchor, constant: -sp),
            aiSuggestionLabel.leadingAnchor.constraint(equalTo: aiSuggestionContainer.leadingAnchor, constant: sp),
            aiSuggestionLabel.trailingAnchor.constraint(equalTo: aiSuggestionContainer.trailingAnchor, constant: -sp),
        ])

        // ── AI: directive insights (small footnote) ──
        aiDirectiveLabel.font = DesignTokens.Typography.caption1
        aiDirectiveLabel.textColor = DesignTokens.Colors.textTertiary
        aiDirectiveLabel.numberOfLines = 0

        // ── Main stack ──
        mainStack = UIStackView(arrangedSubviews: [
            headerStack, statsRow, aiDivider, aiSummaryLabel, aiDaysRow, aiSuggestionContainer, aiDirectiveLabel,
        ])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.setCustomSpacing(DesignTokens.Spacing.sm, after: headerStack)
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    private func configureDayPill(_ pill: PaddedLabel, color: UIColor) {
        pill.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
        pill.textColor = color
        pill.backgroundColor = color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = DesignTokens.Radii.sm
        pill.clipsToBounds = true
        pill.numberOfLines = 0
        pill.contentInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    }

    func configure(with summary: HistoryMonthSummary, review: PeriodicReview?) {
        monthLabel.text = HistoryDateFormat.monthTitle(summary.month)

        // Avg rating pill
        if let avg = summary.averageRating {
            avgRatingPill.text = "  \(String(format: "%.1f", avg)) avg  "
            avgRatingPill.isHidden = false
        } else {
            avgRatingPill.isHidden = true
        }

        // Combined subtitle: "12 entries • work, exercise, reading"
        var subtitleParts: [String] = ["\(summary.entryCount) entr\(summary.entryCount == 1 ? "y" : "ies")"]
        if !summary.topTags.isEmpty {
            subtitleParts.append(summary.topTags.joined(separator: ", "))
        }
        subtitleLabel.text = subtitleParts.joined(separator: " • ")

        let hasReview = review != nil

        // Non-AI stats block: only show when no review (AI version uses pills)
        statsRow.isHidden = hasReview
        if !hasReview {
            if let best = summary.bestDay {
                bestLabel.text = "↑ Best: \(HistoryDateFormat.shortDate(best.date)) · \(best.rating ?? 0)/10"
                bestLabel.isHidden = false
            } else {
                bestLabel.isHidden = true
            }
            if let worst = summary.worstDay, worst.id != summary.bestDay?.id {
                worstLabel.text = "↓ Lowest: \(HistoryDateFormat.shortDate(worst.date)) · \(worst.rating ?? 0)/10"
                worstLabel.isHidden = false
            } else {
                worstLabel.isHidden = true
            }
            // Hide parent if neither has content
            statsRow.isHidden = bestLabel.isHidden && worstLabel.isHidden
        }

        // AI section
        aiDivider.isHidden = !hasReview
        aiSummaryLabel.isHidden = !hasReview
        aiDaysRow.isHidden = !hasReview
        aiSuggestionContainer.isHidden = true
        aiDirectiveLabel.isHidden = true

        guard let review else { return }

        aiSummaryLabel.text = review.summary

        // Day pills
        if let note = review.bestDayNote {
            let prefix = review.bestDay.map { "↑ \(HistoryDateFormat.shortDate($0))  " } ?? "↑ "
            aiBestPill.text = prefix + note
            aiBestPill.isHidden = false
        } else {
            aiBestPill.isHidden = true
        }
        if let note = review.lowestDayNote {
            let prefix = review.lowestDay.map { "↓ \(HistoryDateFormat.shortDate($0))  " } ?? "↓ "
            aiWorstPill.text = prefix + note
            aiWorstPill.isHidden = false
        } else {
            aiWorstPill.isHidden = true
        }
        aiDaysRow.isHidden = aiBestPill.isHidden && aiWorstPill.isHidden

        if let suggestion = review.suggestion, !suggestion.isEmpty {
            aiSuggestionLabel.text = "💡 \(suggestion)"
            aiSuggestionContainer.isHidden = false
        }

        if let insights = review.directiveInsights, !insights.isEmpty {
            aiDirectiveLabel.text = insights
            aiDirectiveLabel.isHidden = false
        }
    }
}

// MARK: - PaddedLabel

/// UILabel with contentInsets for use as pills/badges.
final class PaddedLabel: UILabel {
    var contentInsets: UIEdgeInsets = .zero { didSet { invalidateIntrinsicContentSize() } }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + contentInsets.left + contentInsets.right,
                      height: base.height + contentInsets.top + contentInsets.bottom)
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let inner = bounds.inset(by: contentInsets)
        let rect = super.textRect(forBounds: inner, limitedToNumberOfLines: numberOfLines)
        return CGRect(
            x: rect.origin.x - contentInsets.left,
            y: rect.origin.y - contentInsets.top,
            width: rect.width + contentInsets.left + contentInsets.right,
            height: rect.height + contentInsets.top + contentInsets.bottom
        )
    }
}
