import UIKit
import GRDB

class ModeDetailViewController: NoteDetailBaseViewController {

    var modeService: ModeService?

    override var headerEstimatedHeight: CGFloat { 400 }
    override var entityLabel: String { "mode" }

    private var currentNote: NotePage?
    private var isActive = false

    override func viewDidLoad() {
        _ = headerReg // Force creation before data source setup
        super.viewDidLoad()
    }

    private lazy var headerReg = UICollectionView.CellRegistration<ModeHeaderCell, Bool> { [weak self] cell, _, _ in
        guard let self, let note = self.currentNote else { return }
        cell.configure(with: note, isActive: self.isActive)
        cell.onFieldEdited = { [weak self] title, body in
            self?.saveInlineEdit(title: title, body: body)
        }
        cell.onToggleActive = { [weak self] in
            guard let self, let noteId = self.noteId else { return }
            self.toggleActiveMode(noteId: noteId, isCurrentlyActive: self.isActive)
        }
    }

    override func dequeueHeaderCell(for collectionView: UICollectionView, at indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: headerReg, for: indexPath, item: true)
    }

    override func loadData() {
        guard let noteId else { return }

        let observation = ValueObservation.tracking { db -> ModeDetailData? in
            guard let note = try NotePage.fetchOne(db, key: noteId) else { return nil }

            let isActive = try ActiveMode.fetchOne(db, key: noteId) != nil

            let links = try NoteDirective
                .filter(Column("noteId") == noteId)
                .order(Column("sortIndex"))
                .fetchAll(db)

            let allRules = try ScheduleRule.fetchAll(db)
            let directives: [DirectiveRowData] = links.compactMap { link in
                guard let dir = try? Directive.fetchOne(db, key: link.directiveId) else { return nil }
                let scheduled = allRules.contains { $0.directiveId == dir.id && ScheduleRule.ruleMatchesToday($0) }
                return DirectiveRowData(directive: dir, scheduledToday: scheduled)
            }

            return ModeDetailData(note: note, isActive: isActive, linkedDirectives: directives)
        }

        observationCancellable = observation.start(in: dbQueue, onError: { _ in }, onChange: { [weak self] data in
            guard let data else { return }
            self?.currentNote = data.note
            self?.isActive = data.isActive
            self?.navBar.setTitle(data.note.title)
            self?.applySnapshot(directives: data.linkedDirectives)
        })
    }

    // MARK: - Active Mode Toggle

    private func toggleActiveMode(noteId: UUID, isCurrentlyActive: Bool) {
        Task {
            do {
                try await modeService?.switchTo(noteId: isCurrentlyActive ? nil : noteId)
                Haptics.success()
            } catch {
                Haptics.error()
            }
        }
    }
}

// MARK: - ModeHeaderCell

private final class ModeHeaderCell: UICollectionViewCell, UITextViewDelegate {

    var onFieldEdited: ((String, String) -> Void)?
    var onToggleActive: (() -> Void)?

