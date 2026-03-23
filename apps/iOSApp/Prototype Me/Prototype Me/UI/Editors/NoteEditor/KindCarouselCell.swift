import UIKit

final class KindCarouselCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let checkBadge = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.layer.cornerRadius = DesignTokens.Radii.xl
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .high)
        clipsToBounds = false

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        subtitleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .medium)
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary

        detailLabel.font = DesignTokens.Typography.body
        detailLabel.textColor = DesignTokens.Colors.textSecondary
        detailLabel.numberOfLines = 0

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        checkBadge.preferredSymbolConfiguration = checkConfig
        checkBadge.contentMode = .scaleAspectFit

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.sm
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        checkBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkBadge)

        let padding = DesignTokens.Spacing.xl

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            checkBadge.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            checkBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            checkBadge.widthAnchor.constraint(equalToConstant: 28),

            textStack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -padding),
        ])
    }

    func configure(icon: String, title: String, subtitle: String, detail: String, isSelected: Bool, isDisabled: Bool, kindColor: UIColor = DesignTokens.Colors.accent) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: iconConfig)
        titleLabel.text = title
        subtitleLabel.text = subtitle
        detailLabel.text = detail

        if isDisabled {
            contentView.backgroundColor = DesignTokens.Colors.surfaceSecondary
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = DesignTokens.Colors.separator.cgColor
            iconView.tintColor = DesignTokens.Colors.textTertiary
            titleLabel.textColor = DesignTokens.Colors.textTertiary
            checkBadge.image = UIImage(systemName: "lock.fill")
            checkBadge.tintColor = DesignTokens.Colors.textTertiary
        } else if isSelected {
            contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
            animateBorder(width: 2, color: kindColor.cgColor)
            iconView.tintColor = kindColor
            titleLabel.textColor = DesignTokens.Colors.textPrimary
            crossfadeCheckBadge(systemName: "checkmark.circle.fill", color: kindColor)
        } else {
            contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
            animateBorder(width: 1, color: DesignTokens.Colors.separator.cgColor)
            iconView.tintColor = kindColor.withAlphaComponent(0.5)
            titleLabel.textColor = DesignTokens.Colors.textPrimary
            crossfadeCheckBadge(systemName: "circle", color: DesignTokens.Colors.textTertiary)
        }
    }

    private func animateBorder(width: CGFloat, color: CGColor) {
        let colorAnim = CABasicAnimation(keyPath: "borderColor")
        colorAnim.fromValue = contentView.layer.borderColor
        colorAnim.toValue = color
        colorAnim.duration = 0.25

        let widthAnim = CABasicAnimation(keyPath: "borderWidth")
        widthAnim.fromValue = contentView.layer.borderWidth
        widthAnim.toValue = width
        widthAnim.duration = 0.25

        contentView.layer.add(colorAnim, forKey: "borderColor")
        contentView.layer.add(widthAnim, forKey: "borderWidth")
        contentView.layer.borderColor = color
        contentView.layer.borderWidth = width
    }

    private func crossfadeCheckBadge(systemName: String, color: UIColor) {
        UIView.transition(with: checkBadge, duration: 0.25, options: .transitionCrossDissolve) {
            self.checkBadge.image = UIImage(systemName: systemName)
            self.checkBadge.tintColor = color
        }
    }
}
