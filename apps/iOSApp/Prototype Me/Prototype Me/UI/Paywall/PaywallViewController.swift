import UIKit
import RevenueCat

/// Full-screen paywall with feature comparison and upgrade CTA.
/// Presented modally from Settings, usage limit, or any upgrade prompt.
class PaywallViewController: BaseViewController {

    var purchaseService: PurchaseService?
    var onDismiss: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    private let features = SampleData.paywallFeatures

    // RevenueCat data
    private var currentOffering: Offering?
    private var monthlyPackage: Package?
    private var yearlyPackage: Package?
    private var selectedPackage: Package?

    // CTA elements (need references for updates)
    private var priceLabel: UILabel?
    private var periodLabel: UILabel?
    private var subscribeButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.setTitle("Upgrade to Pro", animated: false)
        navBar.setLeftButton(title: "Close", systemImage: nil) { [weak self] in
            self?.onDismiss?()
        }

        configureLayout()
        buildHero()
        buildFeatureTable()
        buildCTA()
        buildRestoreLink()
        fetchOfferings()
    }

    // MARK: - Fetch Offerings

    private func fetchOfferings() {
        subscribeButton?.isEnabled = false
        subscribeButton?.alpha = 0.5
        priceLabel?.text = "Loading..."

        Task {
            do {
                let offerings = try await purchaseService?.fetchOfferings()
                await MainActor.run {
                    if let offering = offerings?.offering(identifier: "Pro Monthly") ?? offerings?.current {
                        self.currentOffering = offering
                        self.monthlyPackage = offering.monthly
                        self.yearlyPackage = offering.annual
                        self.selectedPackage = offering.monthly ?? offering.availablePackages.first
                        self.updatePriceDisplay()
                        self.subscribeButton?.isEnabled = true
                        self.subscribeButton?.alpha = 1
                    } else {
                        self.priceLabel?.text = "No plans available"
                    }
                }
            } catch {
                await MainActor.run {
                    self.priceLabel?.text = "Couldn't load prices"
                }
            }
        }
    }

    private func updatePriceDisplay() {
        guard let pkg = selectedPackage else { return }
        priceLabel?.text = pkg.localizedPriceString + " / " + pkg.packageType.periodLabel
        periodLabel?.text = "Cancel anytime."
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

    // MARK: - Hero

    private func buildHero() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)
        let iconView = UIImageView(image: UIImage(systemName: "crown.fill", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.accentTertiary
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "Unlock Your Full Potential"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title1, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Unlimited Speak, voice talk, journal summaries, and more."
        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        let heroStack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel])
        heroStack.axis = .vertical
        heroStack.spacing = DesignTokens.Spacing.md
        heroStack.alignment = .center

        contentStack.addArrangedSubview(heroStack)
    }

    // MARK: - Feature Table

    private func buildFeatureTable() {
        let container = UIView()
        container.backgroundColor = DesignTokens.Colors.surfacePrimary
        container.layer.cornerRadius = DesignTokens.Radii.lg

        let tableStack = UIStackView()
        tableStack.axis = .vertical
        tableStack.spacing = 0
        tableStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableStack)

        let headerRow = makeFeatureRow(title: "", freeValue: "Free", proValue: "Pro", isHeader: true)
        tableStack.addArrangedSubview(headerRow)
        tableStack.addArrangedSubview(makeSeparator())

        for (index, feature) in features.enumerated() {
            let row = makeFeatureRow(
                title: feature.title,
                freeValue: feature.freeValue,
                proValue: feature.proValue,
                isHeader: false
            )
            tableStack.addArrangedSubview(row)
            if index < features.count - 1 {
                tableStack.addArrangedSubview(makeSeparator())
            }
        }

        let padding = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            tableStack.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            tableStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            tableStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            tableStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),
        ])

        contentStack.addArrangedSubview(container)
    }

    private func makeFeatureRow(title: String, freeValue: String, proValue: String, isHeader: Bool) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = isHeader
            ? DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            : DesignTokens.Typography.subheadline
        titleLabel.textColor = isHeader ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        let freeLabel = UILabel()
        freeLabel.textAlignment = .center
        freeLabel.font = isHeader
            ? DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            : DesignTokens.Typography.subheadline
        freeLabel.textColor = isHeader ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textSecondary

        let proLabel = UILabel()
        proLabel.textAlignment = .center
        proLabel.font = isHeader
            ? DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            : DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        proLabel.textColor = isHeader ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.accent

        if freeValue == "checkmark" {
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "checkmark", withConfiguration: config)?.withTintColor(DesignTokens.Colors.textSecondary, renderingMode: .alwaysOriginal)
            freeLabel.attributedText = NSAttributedString(attachment: attachment)
        } else {
            freeLabel.text = freeValue
        }

        if proValue == "checkmark" {
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            let attachment = NSTextAttachment()
            attachment.image = UIImage(systemName: "checkmark", withConfiguration: config)?.withTintColor(DesignTokens.Colors.accent, renderingMode: .alwaysOriginal)
            proLabel.attributedText = NSAttributedString(attachment: attachment)
        } else {
            proLabel.text = proValue
        }

        let columnWidth: CGFloat = 60

        let row = UIStackView(arrangedSubviews: [titleLabel, freeLabel, proLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = DesignTokens.Spacing.sm

        NSLayoutConstraint.activate([
            freeLabel.widthAnchor.constraint(equalToConstant: columnWidth),
            proLabel.widthAnchor.constraint(equalToConstant: columnWidth),
        ])

        let wrapper = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: DesignTokens.Spacing.md),
            row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -DesignTokens.Spacing.md),
        ])

        return wrapper
    }

    private func makeSeparator() -> UIView {
        let sep = UIView()
        sep.backgroundColor = DesignTokens.Colors.separator
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return sep
    }

    // MARK: - CTA

    private func buildCTA() {
        let price = UILabel()
        price.text = "Loading..."
        price.font = DesignTokens.Typography.rounded(style: .title3, weight: .bold)
        price.textColor = DesignTokens.Colors.textPrimary
        price.textAlignment = .center
        self.priceLabel = price

        let period = UILabel()
        period.text = "Cancel anytime."
        period.font = DesignTokens.Typography.footnote
        period.textColor = DesignTokens.Colors.textSecondary
        period.textAlignment = .center
        self.periodLabel = period

        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Subscribe"
        config.baseBackgroundColor = DesignTokens.Colors.accent
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.lg,
            leading: DesignTokens.Spacing.xxl,
            bottom: DesignTokens.Spacing.lg,
            trailing: DesignTokens.Spacing.xxl
        )
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DesignTokens.Typography.rounded(style: .headline, weight: .bold)
            return outgoing
        }
        button.configuration = config
        button.addTarget(self, action: #selector(subscribeTapped), for: .touchUpInside)
        self.subscribeButton = button

        let ctaStack = UIStackView(arrangedSubviews: [price, period, button])
        ctaStack.axis = .vertical
        ctaStack.spacing = DesignTokens.Spacing.md
        ctaStack.alignment = .center

        contentStack.addArrangedSubview(ctaStack)
    }

    // MARK: - Restore

    private func buildRestoreLink() {
        let restoreButton = UIButton(type: .system)
        restoreButton.setTitle("Restore purchases", for: .normal)
        restoreButton.titleLabel?.font = DesignTokens.Typography.footnote
        restoreButton.setTitleColor(DesignTokens.Colors.textSecondary, for: .normal)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        let termsButton = UIButton(type: .system)
        termsButton.setTitle("Terms of Service", for: .normal)
        termsButton.titleLabel?.font = DesignTokens.Typography.caption2
        termsButton.setTitleColor(DesignTokens.Colors.textTertiary, for: .normal)

        let privacyButton = UIButton(type: .system)
        privacyButton.setTitle("Privacy Policy", for: .normal)
        privacyButton.titleLabel?.font = DesignTokens.Typography.caption2
        privacyButton.setTitleColor(DesignTokens.Colors.textTertiary, for: .normal)

        let legalStack = UIStackView(arrangedSubviews: [termsButton, privacyButton])
        legalStack.axis = .horizontal
        legalStack.spacing = DesignTokens.Spacing.lg

        let bottomStack = UIStackView(arrangedSubviews: [restoreButton, legalStack])
        bottomStack.axis = .vertical
        bottomStack.spacing = DesignTokens.Spacing.sm
        bottomStack.alignment = .center

        contentStack.addArrangedSubview(bottomStack)
    }

    // MARK: - Actions

    @objc private func subscribeTapped() {
        guard let package = selectedPackage else { return }

        subscribeButton?.isEnabled = false
        subscribeButton?.configuration?.title = "Processing..."

        Task {
            do {
                let result = try await purchaseService?.purchase(package: package)
                if result?.userCancelled == true {
                    await MainActor.run {
                        self.subscribeButton?.isEnabled = true
                        self.subscribeButton?.configuration?.title = "Subscribe"
                    }
                    return
                }

                // Sync plan with backend
                await purchaseService?.syncPlanWithBackend()

                await MainActor.run {
                    Haptics.success()
                    self.onDismiss?()
                }
            } catch {
                await MainActor.run {
                    Haptics.error()
                    self.subscribeButton?.isEnabled = true
                    self.subscribeButton?.configuration?.title = "Subscribe"
                    let alert = UIAlertController(title: "Purchase Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    @objc private func restoreTapped() {
        Task {
            do {
                _ = try await purchaseService?.restorePurchases()
                let isPro = try await purchaseService?.isPro() ?? false
                await purchaseService?.syncPlanWithBackend()

                await MainActor.run {
                    if isPro {
                        Haptics.success()
                        let alert = UIAlertController(title: "Restored!", message: "Your Pro subscription has been restored.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                            self?.onDismiss?()
                        })
                        self.present(alert, animated: true)
                    } else {
                        let alert = UIAlertController(title: "No Subscription Found", message: "We couldn't find an active subscription for this account.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    Haptics.error()
                    let alert = UIAlertController(title: "Restore Failed", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

// MARK: - PackageType Period Label

private extension PackageType {
    var periodLabel: String {
        switch self {
        case .monthly: return "month"
        case .annual: return "year"
        case .weekly: return "week"
        case .lifetime: return "lifetime"
        default: return "period"
        }
    }
}
