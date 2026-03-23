import UIKit

/// Profile screen for self or a friend. Shows avatar, name, bio, mood chips, and plan badge.
class ProfileViewController: BaseViewController {

    var profile: UserProfile?
    var isSelf: Bool = true
    var onEditTapped: (() -> Void)?
    var onUpgradeTapped: (() -> Void)?
    var onFriendsTapped: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        let displayProfile = profile ?? SampleData.currentUserProfile
        navBar.setTitle(isSelf ? "Profile" : displayProfile.displayName, animated: false)

        if isSelf {
            navBar.setRightButtons([
                NavBarButton(systemImage: "pencil") { [weak self] in self?.onEditTapped?() }
            ])
        }

        configureLayout()
        buildContent(displayProfile)
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

    // MARK: - Content

    private func buildContent(_ profile: UserProfile) {
        // Avatar + Name header
        let headerCard = UIView()
        headerCard.backgroundColor = DesignTokens.Colors.surfacePrimary
        headerCard.layer.cornerRadius = DesignTokens.Radii.lg

        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = DesignTokens.Spacing.md
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerCard.addSubview(headerStack)

        let cardPadding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: cardPadding),
            headerStack.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: cardPadding),
            headerStack.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -cardPadding),
            headerStack.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -cardPadding),
        ])

        // Avatar
        let avatarConfig = UIImage.SymbolConfiguration(pointSize: 72, weight: .ultraLight)
        let avatarView = UIImageView(image: UIImage(systemName: profile.avatarSystemImage, withConfiguration: avatarConfig))
        avatarView.tintColor = DesignTokens.Colors.accent
        avatarView.contentMode = .scaleAspectFit
        headerStack.addArrangedSubview(avatarView)

        // Name
        let nameLabel = UILabel()
        nameLabel.text = profile.displayName
        nameLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        nameLabel.textColor = DesignTokens.Colors.textPrimary
        nameLabel.textAlignment = .center
        headerStack.addArrangedSubview(nameLabel)

        // Plan badge
        let badgeLabel = UILabel()
        badgeLabel.text = profile.plan == .pro ? "  PRO  " : "  FREE  "
        badgeLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
        badgeLabel.textColor = profile.plan == .pro ? DesignTokens.Colors.accentTertiary : DesignTokens.Colors.textTertiary
        badgeLabel.backgroundColor = profile.plan == .pro
            ? DesignTokens.Colors.accentTertiary.withAlphaComponent(0.15)
            : DesignTokens.Colors.surfaceSecondary
        badgeLabel.layer.cornerRadius = DesignTokens.Radii.sm
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        headerStack.addArrangedSubview(badgeLabel)

        // Joined date
        let joinedLabel = UILabel()
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        joinedLabel.text = "Joined \(fmt.string(from: profile.joinedAt))"
        joinedLabel.font = DesignTokens.Typography.footnote
        joinedLabel.textColor = DesignTokens.Colors.textTertiary
        joinedLabel.textAlignment = .center
        headerStack.addArrangedSubview(joinedLabel)

        contentStack.addArrangedSubview(headerCard)

        // Bio section
        if let bio = profile.bio, !bio.isEmpty {
            let bioCard = UIView()
            bioCard.backgroundColor = DesignTokens.Colors.surfacePrimary
            bioCard.layer.cornerRadius = DesignTokens.Radii.lg

            let bioStack = UIStackView()
            bioStack.axis = .vertical
            bioStack.spacing = DesignTokens.Spacing.sm
            bioStack.translatesAutoresizingMaskIntoConstraints = false
            bioCard.addSubview(bioStack)

            NSLayoutConstraint.activate([
                bioStack.topAnchor.constraint(equalTo: bioCard.topAnchor, constant: DesignTokens.Spacing.lg),
                bioStack.leadingAnchor.constraint(equalTo: bioCard.leadingAnchor, constant: DesignTokens.Spacing.lg),
                bioStack.trailingAnchor.constraint(equalTo: bioCard.trailingAnchor, constant: -DesignTokens.Spacing.lg),
                bioStack.bottomAnchor.constraint(equalTo: bioCard.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            ])

            let bioTitle = UILabel()
            bioTitle.text = "About"
            bioTitle.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            bioTitle.textColor = DesignTokens.Colors.textTertiary

            let bioLabel = UILabel()
            bioLabel.text = bio
            bioLabel.font = DesignTokens.Typography.body
            bioLabel.textColor = DesignTokens.Colors.textPrimary
            bioLabel.numberOfLines = 0

            bioStack.addArrangedSubview(bioTitle)
            bioStack.addArrangedSubview(bioLabel)

            contentStack.addArrangedSubview(bioCard)
        }

        // Mood chips
        if !profile.moodChips.isEmpty {
            let moodCard = UIView()
            moodCard.backgroundColor = DesignTokens.Colors.surfacePrimary
            moodCard.layer.cornerRadius = DesignTokens.Radii.lg

            let moodStack = UIStackView()
            moodStack.axis = .vertical
            moodStack.spacing = DesignTokens.Spacing.md
            moodStack.translatesAutoresizingMaskIntoConstraints = false
            moodCard.addSubview(moodStack)

            NSLayoutConstraint.activate([
                moodStack.topAnchor.constraint(equalTo: moodCard.topAnchor, constant: DesignTokens.Spacing.lg),
                moodStack.leadingAnchor.constraint(equalTo: moodCard.leadingAnchor, constant: DesignTokens.Spacing.lg),
                moodStack.trailingAnchor.constraint(equalTo: moodCard.trailingAnchor, constant: -DesignTokens.Spacing.lg),
                moodStack.bottomAnchor.constraint(equalTo: moodCard.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            ])

            let moodTitle = UILabel()
            moodTitle.text = "Current Mood"
            moodTitle.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold)
            moodTitle.textColor = DesignTokens.Colors.textTertiary
            moodStack.addArrangedSubview(moodTitle)

            let chipFlow = UIStackView()
            chipFlow.axis = .horizontal
            chipFlow.spacing = DesignTokens.Spacing.sm
            chipFlow.distribution = .fillProportionally

            for chip in profile.moodChips {
                let chipView = makeMoodChip(chip)
                chipFlow.addArrangedSubview(chipView)
            }
            // Spacer
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            chipFlow.addArrangedSubview(spacer)

            moodStack.addArrangedSubview(chipFlow)

            contentStack.addArrangedSubview(moodCard)
        }

        // Actions
        if isSelf {
            let actionsStack = UIStackView()
            actionsStack.axis = .vertical
            actionsStack.spacing = DesignTokens.Spacing.md

            let friendsButton = makeActionRow(icon: "person.2", title: "Friends", hasDisclosure: true)
            friendsButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(friendsTapped)))
            actionsStack.addArrangedSubview(friendsButton)

            if profile.plan == .free {
                let upgradeButton = makeActionRow(icon: "crown", title: "Upgrade to Pro", hasDisclosure: true, tintColor: DesignTokens.Colors.accentTertiary)
                upgradeButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(upgradeTapped)))
                actionsStack.addArrangedSubview(upgradeButton)
            }

            contentStack.addArrangedSubview(actionsStack)
        }
    }

    private func makeMoodChip(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        label.textColor = DesignTokens.Colors.accentSecondary
        label.textAlignment = .center

        let container = UIView()
        container.backgroundColor = DesignTokens.Colors.accentSecondary.withAlphaComponent(0.12)
        container.layer.cornerRadius = DesignTokens.Radii.pill
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.sm),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: DesignTokens.Spacing.lg),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return container
    }

    private func makeActionRow(icon: String, title: String, hasDisclosure: Bool, tintColor: UIColor = DesignTokens.Colors.accent) -> UIView {
        let card = UIView()
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.isUserInteractionEnabled = true

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = DesignTokens.Spacing.md
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = tintColor
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let label = UILabel()
        label.text = title
        label.font = DesignTokens.Typography.body
        label.textColor = DesignTokens.Colors.textPrimary

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(label)

        if hasDisclosure {
            let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
            chevron.tintColor = DesignTokens.Colors.textTertiary
            row.addArrangedSubview(chevron)
        }

        let padding = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: padding),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: padding),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -padding),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -padding),
        ])

        return card
    }

    @objc private func friendsTapped() { onFriendsTapped?() }
    @objc private func upgradeTapped() { onUpgradeTapped?() }
}
