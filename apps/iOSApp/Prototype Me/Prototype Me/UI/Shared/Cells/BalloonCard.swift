import UIKit

/// Card-style cell showing a balloon directive with pressure + countdown + pump button.
final class BalloonCard: UICollectionViewCell {

    static let reuseID = "BalloonCard"

    private let titleLabel = UILabel()
    private let pressureIndicator = PressureIndicator()
    private let timerLabel = UILabel()
    private let pumpButton = UIButton(type: .system)

    var onPump: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .medium)

        titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 2

        pressureIndicator.size = 20

        timerLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        timerLabel.textColor = DesignTokens.Colors.textPrimary
        timerLabel.textAlignment = .center

        var config = UIButton.Configuration.filled()
        config.title = "Pump"
        config.image = UIImage(systemName: "arrow.clockwise")
        config.imagePadding = DesignTokens.Spacing.xs
        config.cornerStyle = .capsule
        config.baseBackgroundColor = DesignTokens.Colors.accent
        config.baseForegroundColor = DesignTokens.Colors.textPrimary
        config.contentInsets = NSDirectionalEdgeInsets(
            top: DesignTokens.Spacing.sm,
            leading: DesignTokens.Spacing.lg,
            bottom: DesignTokens.Spacing.sm,
            trailing: DesignTokens.Spacing.lg
        )
        pumpButton.configuration = config
        pumpButton.addTarget(self, action: #selector(pumpTapped), for: .touchUpInside)

        // Top row: pressure dot + title
        let topRow = UIStackView(arrangedSubviews: [pressureIndicator, titleLabel])
        topRow.axis = .horizontal
        topRow.spacing = DesignTokens.Spacing.sm
        topRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topRow, timerLabel, pumpButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            pressureIndicator.widthAnchor.constraint(equalToConstant: 20),
            pressureIndicator.heightAnchor.constraint(equalToConstant: 20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.lg),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with data: DirectiveRowData) {
        titleLabel.text = data.directive.title
        pressureIndicator.configure(level: data.pressureLevel)
        timerLabel.text = formatTime(data.directive.balloonRemainingSec)

        // Tint timer by pressure
        if let level = data.pressureLevel {
            switch level {
            case .green:  timerLabel.textColor = DesignTokens.Colors.success
            case .yellow: timerLabel.textColor = DesignTokens.Colors.warning
            case .red:    timerLabel.textColor = DesignTokens.Colors.destructive
            }
        }
    }

    @objc private func pumpTapped() {
        onPump?()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
