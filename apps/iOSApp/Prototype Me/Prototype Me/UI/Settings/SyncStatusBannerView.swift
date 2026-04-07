import UIKit

class SyncStatusBannerView: UIView {

    enum State {
        case synced
        case pending(Int)
        case error(String)
    }

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = DesignTokens.Radii.md
        clipsToBounds = true

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.font = DesignTokens.Typography.caption1
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 36),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DesignTokens.Spacing.sm),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.sm),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.sm),
        ])

        configure(state: .synced)
    }

    func configure(state: State) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)

        switch state {
        case .synced:
            backgroundColor = DesignTokens.Colors.accentSecondary.withAlphaComponent(0.12)
            iconView.image = UIImage(systemName: "checkmark.icloud", withConfiguration: iconConfig)
            iconView.tintColor = DesignTokens.Colors.accentSecondary
            label.text = "All synced"
            label.textColor = DesignTokens.Colors.accentSecondary

        case .pending(let count):
            backgroundColor = DesignTokens.Colors.warning.withAlphaComponent(0.12)
            iconView.image = UIImage(systemName: "arrow.triangle.2.circlepath.icloud", withConfiguration: iconConfig)
            iconView.tintColor = DesignTokens.Colors.warning
            label.text = count == 1 ? "1 change waiting to sync" : "\(count) changes waiting to sync"
            label.textColor = DesignTokens.Colors.warning

        case .error:
            backgroundColor = DesignTokens.Colors.destructive.withAlphaComponent(0.12)
            iconView.image = UIImage(systemName: "exclamationmark.icloud", withConfiguration: iconConfig)
            iconView.tintColor = DesignTokens.Colors.destructive
            label.text = "Sync issue — check connection"
            label.textColor = DesignTokens.Colors.destructive
        }
    }
}
