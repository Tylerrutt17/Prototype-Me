import UIKit
import UserNotifications

/// Card-style section for enabling/configuring a balloon countdown timer on a directive.
final class BalloonEditorSection: UIView {

    var onToggleChanged: ((Bool) -> Void)?
    var onDurationChanged: ((Double) -> Void)?

    private let toggle = UISwitch()
    private let durationLabel = UILabel()
    private let durationStepper = UIStepper()
    private let detailStack = UIStackView()
    private let debugToggle = UISwitch()
    private var debugMode = false
    private let notifBanner = UIView()
    private let notifLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.clipsToBounds = true
        card.layer.borderWidth = 1
        card.layer.borderColor = DesignTokens.Colors.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        // Section title
        let sectionLabel = UILabel()
        sectionLabel.text = "BALLOON / TIMER"
        sectionLabel.font = DesignTokens.Typography.caption1
        sectionLabel.textColor = DesignTokens.Colors.textSecondary
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sectionLabel)

        // Header row: icon + title + toggle
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: "timer", withConfiguration: iconConfig))
        iconView.tintColor = DesignTokens.Colors.warning
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = "Enable Balloon / Timer"
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        toggle.isOn = false
        toggle.onTintColor = DesignTokens.Colors.accent
        toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLabel, UIView(), toggle])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.md
        headerRow.alignment = .center

        // Description
        let descLabel = UILabel()
        descLabel.text = "Keep this directive top of mind. A balloon floats in your sky and slowly sinks as time passes. You'll get a push notification when it's running low — pump it to reset. The purpose: keep the directive in your mind."
        descLabel.font = DesignTokens.Typography.caption1
        descLabel.textColor = DesignTokens.Colors.textSecondary
        descLabel.numberOfLines = 0

        // Duration controls (hidden when off)
        let durationTitle = UILabel()
        durationTitle.text = "DURATION"
        durationTitle.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        durationTitle.textColor = DesignTokens.Colors.textTertiary

        durationLabel.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        durationLabel.textColor = DesignTokens.Colors.textPrimary
        durationLabel.text = "24 hours"

        durationStepper.minimumValue = 1
        durationStepper.maximumValue = 720
        durationStepper.stepValue = 1
        durationStepper.value = 24
        durationStepper.addTarget(self, action: #selector(durationChanged), for: .valueChanged)

        let durationRow = UIStackView(arrangedSubviews: [durationLabel, UIView(), durationStepper])
        durationRow.axis = .horizontal
        durationRow.alignment = .center

        // Debug: override duration to 1 minute
        let debugLabel = UILabel()
        debugLabel.text = "DEBUG: 1 min duration"
        debugLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        debugLabel.textColor = DesignTokens.Colors.warning

        debugToggle.isOn = false
        debugToggle.onTintColor = DesignTokens.Colors.warning
        debugToggle.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        debugToggle.addTarget(self, action: #selector(debugToggled), for: .valueChanged)

        let debugRow = UIStackView(arrangedSubviews: [debugLabel, UIView(), debugToggle])
        debugRow.axis = .horizontal
        debugRow.alignment = .center

        // Notification permission banner (hidden by default)
        notifBanner.backgroundColor = DesignTokens.Colors.warning.withAlphaComponent(0.12)
        notifBanner.layer.cornerRadius = DesignTokens.Radii.md
        notifBanner.isHidden = true

        let warningIcon = UIImageView(image: UIImage(systemName: "bell.slash.fill"))
        warningIcon.tintColor = DesignTokens.Colors.warning
        warningIcon.contentMode = .scaleAspectFit
        warningIcon.translatesAutoresizingMaskIntoConstraints = false
        warningIcon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        warningIcon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        notifLabel.text = "Notifications are disabled. Tap here to enable them in Settings so you get reminded when balloons expire."
        notifLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .medium)
        notifLabel.textColor = DesignTokens.Colors.warning
        notifLabel.numberOfLines = 0

        let notifStack = UIStackView(arrangedSubviews: [warningIcon, notifLabel])
        notifStack.axis = .horizontal
        notifStack.spacing = DesignTokens.Spacing.sm
        notifStack.alignment = .top
        notifStack.translatesAutoresizingMaskIntoConstraints = false
        notifBanner.addSubview(notifStack)

        let bannerPad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            notifStack.topAnchor.constraint(equalTo: notifBanner.topAnchor, constant: bannerPad),
            notifStack.bottomAnchor.constraint(equalTo: notifBanner.bottomAnchor, constant: -bannerPad),
            notifStack.leadingAnchor.constraint(equalTo: notifBanner.leadingAnchor, constant: bannerPad),
            notifStack.trailingAnchor.constraint(equalTo: notifBanner.trailingAnchor, constant: -bannerPad),
        ])

        let bannerTap = UITapGestureRecognizer(target: self, action: #selector(openSettings))
        notifBanner.addGestureRecognizer(bannerTap)

        detailStack.axis = .vertical
        detailStack.spacing = DesignTokens.Spacing.sm
        detailStack.addArrangedSubview(notifBanner)
        detailStack.addArrangedSubview(durationTitle)
        detailStack.addArrangedSubview(durationRow)
        detailStack.addArrangedSubview(debugRow)
        detailStack.isHidden = true

        // Main stack
        let mainStack = UIStackView(arrangedSubviews: [headerRow, descLabel, detailStack])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(mainStack)

        let padding = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            card.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: padding),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -padding),
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: padding),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -padding),
        ])
    }

    @objc private func toggled() {
        let isOn = toggle.isOn
        UIView.animate(withDuration: 0.25) {
            self.detailStack.isHidden = !isOn
            self.detailStack.alpha = isOn ? 1 : 0
        }
        onToggleChanged?(isOn)
        Haptics.selection()

        if isOn { checkNotificationPermission() }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let denied = settings.authorizationStatus == .denied
                UIView.animate(withDuration: 0.25) {
                    self.notifBanner.isHidden = !denied
                }
            }
        }
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func debugToggled() {
        debugMode = debugToggle.isOn
        if debugMode {
            durationLabel.text = "1 minute (debug)"
            durationLabel.textColor = DesignTokens.Colors.warning
            durationStepper.isEnabled = false
            onDurationChanged?(1.0 / 60.0)  // 1 minute in hours
        } else {
            durationStepper.isEnabled = true
            durationLabel.textColor = DesignTokens.Colors.textPrimary
            updateDurationLabel(durationStepper.value)
            onDurationChanged?(durationStepper.value)
        }
        Haptics.selection()
    }

    @objc private func durationChanged() {
        let hours = durationStepper.value
        // Adjust step size: 1h under 48h, 24h above
        durationStepper.stepValue = hours >= 48 ? 24 : 1
        updateDurationLabel(hours)
        onDurationChanged?(hours)
    }

    private func updateDurationLabel(_ hours: Double) {
        let totalHours = Int(hours)
        let days = totalHours / 24
        let remaining = totalHours % 24

        if days == 0 {
            durationLabel.text = "\(totalHours) hour\(totalHours == 1 ? "" : "s")"
        } else if remaining == 0 {
            durationLabel.text = "\(days) day\(days == 1 ? "" : "s")"
        } else {
            durationLabel.text = "\(days)d \(remaining)h"
        }
    }

    func configure(isEnabled: Bool, durationHours: Double) {
        toggle.isOn = isEnabled
        durationStepper.value = durationHours
        detailStack.isHidden = !isEnabled
        detailStack.alpha = isEnabled ? 1 : 0
        updateDurationLabel(durationHours)

        if isEnabled { checkNotificationPermission() }
    }
}
