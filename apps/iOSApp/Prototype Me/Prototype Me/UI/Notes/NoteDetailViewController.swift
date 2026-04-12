import UIKit
import GRDB

class NoteDetailViewController: NoteDetailBaseViewController {

    private var currentNote: NotePage?

    override func viewDidLoad() {
        _ = headerReg // Force creation before data source setup
        super.viewDidLoad()
    }

    private lazy var headerReg = UICollectionView.CellRegistration<NoteHeaderCell, Bool> { [weak self] cell, _, _ in
        guard let self, let note = self.currentNote else { return }
        cell.configure(with: note)
        cell.onFieldEdited = { [weak self] title, body in
            self?.saveInlineEdit(title: title, body: body)
        }
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

private final class NoteHeaderCell: UICollectionViewCell, UITextViewDelegate {

    var onFieldEdited: ((String, String) -> Void)?

    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let kindBadge = UIButton(type: .system)
    private let titleView = UITextView()
    private let titlePlaceholder = UILabel()
    private let bodyView = UITextView()
    private let bodyPlaceholder = UILabel()
    private let showMoreButton = UIButton(type: .system)
    private var isExpanded = false

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

        // Title (editable)
        titleView.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleView.textColor = DesignTokens.Colors.textPrimary
        titleView.backgroundColor = .clear
        titleView.isScrollEnabled = false
        titleView.textContainerInset = .zero
        titleView.textContainer.lineFragmentPadding = 0
        titleView.delegate = self
        titleView.returnKeyType = .done

        titlePlaceholder.text = "Title"
        titlePlaceholder.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titlePlaceholder.textColor = DesignTokens.Colors.textTertiary
        titlePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(titlePlaceholder)
        NSLayoutConstraint.activate([
            titlePlaceholder.topAnchor.constraint(equalTo: titleView.topAnchor),
            titlePlaceholder.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
        ])

        // Body (editable, collapsed by default)
        bodyView.font = DesignTokens.Typography.body
        bodyView.textColor = DesignTokens.Colors.textSecondary
        bodyView.backgroundColor = .clear
        bodyView.isScrollEnabled = false
        bodyView.textContainerInset = .zero
        bodyView.textContainer.lineFragmentPadding = 0
        bodyView.textContainer.maximumNumberOfLines = 3
        bodyView.textContainer.lineBreakMode = .byTruncatingTail
        bodyView.delegate = self

        bodyPlaceholder.text = "Add a description…"
        bodyPlaceholder.font = DesignTokens.Typography.body
        bodyPlaceholder.textColor = DesignTokens.Colors.textTertiary
        bodyPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(bodyPlaceholder)
        NSLayoutConstraint.activate([
            bodyPlaceholder.topAnchor.constraint(equalTo: bodyView.topAnchor),
            bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
        ])

        // Show more/less
        showMoreButton.setTitle("Show more", for: .normal)
        showMoreButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        showMoreButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        showMoreButton.contentHorizontalAlignment = .leading
        showMoreButton.addTarget(self, action: #selector(toggleExpand), for: .touchUpInside)
        showMoreButton.isHidden = true

        let stack = UIStackView(arrangedSubviews: [titleView, bodyView, showMoreButton])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.alignment = .fill
        stack.setCustomSpacing(DesignTokens.Spacing.xs, after: bodyView)
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

    @objc private func toggleExpand() {
        isExpanded.toggle()
        applyExpandState()
        invalidateIntrinsicContentSize()
        if let collectionView = superview as? UICollectionView {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    private func applyExpandState() {
        bodyView.textContainer.maximumNumberOfLines = isExpanded ? 0 : 3
        bodyView.textContainer.lineBreakMode = isExpanded ? .byWordWrapping : .byTruncatingTail
        showMoreButton.setTitle(isExpanded ? "Show less" : "Show more", for: .normal)
        bodyView.invalidateIntrinsicContentSize()
    }

    private func bodyExceedsCollapsedLines() -> Bool {
        guard bodyView.bounds.width > 0 else { return false }
        let textStorage = NSTextStorage(attributedString: bodyView.attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: bodyView.bounds.width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        var lineCount = 0
        var index = 0
        let glyphCount = layoutManager.numberOfGlyphs
        while index < glyphCount {
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            lineCount += 1
            index = NSMaxRange(lineRange)
        }
        return lineCount > 3
    }

    private func updateShowMoreVisibility() {
        guard !bodyView.text.isEmpty else {
            showMoreButton.isHidden = true
            return
        }
        showMoreButton.isHidden = !bodyExceedsCollapsedLines() && !isExpanded
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ShimmerBorder.updateFrame(on: contentView, cornerRadius: DesignTokens.Radii.xl)
        updateShowMoreVisibility()
    }

    func configure(with note: NotePage) {
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

        if !titleView.isFirstResponder {
            titleView.text = note.title
            titlePlaceholder.isHidden = !note.title.isEmpty
        }

        if !bodyView.isFirstResponder {
            bodyView.text = note.body
            bodyPlaceholder.isHidden = !note.body.isEmpty
            applyExpandState()
        }

        if note.kind == .mode {
            DispatchQueue.main.async {
                ShimmerBorder.add(to: self.contentView, color: color, cornerRadius: DesignTokens.Radii.xl)
            }
        } else {
            ShimmerBorder.remove(from: contentView)
        }
    }

    // MARK: - UITextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
        // Auto-expand when user taps into the body to edit
        if textView === bodyView, !isExpanded {
            isExpanded = true
            applyExpandState()
            invalidateIntrinsicContentSize()
            if let collectionView = superview as? UICollectionView {
                collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textView === titleView, text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        if textView === titleView {
            titlePlaceholder.isHidden = !textView.text.isEmpty
        } else {
            bodyPlaceholder.isHidden = !textView.text.isEmpty
            if textView === bodyView {
                if !isExpanded, bodyExceedsCollapsedLines() {
                    // Auto-expand when typing past 3 lines
                    isExpanded = true
                    applyExpandState()
                } else if isExpanded, !bodyExceedsCollapsedLines() {
                    // Auto-collapse when text shrinks back to 3 lines or fewer
                    isExpanded = false
                    applyExpandState()
                }
                updateShowMoreVisibility()
            }
        }
        invalidateIntrinsicContentSize()
        if let collectionView = superview as? UICollectionView {
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView === titleView {
            titlePlaceholder.isHidden = !textView.text.isEmpty
        } else {
            bodyPlaceholder.isHidden = !textView.text.isEmpty
            // Collapse back if text fits in 3 lines
            if isExpanded, !bodyExceedsCollapsedLines() {
                isExpanded = false
                applyExpandState()
            }
            updateShowMoreVisibility()
        }
        let title = titleView.text ?? ""
        let body = bodyView.text ?? ""
        onFieldEdited?(title, body)
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