    private let glowLayer = CAGradientLayer()
    private let accentBar = UIView()
    private let iconView = UIImageView()
    private let kindBadge = UIButton(type: .system)
    private let titleView = UITextView()
    private let titlePlaceholder = UILabel()
    private let bodyView = UITextView()
    private let bodyPlaceholder = UILabel()
    private let showMoreButton = UIButton(type: .system)
    private var isExpanded = false
    private var bodyStack: UIStackView!
    private let activateButton = UIView()
    private let activateIcon = UIImageView()
    private let activateLabel = UILabel()
    private let shimmerLayer = CAGradientLayer()
    private var wasActive = false
    private var isCurrentlyActive = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func activateButtonTapped() {
        activateButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 10) {
            self.activateButton.transform = .identity
        }
        Haptics.medium()
        onToggleActive?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isCurrentlyActive {
            startActiveAnimations()
        }
    }

    @objc private func appDidBecomeActive() {
        if isCurrentlyActive {
            startActiveAnimations()
        }
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        let modeColor = NoteKind.mode.color
        contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
        contentView.layer.cornerRadius = DesignTokens.Radii.xl
        contentView.clipsToBounds = true
        DesignTokens.Shadows.apply(to: layer, elevation: .medium)
        clipsToBounds = false

        glowLayer.colors = [
            modeColor.withAlphaComponent(0.5).cgColor,
            modeColor.withAlphaComponent(0.0).cgColor,
        ]
        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        glowLayer.opacity = 0
        layer.insertSublayer(glowLayer, at: 0)

        accentBar.backgroundColor = modeColor
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accentBar)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
        iconView.image = UIImage(systemName: "bolt.fill", withConfiguration: iconConfig)
        iconView.tintColor = modeColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.title = "MODE"
        badgeConfig.cornerStyle = .capsule
        badgeConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        badgeConfig.baseBackgroundColor = modeColor.withAlphaComponent(0.15)
        badgeConfig.baseForegroundColor = modeColor
        badgeConfig.titleTextAttributesTransformer = .init { container in
            var c = container
            c.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)
            return c
        }
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
        titleView.setContentCompressionResistancePriority(.required, for: .vertical)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleView)

        titlePlaceholder.text = "Title"
        titlePlaceholder.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titlePlaceholder.textColor = DesignTokens.Colors.textTertiary
        titlePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        titleView.addSubview(titlePlaceholder)
        NSLayoutConstraint.activate([
            titlePlaceholder.topAnchor.constraint(equalTo: titleView.topAnchor),
            titlePlaceholder.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
        ])

        // Body (editable)
        bodyView.font = DesignTokens.Typography.body
        bodyView.textColor = DesignTokens.Colors.textSecondary
        bodyView.backgroundColor = .clear
        bodyView.isScrollEnabled = false
        bodyView.textContainerInset = .zero
        bodyView.textContainer.lineFragmentPadding = 0
        bodyView.textContainer.maximumNumberOfLines = 3
        bodyView.textContainer.lineBreakMode = .byTruncatingTail
        bodyView.delegate = self
        bodyView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bodyView)

        bodyPlaceholder.text = "Add a description…"
        bodyPlaceholder.font = DesignTokens.Typography.body
        bodyPlaceholder.textColor = DesignTokens.Colors.textTertiary
        bodyPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(bodyPlaceholder)
        NSLayoutConstraint.activate([
            bodyPlaceholder.topAnchor.constraint(equalTo: bodyView.topAnchor),
            bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor),
        ])

        showMoreButton.setTitle("Show more", for: .normal)
        showMoreButton.titleLabel?.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        showMoreButton.setTitleColor(DesignTokens.Colors.accent, for: .normal)
        showMoreButton.contentHorizontalAlignment = .leading
        showMoreButton.addTarget(self, action: #selector(toggleExpand), for: .touchUpInside)
        showMoreButton.isHidden = true

        activateButton.layer.cornerRadius = DesignTokens.Radii.lg
        activateButton.translatesAutoresizingMaskIntoConstraints = false
        activateButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(activateButtonTapped)))
        contentView.addSubview(activateButton)

        activateIcon.contentMode = .scaleAspectFit
        activateIcon.translatesAutoresizingMaskIntoConstraints = false
        activateButton.addSubview(activateIcon)

        activateLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        activateLabel.translatesAutoresizingMaskIntoConstraints = false
        activateButton.addSubview(activateLabel)

        let lighter = modeColor.withAlphaComponent(0.0).cgColor
        let highlight = UIColor.white.withAlphaComponent(0.25).cgColor
        shimmerLayer.colors = [lighter, highlight, lighter]
        shimmerLayer.locations = [0.0, 0.5, 1.0]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.cornerRadius = DesignTokens.Radii.lg
        shimmerLayer.isHidden = true
        activateButton.layer.addSublayer(shimmerLayer)

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

            titleView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: DesignTokens.Spacing.lg),
            titleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            titleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
        ])

        bodyStack = UIStackView(arrangedSubviews: [bodyView, showMoreButton, activateButton])
        bodyStack.axis = .vertical
        bodyStack.spacing = DesignTokens.Spacing.md
        bodyStack.alignment = .fill
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bodyStack)

        NSLayoutConstraint.activate([
            bodyStack.topAnchor.constraint(equalTo: titleView.bottomAnchor, constant: DesignTokens.Spacing.md),
            bodyStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            bodyStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            bodyStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding),

            showMoreButton.heightAnchor.constraint(equalToConstant: 36),
            activateButton.heightAnchor.constraint(equalToConstant: 48),

            activateIcon.leadingAnchor.constraint(equalTo: activateButton.leadingAnchor, constant: DesignTokens.Spacing.lg),
            activateIcon.centerYAnchor.constraint(equalTo: activateButton.centerYAnchor),
            activateIcon.widthAnchor.constraint(equalToConstant: 20),
            activateIcon.heightAnchor.constraint(equalToConstant: 20),

            activateLabel.leadingAnchor.constraint(equalTo: activateIcon.trailingAnchor, constant: DesignTokens.Spacing.sm),
            activateLabel.centerYAnchor.constraint(equalTo: activateButton.centerYAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = activateButton.bounds
        glowLayer.frame = bounds.insetBy(dx: -20, dy: -20)
        updateShowMoreVisibility()
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

    func configure(with note: NotePage, isActive: Bool) {
        let modeColor = NoteKind.mode.color
        isCurrentlyActive = isActive

        if !titleView.isFirstResponder {
            titleView.text = note.title
            titlePlaceholder.isHidden = !note.title.isEmpty
        }

        if !bodyView.isFirstResponder {
            bodyView.text = note.body
            bodyPlaceholder.isHidden = !note.body.isEmpty
            applyExpandState()
        }

        let shouldAnimate = wasActive != isActive && window != nil
        wasActive = isActive

        let btnIconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        if isActive {
            activateButton.backgroundColor = modeColor
            activateButton.layer.borderWidth = 0
            activateIcon.image = UIImage(systemName: "bolt.fill", withConfiguration: btnIconConfig)
            activateIcon.tintColor = .white
            activateLabel.text = "Active — Tap to Deactivate"
            activateLabel.textColor = .white

            contentView.backgroundColor = modeColor.withAlphaComponent(0.06)
            contentView.layer.borderWidth = 1.5
            contentView.layer.borderColor = modeColor.withAlphaComponent(0.4).cgColor
            accentBar.backgroundColor = modeColor

            if shouldAnimate {
                playActivateAnimation()
            } else {
                startActiveAnimations()
            }
        } else {
            activateButton.backgroundColor = DesignTokens.Colors.surfaceSecondary
            activateButton.layer.borderWidth = 1
            activateButton.layer.borderColor = modeColor.withAlphaComponent(0.4).cgColor
            activateIcon.image = UIImage(systemName: "bolt.fill", withConfiguration: btnIconConfig)
            activateIcon.tintColor = modeColor.withAlphaComponent(0.6)
            activateLabel.text = "Tap to Activate"
            activateLabel.textColor = DesignTokens.Colors.textPrimary

            contentView.backgroundColor = DesignTokens.Colors.surfacePrimary
            contentView.layer.borderWidth = 0
            accentBar.backgroundColor = modeColor.withAlphaComponent(0.4)

            stopActiveAnimations()

            if shouldAnimate {
                playDeactivateAnimation()
            }
        }
    }

    // MARK: - UITextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
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
                    isExpanded = true
                    applyExpandState()
                } else if isExpanded, !bodyExceedsCollapsedLines() {
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

    // MARK: - Animations

    private func playActivateAnimation() {
        let modeColor = NoteKind.mode.color

        activateButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 8) {
            self.activateButton.transform = .identity
        }

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = 0.4
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconView.layer.add(spin, forKey: "spin")

        let borderFlash = CABasicAnimation(keyPath: "borderColor")
        borderFlash.fromValue = modeColor.cgColor
        borderFlash.toValue = modeColor.withAlphaComponent(0.4).cgColor
        borderFlash.duration = 0.3
        borderFlash.autoreverses = true
        contentView.layer.add(borderFlash, forKey: "borderFlash")

        UIView.animate(withDuration: 0.15) {
            self.accentBar.transform = CGAffineTransform(scaleX: 1.0, y: 3.0)
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
                self.accentBar.transform = .identity
            }
        }

        playGlowPulse()
        startActiveAnimations()
        Haptics.success()
    }

    private func playDeactivateAnimation() {
        glowLayer.opacity = 0
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0.0, 0.6, 0.0]
        flash.keyTimes = [0.0, 0.2, 1.0]
        flash.duration = 0.5
        flash.isRemovedOnCompletion = true
        glowLayer.add(flash, forKey: "deactivateFlash")

        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.activateButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.activateButton.transform = .identity
            }
        }

        Haptics.light()
    }

    private func startActiveAnimations() {
        let modeColor = NoteKind.mode.color

        let iconPulse = CABasicAnimation(keyPath: "transform.scale")
        iconPulse.fromValue = 1.0
        iconPulse.toValue = 1.15
        iconPulse.duration = 1.5
        iconPulse.autoreverses = true
        iconPulse.repeatCount = .infinity
        iconPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconView.layer.add(iconPulse, forKey: "activePulse")

        let borderGlow = CABasicAnimation(keyPath: "borderColor")
        borderGlow.fromValue = modeColor.withAlphaComponent(0.4).cgColor
        borderGlow.toValue = modeColor.withAlphaComponent(0.15).cgColor
        borderGlow.duration = 2.0
        borderGlow.autoreverses = true
        borderGlow.repeatCount = .infinity
        borderGlow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentView.layer.add(borderGlow, forKey: "glowPulse")

        layer.shadowColor = modeColor.cgColor
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.25

        startShimmer()
    }

    private func stopActiveAnimations() {
        iconView.layer.removeAnimation(forKey: "activePulse")
        contentView.layer.removeAnimation(forKey: "glowPulse")
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        stopShimmer()
    }

    private func startShimmer() {
        shimmerLayer.isHidden = false
        shimmerLayer.frame = activateButton.bounds

        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.5, -0.25, 0.0]
        sweep.toValue = [1.0, 1.25, 1.5]
        sweep.duration = 2.0
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shimmerLayer.add(sweep, forKey: "shimmer")
    }

    private func stopShimmer() {
        shimmerLayer.removeAllAnimations()
        shimmerLayer.isHidden = true
    }

    private func playGlowPulse() {
        glowLayer.opacity = 0
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0.0, 0.7, 0.0]
        fade.keyTimes = [0.0, 0.3, 1.0]
        fade.duration = 0.8
        fade.isRemovedOnCompletion = true
        glowLayer.add(fade, forKey: "glowPulse")
    }
}

// MARK: - LinkButtonCell

final class LinkButtonCell: UICollectionViewCell {

    private let iconView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        contentView.backgroundColor = DesignTokens.Colors.accent.withAlphaComponent(0.12)
        contentView.layer.cornerRadius = DesignTokens.Radii.lg
        contentView.clipsToBounds = true

        iconView.tintColor = DesignTokens.Colors.accent
        iconView.contentMode = .scaleAspectFit

        label.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        label.textColor = DesignTokens.Colors.accent

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = DesignTokens.Spacing.sm
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.md),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.md),
        ])
    }

    func configure(title: String, systemImage: String) {
        label.text = title
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        iconView.image = UIImage(systemName: systemImage, withConfiguration: config)
    }
}
