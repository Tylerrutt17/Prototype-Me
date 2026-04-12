import UIKit
import GRDB

class NoteDetailViewController: NoteDetailBaseViewController {

    private var currentNote: NotePage?

    private lazy var headerReg = UICollectionView.CellRegistration<NoteHeaderCell, Bool> { [weak self] cell, _, _ in
        guard let self, let note = self.currentNote else { return }
        cell.configure(with: note, isExpanded: self.isBodyExpanded)
        cell.onToggleExpand = { [weak self] in self?.toggleBodyExpanded() }
    }

    override func dequeueHeaderCell(for collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: true)
    }

    override func loadData() {
        guard let noteId else { return }

        let observation = ValueObservation.tracking { db -> (NotePage?, [DirectiveRowData]) in
            guard let note = try NotePage.fetchOne(db, key: noteId) else { return (nil, []) }

            let links = try NoteDirective
                .filter(Column("noteId") == noteId)
                .order(Column("sortIndex"))
                .fetchAll(db)

            let allRules = try ScheduleRule.fetchAll(db)
            let rows: [DirectiveRowData] = links.compactMap { link in
                guard let dir = try? Directive.fetchOne(db, key: link.directiveId) else { return nil }
                let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                return DirectiveRowData(directive: dir, scheduledToday: scheduled)
            }
            return (note, rows)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] (note, directives) in
            self?.currentNote = note
            self?.navBar.setTitle(note?.title)
            self?.applySnapshot(directives: directives)
        })
    }
}

// MARK: - NoteHeaderCell

private final class NoteHeaderCell: UICollectionViewCell {

    var onToggleExpand: (() -> Void)?

    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let kindBadge = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let showMoreButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.xl
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .medium)
        clipsToBounds = false

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        kindBadge.configuration = badgeConfig
        kindBadge.isUserInteractionEnabled = false
        kindBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(kindBadge)

        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.numberOfLines = 0

        bodyLabel.font = DesignTokens.Typography.body
        bodyLabel.textColor = DesignTokens.Colors.textSecondary
        bodyLabel.numberOfLines = 0

        showMoreButton.setTitle("Show more", for: .normal)
        showMoreButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        showMoreButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        showMoreButton.contentHorizontalAlignment = .leading
        showMoreButton.addTarget(self, action: #selector(tappedShowMore), for: .touchUpInside)
        showMoreButton.isHidden = true

        // .fill alignment gives labels correct width during sizing pass
        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, showMoreButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.setCustomSpacing(DesignTokens.Spacing.xs, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            accentBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accentBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            accentBar.heightAnchor.constraint(equalToConstant: 4),

            iconView.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: DesignTokens.Spacing.lg),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            kindBadge.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            kindBadge.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: DesignTokens.Spacing.md),

            stack.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),

            showMoreButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @objc private func tappedShowMore() {
        onToggleExpand?()
    }

    func setExpanded(_ expanded: Bool, body: String) {
        bodyLabel.text = body
        bodyLabel.numberOfLines = expanded ? 0 : 3
        showMoreButton.setTitle(expanded ? "Show less" : "Show more", for: .normal)

        layoutIfNeeded()
        showMoreButton.isHidden = !bodyLabel.isTruncated && !expanded
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ShimmerBorder.updateFrame(on: contentView, cornerRadius: DesignTokens.Radii.xl)
    }

    func configure(with note: NotePage, isExpanded: Bool) {
        let color = note.kind.color
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        iconView.image = UIImage(systemName: note.kind.iconName, withConfiguration: iconConfig)
        iconView.tintColor = color

        accentBar.backgroundColor = color

        var badgeConfig = kindBadge.configuration ?? .filled()
        badgeConfig.title = note.kind.displayName.uppercased()
        badgeConfig.baseBackgroundColor = color.withAlphaComponent(0.15)
        badgeConfig.baseForegroundColor = color
        badgeConfig.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            return c
        }
        kindBadge.configuration = badgeConfig

        titleLabel.text = note.title

        if note.body.isEmpty {
            bodyLabel.isHidden = true
            showMoreButton.isHidden = true
        } else {
            bodyLabel.isHidden = false
            setExpanded(isExpanded, body: note.body)
        }

        // Shimmer border for modes
        if note.kind == .mode {
            DispatchQueue.main.async {
                ShimmerBorder.add(to: self.contentView, color: color, cornerRadius: DesignTokens.Radii.xl)
            }
        } else {
            ShimmerBorder.remove(from: contentView)
        }
    }
}

// MARK: - SectionHeaderView

final class SectionHeaderView: UICollectionReusableView {

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.lg),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.lg),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.xs),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title.uppercased()
    }
}

// MARK: - UILabel Truncation Check

extension UILabel {
    var isTruncated: Bool {
        guard let text, numberOfLines > 0, bounds.width > 0 else { return false }
        let maxSize = CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
        let fullHeight = (text as NSString).boundingRect(
            with: maxSize, options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font as Any], context: nil
        ).height
        return fullHeight > bounds.height + 2
    }
}
