import UIKit

/// Collection view cell for displaying a NotePage in list views.
final class NoteCell: UICollectionViewCell {

    static let reuseID = "NoteCell"

    private let kindIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tierLabel = TierLabel()
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

        kindIcon.tintColor = DesignTokens.Colors.textSecondary
        kindIcon.contentMode = .scaleAspectFit
        kindIcon.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = DesignTokens.Typography.headline
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 1

        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.numberOfLines = 1

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xxs

        let mainStack = UIStackView(arrangedSubviews: [kindIcon, textStack, tierLabel, chevron])
        mainStack.axis = .horizontal
        mainStack.spacing = DesignTokens.Spacing.md
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            kindIcon.widthAnchor.constraint(equalToConstant: 24),
            kindIcon.heightAnchor.constraint(equalToConstant: 24),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])
    }

    func configure(with item: NoteListItem) {
        titleLabel.text = item.note.title
        tierLabel.configure(tier: item.note.tier)

        // Kind icon
        let iconName: String = switch item.note.kind {
        case .mode:      "bolt.fill"
        case .framework: "star.fill"
        case .regular:   "doc.text"
        }
        kindIcon.image = UIImage(systemName: iconName)

        // Subtitle
        var parts: [String] = []
        if item.directiveCount > 0 {
            parts.append("\(item.directiveCount) directive\(item.directiveCount == 1 ? "" : "s")")
        }
        if let folder = item.folderName {
            parts.append(folder)
        }
        subtitleLabel.text = parts.isEmpty ? item.note.kind.rawValue.capitalized : parts.joined(separator: " · ")
    }
}
