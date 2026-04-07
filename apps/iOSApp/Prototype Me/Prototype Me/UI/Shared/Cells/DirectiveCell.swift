import UIKit

/// Collection view cell for displaying a Directive in list views.
final class DirectiveCell: InteractiveCell {

    static let reuseID = "DirectiveCell"

    private let colorBar = UIView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let balloonIcon = UIImageView()
    private let scheduleIcon = UIImageView()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.md
        contentView.clipsToBounds = true

        colorBar.translatesAutoresizingMaskIntoConstraints = false
        colorBar.isHidden = true

        titleLabel.font = DesignTokens.Typography.headline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 2

        balloonIcon.image = UIImage(systemName: "balloon.fill")
        balloonIcon.contentMode = .scaleAspectFit
        balloonIcon.setContentHuggingPriority(.required, for: .horizontal)

        scheduleIcon.image = UIImage(systemName: "calendar.badge.clock")
        scheduleIcon.tintColor = DesignTokens.Colors.accent
        scheduleIcon.contentMode = .scaleAspectFit

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        // Title row: title [balloon icon] [schedule icon] chevron
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, balloonIcon, scheduleIcon, chevron])
        titleRow.axis = .horizontal
        titleRow.spacing = DesignTokens.Spacing.sm
        titleRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleRow, bodyLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.xs
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(colorBar)
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            colorBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            colorBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            colorBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            colorBar.widthAnchor.constraint(equalToConstant: 4),
            balloonIcon.widthAnchor.constraint(equalToConstant: 18),
            balloonIcon.heightAnchor.constraint(equalToConstant: 18),
            scheduleIcon.widthAnchor.constraint(equalToConstant: 16),
            scheduleIcon.heightAnchor.constraint(equalToConstant: 16),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with data: DirectiveRowData) {
        titleLabel.text = data.directive.title
        bodyLabel.text = data.directive.body
        bodyLabel.isHidden = data.directive.body == nil

        if let hex = data.directive.color, let color = UIColor(hex: hex) {
            colorBar.backgroundColor = color
            colorBar.isHidden = false
        } else {
            colorBar.isHidden = true
        }

        if let level = data.pressureLevel {
            balloonIcon.tintColor = balloonTint(for: level)
            balloonIcon.isHidden = false
            let isExpired = data.directive.balloonEnabled && data.directive.liveRemainingSec == 0
            setBalloonPulsing(isExpired)
        } else {
            balloonIcon.isHidden = true
            setBalloonPulsing(false)
        }

        scheduleIcon.isHidden = !data.scheduledToday
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setBalloonPulsing(false)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // CAAnimations are stripped when the view leaves its window (tab switch,
        // background). Re-apply when we come back if we're supposed to be pulsing.
        if window != nil, isPulsing {
            applyPulseAnimation()
        }
    }

    private static let pulseKey = "expiredPulse"
    private var isPulsing = false

    private func setBalloonPulsing(_ active: Bool) {
        isPulsing = active
        if active {
            applyPulseAnimation()
        } else {
            balloonIcon.layer.removeAnimation(forKey: Self.pulseKey)
        }
    }

    private func applyPulseAnimation() {
        guard balloonIcon.layer.animation(forKey: Self.pulseKey) == nil else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.18
        scale.duration = 0.6
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        balloonIcon.layer.add(scale, forKey: Self.pulseKey)
    }

    private func balloonTint(for level: PressureLevel) -> UIColor {
        switch level {
        case .green:  return DesignTokens.Colors.success
        case .yellow: return DesignTokens.Colors.warning
        case .red:    return DesignTokens.Colors.destructive
        }
    }
}
