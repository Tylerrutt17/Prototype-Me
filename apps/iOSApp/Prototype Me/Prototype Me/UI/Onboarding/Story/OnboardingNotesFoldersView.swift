import UIKit

/// Notes & Folders demo: Mock folder and note cells staggering in.
final class OnboardingNotesFoldersView: UIView, StoryAnimatable {

    private var rows: [UIView] = []
    private var hasBuilt = false

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBuilt && bounds.width > 0 {
            hasBuilt = true
            buildVisual()
        }
    }

    private func buildVisual() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.md),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.md),
        ])

        // Folders
        let folders: [(name: String, count: Int)] = [
            ("Health & Fitness", 4),
            ("Work", 6),
        ]

        for folder in folders {
            let row = makeFolderRow(name: folder.name, count: folder.count)
            stack.addArrangedSubview(row)
            rows.append(row)
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 12)
        }

        // Notes
        let notes: [(title: String, subtitle: String, kind: NoteKind)] = [
            ("Morning routine ideas", "Regular · Health & Fitness", .regular),
            ("Deep Work mode", "Situational Mode · 3 directives", .mode),
            ("Weekly review", "Regular · Work", .regular),
        ]

        for note in notes {
            let row = makeNoteRow(title: note.title, subtitle: note.subtitle, kind: note.kind)
            stack.addArrangedSubview(row)
            rows.append(row)
            row.alpha = 0
            row.transform = CGAffineTransform(translationX: 0, y: 12)
        }
    }

    private func makeFolderRow(name: String, count: Int) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: "folder.fill", withConfiguration: iconConfig))
        icon.tintColor = DesignTokens.Colors.accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = name
        label.font = DesignTokens.Typography.rounded(style: .body, weight: .semibold)
        label.textColor = DesignTokens.Colors.textPrimary

        let countLabel = UILabel()
        countLabel.text = "\(count)"
        countLabel.font = DesignTokens.Typography.caption1
        countLabel.textColor = DesignTokens.Colors.textTertiary
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true

        let row = UIStackView(arrangedSubviews: [icon, label, UIView(), countLabel, chevron])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return card
    }

    private func makeNoteRow(title: String, subtitle: String, kind: NoteKind) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: kind.iconName, withConfiguration: iconConfig))
        icon.tintColor = kind.color
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = DesignTokens.Typography.caption1
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = DesignTokens.Colors.textTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true

        let row = UIStackView(arrangedSubviews: [icon, textStack, UIView(), chevron])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.md
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return card
    }

    // MARK: - StoryAnimatable

    func playEntrance() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            for row in rows { row.alpha = 1; row.transform = .identity }
            return
        }

        for (i, row) in rows.enumerated() {
            UIView.animate(
                withDuration: 0.4,
                delay: 0.15 + Double(i) * 0.1,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3
            ) {
                row.alpha = 1
                row.transform = .identity
            }
        }
    }

    func stopAnimations() {
        for row in rows { row.layer.removeAllAnimations() }
    }
}
