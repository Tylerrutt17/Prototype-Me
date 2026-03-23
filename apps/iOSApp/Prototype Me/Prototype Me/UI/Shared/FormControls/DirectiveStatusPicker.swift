import UIKit

/// Card-style picker for Active / Archived directive status.
final class DirectiveStatusPicker: UIView {

    var onStatusChanged: ((DirectiveStatus) -> Void)?

    private var selectedStatus: DirectiveStatus = .active
    private var activeCard: UIView!
    private var archivedCard: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        let titleLabel = UILabel()
        titleLabel.text = "STATUS"
        titleLabel.font = DesignTokens.Typography.caption1
        titleLabel.textColor = DesignTokens.Colors.textSecondary

        activeCard = makeCard(
            icon: "bolt.fill",
            title: "Active",
            description: "Shows in Focus, balloons tick, schedule runs.",
            color: DesignTokens.Colors.success
        )
        activeCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(activeTapped)))

        archivedCard = makeCard(
            icon: "archivebox.fill",
            title: "Archived",
            description: "Hidden from Focus and balloons. Kept for history.",
            color: DesignTokens.Colors.textTertiary
        )
        archivedCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(archivedTapped)))

        let cardsRow = UIStackView(arrangedSubviews: [activeCard, archivedCard])
        cardsRow.axis = .horizontal
        cardsRow.spacing = DesignTokens.Spacing.md
        cardsRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [titleLabel, cardsRow])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        updateAppearance()
    }

    private func makeCard(icon: String, title: String, description: String, color: UIColor) -> UIView {
        let card = UIView()
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.clipsToBounds = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.tag = 10

        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = DesignTokens.Typography.caption1
        descLabel.textColor = DesignTokens.Colors.textSecondary
        descLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let mainStack = UIStackView(arrangedSubviews: [iconView, textStack])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.sm
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.isUserInteractionEnabled = false
        card.addSubview(mainStack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            mainStack.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            mainStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return card
    }

    @objc private func activeTapped() {
        selectedStatus = .active
        onStatusChanged?(.active)
        UIView.animate(withDuration: 0.2) { self.updateAppearance() }
        Haptics.selection()
    }

    @objc private func archivedTapped() {
        selectedStatus = .archived
        onStatusChanged?(.archived)
        UIView.animate(withDuration: 0.2) { self.updateAppearance() }
        Haptics.selection()
    }

    func setStatus(_ status: DirectiveStatus) {
        selectedStatus = status
        updateAppearance()
    }

    private func updateAppearance() {
        let isActive = selectedStatus == .active

        activeCard.backgroundColor = isActive
            ? DesignTokens.Colors.success.withAlphaComponent(0.1)
            : DesignTokens.Colors.surfaceSecondary
        activeCard.layer.borderWidth = isActive ? 2 : 1
        activeCard.layer.borderColor = isActive
            ? DesignTokens.Colors.success.cgColor
            : DesignTokens.Colors.separator.cgColor

        archivedCard.backgroundColor = !isActive
            ? DesignTokens.Colors.textTertiary.withAlphaComponent(0.1)
            : DesignTokens.Colors.surfaceSecondary
        archivedCard.layer.borderWidth = !isActive ? 2 : 1
        archivedCard.layer.borderColor = !isActive
            ? DesignTokens.Colors.textTertiary.cgColor
            : DesignTokens.Colors.separator.cgColor
    }
}
