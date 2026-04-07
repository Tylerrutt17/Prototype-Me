import UIKit

/// Displays AI usage quota: remaining requests, usage bar, reset time.
class UsageLimitViewController: BaseViewController {

    var quota: UsageQuota? { didSet { if isViewLoaded { rebuildContent() } } }
    var plan: SubscriptionPlan = .free { didSet { if isViewLoaded { rebuildContent() } } }
    var onUpgradeTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Prototype Usage", animated: false)
        configureLayout()
        if quota != nil {
            buildContent()
        } else {
            showSpinner()
        }
    }

    private func showSpinner() {
        spinner.color = DesignTokens.Colors.textSecondary
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        spinner.startAnimating()
    }

    private func rebuildContent() {
        spinner.stopAnimating()
        spinner.removeFromSuperview()
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buildContent()
    }

    func showLoadError(_ message: String) {
        spinner.stopAnimating()
        spinner.removeFromSuperview()
        let label = UILabel()
        label.text = message
        label.font = DesignTokens.Typography.body
        label.textColor = DesignTokens.Colors.textSecondary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Layout

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = DesignTokens.Spacing.xl
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: DesignTokens.Spacing.xxl),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -padding * 2),
        ])
    }

    // MARK: - Content

    private func buildContent() {
        guard let quota else { return }

        // Quota card
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = DesignTokens.Spacing.lg
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        let cardPadding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: cardPadding),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: cardPadding),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -cardPadding),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -cardPadding),
        ])

        // Remaining count
        let countLabel = UILabel()
        countLabel.text = "\(quota.remaining)"
        countLabel.font = DesignTokens.Typography.rounded(style: .largeTitle, weight: .bold)
        countLabel.textColor = quota.remaining <= 2 ? DesignTokens.Colors.destructive : DesignTokens.Colors.accent
        countLabel.textAlignment = .center

        let ofLabel = UILabel()
        ofLabel.text = "of \(quota.dailyLimit) Prototype suggestions remaining today"
        ofLabel.font = DesignTokens.Typography.subheadline
        ofLabel.textColor = DesignTokens.Colors.textSecondary
        ofLabel.textAlignment = .center

        let countStack = UIStackView(arrangedSubviews: [countLabel, ofLabel])
        countStack.axis = .vertical
        countStack.spacing = DesignTokens.Spacing.xs
        cardStack.addArrangedSubview(countStack)

        // Progress bar
        let progressTrack = UIView()
        progressTrack.backgroundColor = DesignTokens.Colors.surfaceSecondary
        progressTrack.layer.cornerRadius = 6
        progressTrack.heightAnchor.constraint(equalToConstant: 12).isActive = true

        let progressFill = UIView()
        let fillColor: UIColor = quota.usageRatio >= 0.9
            ? DesignTokens.Colors.destructive
            : quota.usageRatio >= 0.6
                ? DesignTokens.Colors.warning
                : DesignTokens.Colors.accent
        progressFill.backgroundColor = fillColor
        progressFill.layer.cornerRadius = 6
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)

        NSLayoutConstraint.activate([
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: min(1.0, quota.usageRatio)),
        ])

        cardStack.addArrangedSubview(progressTrack)

        // Reset time
        let resetLabel = UILabel()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        resetLabel.text = "Resets at \(formatter.string(from: quota.resetAt))"
        resetLabel.font = DesignTokens.Typography.footnote
        resetLabel.textColor = DesignTokens.Colors.textTertiary
        resetLabel.textAlignment = .center
        cardStack.addArrangedSubview(resetLabel)

        contentStack.addArrangedSubview(card)

        // Usage history (dummy)
        let historyCard = UIView()
        historyCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        historyCard.layer.cornerRadius = DesignTokens.Radii.lg

        let historyStack = UIStackView()
        historyStack.axis = .vertical
        historyStack.spacing = DesignTokens.Spacing.md
        historyStack.translatesAutoresizingMaskIntoConstraints = false
        historyCard.addSubview(historyStack)

        NSLayoutConstraint.activate([
            historyStack.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: cardPadding),
            historyStack.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: cardPadding),
            historyStack.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -cardPadding),
            historyStack.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -cardPadding),
        ])

        let historyTitle = UILabel()
        historyTitle.text = "Recent Usage"
        historyTitle.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        historyTitle.textColor = DesignTokens.Colors.textPrimary
        historyStack.addArrangedSubview(historyTitle)

        let usageEntries = [
            ("Today", "\(quota.dailyUsed) requests"),
            ("Yesterday", "8 requests"),
            ("2 days ago", "5 requests"),
            ("3 days ago", "10 requests"),
            ("4 days ago", "3 requests"),
        ]

        for (day, count) in usageEntries {
            let row = UIStackView()
            row.axis = .horizontal

            let dayLabel = UILabel()
            dayLabel.text = day
            dayLabel.font = DesignTokens.Typography.subheadline
            dayLabel.textColor = DesignTokens.Colors.textPrimary

            let countLbl = UILabel()
            countLbl.text = count
            countLbl.font = DesignTokens.Typography.subheadline
            countLbl.textColor = DesignTokens.Colors.textSecondary
            countLbl.textAlignment = .right

            row.addArrangedSubview(dayLabel)
            row.addArrangedSubview(countLbl)
            historyStack.addArrangedSubview(row)
        }

        contentStack.addArrangedSubview(historyCard)

        // Upgrade prompt (for free users)
        if plan == .free {
            let upgradeCard = UIView()
            upgradeCard.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.1)
            upgradeCard.layer.cornerRadius = DesignTokens.Radii.lg
            upgradeCard.layer.borderWidth = 1
            upgradeCard.layer.borderColor = DesignTokens.Colors.accent.withAlphaComponent(0.3).cgColor

            let upgradeStack = UIStackView()
            upgradeStack.axis = .vertical
            upgradeStack.spacing = DesignTokens.Spacing.md
            upgradeStack.alignment = .center
            upgradeStack.translatesAutoresizingMaskIntoConstraints = false
            upgradeCard.addSubview(upgradeStack)

            NSLayoutConstraint.activate([
                upgradeStack.topAnchor.constraint(equalTo: upgradeCard.topAnchor, constant: cardPadding),
                upgradeStack.leadingAnchor.constraint(equalTo: upgradeCard.leadingAnchor, constant: cardPadding),
                upgradeStack.trailingAnchor.constraint(equalTo: upgradeCard.trailingAnchor, constant: -cardPadding),
                upgradeStack.bottomAnchor.constraint(equalTo: upgradeCard.bottomAnchor, constant: -cardPadding),
            ])

            let upgradeTitle = UILabel()
            upgradeTitle.text = "Need more Prototype suggestions?"
            upgradeTitle.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
            upgradeTitle.textColor = DesignTokens.Colors.textPrimary
            upgradeTitle.textAlignment = .center

            let upgradeBody = UILabel()
            upgradeBody.text = "Upgrade to Pro for unlimited Prototype suggestions and more."
            upgradeBody.font = DesignTokens.Typography.subheadline
            upgradeBody.textColor = DesignTokens.Colors.textSecondary
            upgradeBody.textAlignment = .center
            upgradeBody.numberOfLines = 0

            let upgradeButton = UIButton(type: .system)
            var btnConfig = UIButton.Configuration.filled()
            btnConfig.title = "Upgrade to Pro"
            btnConfig.baseBackgroundColor = DesignTokens.Colors.accent
            btnConfig.baseForegroundColor = .white
            btnConfig.cornerStyle = .medium
            btnConfig.contentInsets = NSDirectionalEdgeInsets(
                top: DesignTokens.Spacing.md,
                leading: DesignTokens.Spacing.xl,
                bottom: DesignTokens.Spacing.md,
                trailing: DesignTokens.Spacing.xl
            )
            upgradeButton.configuration = btnConfig
            upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)

            upgradeStack.addArrangedSubview(upgradeTitle)
            upgradeStack.addArrangedSubview(upgradeBody)
            upgradeStack.addArrangedSubview(upgradeButton)

            contentStack.addArrangedSubview(upgradeCard)
        }
    }

    @objc private func upgradeTapped() {
        onUpgradeTapped?()
    }
}
