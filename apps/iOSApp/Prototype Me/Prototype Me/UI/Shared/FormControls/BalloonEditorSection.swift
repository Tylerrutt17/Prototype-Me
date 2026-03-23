import UIKit

/// Card-style section for enabling/configuring a balloon countdown timer on a directive.
final class BalloonEditorSection: UIView {

    var onToggleChanged: ((Bool) -> Void)?
    var onDurationChanged: ((Double) -> Void)?

    private let toggle = UISwitch()
    private let durationLabel = UILabel()
    private let durationStepper = UIStepper()
    private let detailStack = UIStackView()

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
        sectionLabel.text = "COUNTDOWN TIMER / BALLOON"
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
        titleLabel.text = "Enable Timer"
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

        detailStack.axis = .vertical
        detailStack.spacing = DesignTokens.Spacing.sm
        detailStack.addArrangedSubview(durationTitle)
        detailStack.addArrangedSubview(durationRow)
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
    }
}
