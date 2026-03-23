import UIKit

nonisolated private enum SeedReviewSection: Sendable { case header, cards }
nonisolated private enum SeedReviewItem: Hashable, Sendable {
    case header
    case card(SeedPlanCard)
}

/// Displays seed plan cards for review before entering the main app.
final class SeedPlanReviewViewController: UIViewController {

    var cards: [SeedPlanCard] = []
    var onConfirmed: (() -> Void)?

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SeedReviewSection, SeedReviewItem>!
    private let confirmButton = AppButton(title: "Confirm & Start")
    private let bottomBar = GlassPanelView(cornerRadius: 0)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        setupCollectionView()
        setupDataSource()
        setupBottomBar()
        applySnapshot()
    }

    // MARK: - Collection View

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
        ])
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let section = sectionIndex == 0 ? SeedReviewSection.header : .cards
            switch section {
            case .header:
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: item.layoutSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: DesignTokens.Spacing.xxl, leading: DesignTokens.Spacing.xxl, bottom: DesignTokens.Spacing.lg, trailing: DesignTokens.Spacing.xxl)
                return layoutSection
            case .cards:
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(72)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: item.layoutSize, subitems: [item])
                let layoutSection = NSCollectionLayoutSection(group: group)
                layoutSection.interGroupSpacing = DesignTokens.Spacing.sm
                layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: DesignTokens.Spacing.xxl, bottom: DesignTokens.Spacing.xxl, trailing: DesignTokens.Spacing.xxl)
                return layoutSection
            }
        }
    }

    // MARK: - Data Source

    private func setupDataSource() {
        let headerReg = UICollectionView.CellRegistration<HeaderCell, Void> { cell, _, _ in
            cell.configure()
        }

        let cardReg = UICollectionView.CellRegistration<SeedCardCell, SeedPlanCard> { cell, _, card in
            cell.configure(with: card)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { cv, indexPath, item in
            switch item {
            case .header:
                return cv.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: ())
            case .card(let card):
                return cv.dequeueConfiguredReusableCell(using: cardReg, for: indexPath, item: card)
            }
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<SeedReviewSection, SeedReviewItem>()
        snapshot.appendSections([.header, .cards])
        snapshot.appendItems([.header], toSection: .header)
        snapshot.appendItems(cards.map { .card($0) }, toSection: .cards)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Bottom Bar

    private func setupBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),

            confirmButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: DesignTokens.Spacing.lg),
            confirmButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            confirmButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -DesignTokens.Spacing.xxl),
        ])
    }

    @objc private func confirmTapped() {
        Haptics.success()
        onConfirmed?()
    }
}

// MARK: - HeaderCell

private final class HeaderCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.text = "Your Starter Plan"

        subtitleLabel.font = DesignTokens.Typography.body
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.text = "You can always change these later."
        subtitleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure() {} // Static content set in init
}

// MARK: - SeedCardCell

private final class SeedCardCell: UICollectionViewCell {
    private let cardView = SeedPlanCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with card: SeedPlanCard) {
        cardView.configure(with: card)
    }
}
