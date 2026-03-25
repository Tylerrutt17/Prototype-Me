import UIKit
import GRDB

// MARK: - Step Builders

extension NoteEditorViewController {

    // MARK: - Step 1: Title + Body

    func buildTitleBodyStep() -> UIView {
        let container = UIView()

        var headerViews: [UIView] = []
        if isCreateMode {
            headerViews.append(makeStepTitle("What's on your mind?"))
            headerViews.append(makeStepSubtitle("Give your note a title and start writing."))
        }

        let titleInput = UITextField()
        titleInput.placeholder = "Title"
        titleInput.text = enteredTitle
        titleInput.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleInput.textColor = DesignTokens.Colors.textPrimary
        titleInput.tintColor = DesignTokens.Colors.accent
        titleInput.returnKeyType = .done
        titleInput.tag = 100
        titleInput.delegate = self
        titleInput.addTarget(self, action: #selector(titleFieldChanged(_:)), for: .editingChanged)
        titleInput.attributedPlaceholder = NSAttributedString(
            string: "Title",
            attributes: [.foregroundColor: DesignTokens.Colors.textTertiary]
        )

        let titleContainer = UIView()
        titleInput.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleInput)
        let border = UIView()
        border.backgroundColor = DesignTokens.Colors.separator
        border.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(border)
        NSLayoutConstraint.activate([
            titleInput.topAnchor.constraint(equalTo: titleContainer.topAnchor, constant: DesignTokens.Spacing.sm),
            titleInput.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleInput.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            titleInput.bottomAnchor.constraint(equalTo: border.topAnchor, constant: -DesignTokens.Spacing.sm),
            border.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: titleContainer.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
        ])

        let bodyLabel = UILabel()
        bodyLabel.text = "BODY"
        bodyLabel.font = DesignTokens.Typography.caption1
        bodyLabel.textColor = DesignTokens.Colors.textSecondary

        let bodyInput = UITextView()
        bodyInput.text = enteredBody
        bodyInput.font = DesignTokens.Typography.body
        bodyInput.textColor = DesignTokens.Colors.textPrimary
        bodyInput.tintColor = DesignTokens.Colors.accent
        bodyInput.backgroundColor = DesignTokens.Colors.surfaceSecondary
        bodyInput.layer.cornerRadius = DesignTokens.Radii.md
        bodyInput.layer.borderWidth = 1
        bodyInput.layer.borderColor = DesignTokens.Colors.separator.cgColor
        bodyInput.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        bodyInput.tag = 101
        bodyInput.delegate = self

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard)),
        ]
        toolbar.tintColor = DesignTokens.Colors.accent
        bodyInput.inputAccessoryView = toolbar

        var arrangedViews: [UIView] = headerViews
        arrangedViews.append(contentsOf: [titleContainer, bodyLabel, bodyInput])

        let stack = UIStackView(arrangedSubviews: arrangedViews)
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        container.addSubview(scroll)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -padding * 2),
            bodyInput.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
        ])

        // Only auto-focus keyboard for new notes, not when editing
        if isCreateMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                titleInput.becomeFirstResponder()
            }
        }

        return container
    }

    // MARK: - Step 2: Kind (Deck Carousel)

    func buildKindStep() -> UIView {
        let existingFrameworkId: UUID? = try? dbQueue.read { db in
            try NotePage
                .filter(Column("kind") == NoteKind.framework.rawValue)
                .fetchOne(db)?
                .id
        }
        // Block framework selection if one already exists — unless we're editing that framework
        let frameworkExists = existingFrameworkId != nil && existingFrameworkId != noteId

        let kinds: [(kind: NoteKind, icon: String, title: String, desc: String, detail: String)] = [
            (.regular, "doc.text", "Regular",
             "A freeform note for anything.",
             "Use regular notes for ideas, references, learning materials, or anything you want to capture. They can be organized into folders and linked to directives."),
            (.mode, "bolt.fill", "Mode",
             "An operating mode that filters your Focus.",
             "Modes represent different states of working — like \"Deep Work\", \"Social\", or \"Recovery\". When you activate a mode on the Focus tab, it filters which directives and schedule items you see. Create modes that match how you actually work."),
            (.situation, "cloud.sun.fill", "Situation",
             "A contextual scenario with linked directives.",
             "Situations describe recurring contexts — like \"Feeling overwhelmed\" or \"Starting a new project\". Link directives to situations so you know exactly what to do when they arise."),
            (.framework, "star.fill", "Framework",
             frameworkExists ? "Already created." : "Your personal values and principles.",
             frameworkExists ? "You can only have one framework." : "Your personal constitution. Write down your core values, principles, and non-negotiables. This note is pinned at the top of your Notes tab and limited to one per account."),
        ]

        let container = UIView()

        let titleLabel = makeStepTitle("What type of note?")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        let subtitleLabel = makeStepSubtitle("Swipe through the deck. Tap to select.")
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)

        // Icon-based page indicator
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let pageIcons: [UIImageView] = kinds.map { k in
            let iv = UIImageView(image: UIImage(systemName: k.icon, withConfiguration: iconConfig))
            iv.contentMode = .scaleAspectFit
            iv.tintColor = DesignTokens.Colors.textTertiary.withAlphaComponent(0.3)
            iv.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iv.widthAnchor.constraint(equalToConstant: 24),
                iv.heightAnchor.constraint(equalToConstant: 24),
            ])
            return iv
        }
        let initialPage = kinds.firstIndex(where: { $0.kind == selectedKind }) ?? 0
        pageIcons[initialPage].tintColor = kinds[initialPage].kind.color

        let pageStack = UIStackView(arrangedSubviews: pageIcons)
        pageStack.axis = .horizontal
        pageStack.spacing = DesignTokens.Spacing.lg
        pageStack.alignment = .center
        pageStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(pageStack)

        func updatePageIcons(page: Int) {
            for (i, icon) in pageIcons.enumerated() {
                UIView.animate(withDuration: 0.2) {
                    icon.tintColor = i == page
                        ? kinds[i].kind.color
                        : DesignTokens.Colors.textTertiary.withAlphaComponent(0.3)
                    icon.transform = i == page
                        ? CGAffineTransform(scaleX: 1.3, y: 1.3)
                        : .identity
                }
            }
        }
        var currentPage = initialPage

        weak var weakCV: UICollectionView?
        let layout = UICollectionViewCompositionalLayout { [weak self] _, environment in
            let containerWidth = environment.container.effectiveContentSize.width
            let sideInset = DesignTokens.Spacing.xl
            let cardWidth = containerWidth - sideInset * 2
            let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: .estimated(360))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .groupPagingCentered
            section.interGroupSpacing = -cardWidth * 0.15  // overlap adjacent cards behind front

            section.visibleItemsInvalidationHandler = { [weak self] items, offset, env in
                let pageWidth = cardWidth + (-cardWidth * 0.15)  // card width + negative spacing
                let page = Int(round(offset.x / pageWidth))
                if currentPage != page {
                    currentPage = page
                    updatePageIcons(page: page)

                    // Select the front card immediately — cell animations are internal
                    guard let self, page < kinds.count else { return }
                    let kind = kinds[page].kind
                    guard kind != .framework || !frameworkExists else { return }
                    if self.selectedKind != kind {
                        self.selectedKind = kind
                        Haptics.selection()
                        if let cv = weakCV {
                            for cell in cv.visibleCells {
                                guard let indexPath = cv.indexPath(for: cell),
                                      let kindCell = cell as? KindCarouselCell else { continue }
                                let k = kinds[indexPath.item]
                                kindCell.configure(
                                    icon: k.icon, title: k.title, subtitle: k.desc,
                                    detail: k.detail, isSelected: self.selectedKind == k.kind,
                                    isDisabled: k.kind == .framework && frameworkExists,
                                    kindColor: k.kind.color
                                )
                            }
                        }
                    }
                }

                // 3D deck transforms
                let centerX = offset.x + containerWidth / 2
                for item in items {
                    guard let cell = weakCV?.cellForItem(at: item.indexPath) else { continue }

                    let itemCenterX = item.frame.midX
                    let distance = (itemCenterX - centerX) / pageWidth
                    let absDistance = min(abs(distance), 2.0)

                    let scale = 1.0 - absDistance * 0.08
                    let yShift = absDistance * 12
                    let rotation = -distance * 0.04
                    let opacity = 1.0 - absDistance * 0.1

                    var t = CATransform3DIdentity
                    t.m34 = -1.0 / 800
                    t = CATransform3DTranslate(t, 0, yShift, -absDistance * 60)
                    t = CATransform3DScale(t, scale, scale, 1)
                    t = CATransform3DRotate(t, rotation, 0, 0, 1)

                    cell.layer.transform = t
                    cell.alpha = max(0.75, opacity)
                    cell.layer.zPosition = CGFloat((1.0 - absDistance) * 100)
                }
            }
            return section
        }

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        weakCV = cv
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.clipsToBounds = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cv)

        let cellReg = UICollectionView.CellRegistration<KindCarouselCell, Int> { [weak self] cell, _, index in
            guard let self else { return }
            let k = kinds[index]
            let isSelected = self.selectedKind == k.kind
            cell.configure(icon: k.icon, title: k.title, subtitle: k.desc, detail: k.detail, isSelected: isSelected, isDisabled: k.kind == .framework && frameworkExists, kindColor: k.kind.color)
        }

        let ds = UICollectionViewDiffableDataSource<Int, Int>(collectionView: cv) { cv, indexPath, index in
            cv.dequeueConfiguredReusableCell(using: cellReg, for: indexPath, item: index)
        }
        var snap = NSDiffableDataSourceSnapshot<Int, Int>()
        snap.appendSections([0])
        snap.appendItems(Array(0..<kinds.count), toSection: 0)
        ds.apply(snap, animatingDifferences: false)
        self.kindDS = ds
        objc_setAssociatedObject(container, "kindDS", ds, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let tapGesture = BlockTapGesture { [weak self] in
            guard let self else { return }
            let page = currentPage
            let kind = kinds[page].kind

            // Don't select framework if one already exists
            if kind == .framework && frameworkExists {
                Haptics.warning()
                return
            }
            self.selectedKind = kind
            Haptics.success()
            self.showStep(2, animated: true)
        }
        cv.addGestureRecognizer(tapGesture)

        let nextButton = AppButton(title: "Next")
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addAction(UIAction { [weak self] _ in
            self?.showStep(2, animated: true)
        }, for: .touchUpInside)
        container.addSubview(nextButton)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            subtitleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),

            cv.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DesignTokens.Spacing.xl),
            cv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            cv.heightAnchor.constraint(equalToConstant: 380),

            pageStack.topAnchor.constraint(equalTo: cv.bottomAnchor, constant: DesignTokens.Spacing.sm),
            pageStack.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            nextButton.topAnchor.constraint(equalTo: pageStack.bottomAnchor, constant: DesignTokens.Spacing.lg),
            nextButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            nextButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
        ])

        // Scroll carousel to the current kind when editing.
        // orthogonalScrollingBehavior uses an internal UIScrollView, so scrollToItem
        // doesn't work — we find the internal scroll view and set its offset directly.
        if initialPage > 0 {
            DispatchQueue.main.async {
                cv.layoutIfNeeded()
                for subview in cv.subviews {
                    guard let scrollView = subview as? UIScrollView, scrollView !== cv else { continue }
                    let sideInset = DesignTokens.Spacing.xl
                    let cardWidth = cv.bounds.width - sideInset * 2
                    let spacing = -cardWidth * 0.15
                    let pageWidth = cardWidth + spacing
                    scrollView.setContentOffset(
                        CGPoint(x: pageWidth * CGFloat(initialPage), y: 0),
                        animated: false
                    )
                    break
                }
            }
        }

        return container
    }

    // MARK: - Step 2: Folder

    func buildFolderStep() -> UIView {
        // Pre-expand the parent chain of the selected folder on first build
        if let selectedId = selectedFolderId, expandedFolderIds.isEmpty {
            var current = selectedId
            while let folder = folders.first(where: { $0.id == current }), let parentId = folder.parentFolderId {
                expandedFolderIds.insert(parentId)
                current = parentId
            }
        }

        let container = UIView()
        let titleLabel = makeStepTitle(isCreateMode ? "Add to a folder?" : "Move to a folder?")
        let subtitleLabel = makeStepSubtitle("Optional. You can change this later.")

        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = DesignTokens.Spacing.xs
        self.folderListStack = cardsStack

        let button = AppButton(title: isCreateMode ? "Create Note" : "Save")
        button.addAction(UIAction { [weak self] _ in self?.saveNote() }, for: .touchUpInside)

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cardsStack, button])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.lg
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(mainStack)
        container.addSubview(scroll)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mainStack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: padding),
            mainStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -padding),
            mainStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            mainStack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -padding * 2),
        ])

        populateFolderList()
        return container
    }

    /// Rebuilds just the folder rows inside the existing stack, with an optional crossfade.
    func populateFolderList() {
        guard let stack = folderListStack else { return }

        let rootFolders = folders.filter { $0.parentFolderId == nil }.sorted { $0.sortIndex < $1.sortIndex }
        func children(of parentId: UUID) -> [Folder] {
            folders.filter { $0.parentFolderId == parentId }.sorted { $0.sortIndex < $1.sortIndex }
        }

        // Snapshot old views for crossfade
        let oldViews = stack.arrangedSubviews

        // Build new rows into a temporary array
        var newViews: [UIView] = []

        // "No Folder" option
        newViews.append(makeOptionCard(
            icon: "tray", title: "No Folder",
            description: "Keep at root level.", isSelected: selectedFolderId == nil,
            onTap: { [weak self] in
                self?.selectedFolderId = nil
                Haptics.selection()
                self?.populateFolderList()
            }
        ))

        func addFolderRows(folder: Folder, depth: Int) {
            let fId = folder.id
            let subs = children(of: fId)
            let hasChildren = !subs.isEmpty
            let isExpanded = expandedFolderIds.contains(fId)
            let isSelected = selectedFolderId == fId

            let row = TappableCardView(onTap: { [weak self] in
                guard let self else { return }
                self.selectedFolderId = fId
                if hasChildren {
                    if self.expandedFolderIds.contains(fId) {
                        if isSelected { self.expandedFolderIds.remove(fId) }
                    } else {
                        self.expandedFolderIds.insert(fId)
                    }
                }
                Haptics.selection()
                self.populateFolderList()
            })
            row.backgroundColor = isSelected
                ? DesignTokens.Colors.accent.withAlphaComponent(0.12)
                : DesignTokens.Colors.surfacePrimary
            row.layer.cornerRadius = DesignTokens.Radii.md
            row.layer.borderWidth = isSelected ? 1.5 : 1
            row.layer.borderColor = isSelected
                ? DesignTokens.Colors.accent.cgColor
                : DesignTokens.Colors.separator.cgColor
            row.clipsToBounds = true

            let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let folderIcon = UIImageView(image: UIImage(systemName: "folder.fill", withConfiguration: iconConfig))
            folderIcon.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary
            folderIcon.contentMode = .scaleAspectFit
            folderIcon.translatesAutoresizingMaskIntoConstraints = false
            folderIcon.widthAnchor.constraint(equalToConstant: 20).isActive = true

            let nameLabel = UILabel()
            nameLabel.text = folder.name
            nameLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: isSelected ? .semibold : .medium)
            nameLabel.textColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textPrimary

            let checkConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            let checkView = UIImageView()
            checkView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle", withConfiguration: checkConfig)
            checkView.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary
            checkView.translatesAutoresizingMaskIntoConstraints = false
            checkView.widthAnchor.constraint(equalToConstant: 18).isActive = true

            var rowViews: [UIView] = [folderIcon, nameLabel, UIView(), checkView]
            if hasChildren {
                let chevronConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
                let chevron = UIImageView(image: UIImage(systemName: isExpanded ? "chevron.down" : "chevron.right", withConfiguration: chevronConfig))
                chevron.tintColor = DesignTokens.Colors.textTertiary
                chevron.contentMode = .scaleAspectFit
                chevron.translatesAutoresizingMaskIntoConstraints = false
                chevron.widthAnchor.constraint(equalToConstant: 12).isActive = true
                rowViews.append(chevron)
            }

            let hStack = UIStackView(arrangedSubviews: rowViews)
            hStack.axis = .horizontal
            hStack.spacing = DesignTokens.Spacing.sm
            hStack.alignment = .center
            hStack.isUserInteractionEnabled = false
            hStack.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(hStack)

            let vPad = DesignTokens.Spacing.md
            let hPad = DesignTokens.Spacing.md
            NSLayoutConstraint.activate([
                hStack.topAnchor.constraint(equalTo: row.topAnchor, constant: vPad),
                hStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -vPad),
                hStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: hPad),
                hStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -hPad),
            ])

            if depth > 0 {
                let wrapper = UIView()
                row.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(row)
                NSLayoutConstraint.activate([
                    row.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                    row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: CGFloat(depth) * DesignTokens.Spacing.xl),
                    row.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                ])
                newViews.append(wrapper)
            } else {
                newViews.append(row)
            }

            if isExpanded {
                for child in subs {
                    addFolderRows(folder: child, depth: depth + 1)
                }
            }
        }

        for folder in rootFolders {
            addFolderRows(folder: folder, depth: 0)
        }

        // Swap content instantly — no animation to avoid layout jumps
        oldViews.forEach { $0.removeFromSuperview() }
        for view in newViews {
            stack.addArrangedSubview(view)
        }
    }

    // MARK: - Generic Card Step Builder

    func buildCardStep(
        title: String,
        subtitle: String,
        options: [(icon: String, title: String, description: String, isSelected: Bool, action: () -> Void)],
        buttonTitle: String? = nil,
        buttonAction: (() -> Void)? = nil
    ) -> UIView {
        let container = UIView()

        let titleLabel = makeStepTitle(title)
        let subtitleLabel = makeStepSubtitle(subtitle)

        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = DesignTokens.Spacing.md

        for opt in options {
            let card = makeOptionCard(
                icon: opt.icon, title: opt.title,
                description: opt.description, isSelected: opt.isSelected,
                onTap: opt.action
            )
            cardsStack.addArrangedSubview(card)
        }

        var arrangedViews: [UIView] = [titleLabel, subtitleLabel, cardsStack]

        if let buttonTitle, let buttonAction {
            let button = AppButton(title: buttonTitle)
            let action = buttonAction
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            arrangedViews.append(button)
        }

        let stack = UIStackView(arrangedSubviews: arrangedViews)
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.lg
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        container.addSubview(scroll)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: DesignTokens.Spacing.xl),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -padding),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -padding * 2),
        ])

        return container
    }

    // MARK: - Option Card

    func makeOptionCard(icon: String, title: String, description: String, isSelected: Bool, onTap: @escaping () -> Void) -> UIView {
        let card = TappableCardView(onTap: onTap)

        card.backgroundColor = isSelected
            ? DesignTokens.Colors.accent.withAlphaComponent(0.15)
            : DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg
        card.layer.borderWidth = isSelected ? 2 : 1
        card.layer.borderColor = isSelected
            ? DesignTokens.Colors.accent.cgColor
            : DesignTokens.Colors.separator.cgColor
        card.clipsToBounds = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLbl.textColor = DesignTokens.Colors.textPrimary

        let descLbl = UILabel()
        descLbl.text = description
        descLbl.font = DesignTokens.Typography.caption1
        descLbl.textColor = DesignTokens.Colors.textSecondary
        descLbl.numberOfLines = 0
        descLbl.isHidden = description.isEmpty

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let checkView = UIImageView()
        if isSelected {
            checkView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
            checkView.tintColor = DesignTokens.Colors.accent
        } else {
            checkView.image = UIImage(systemName: "circle", withConfiguration: checkConfig)
            checkView.tintColor = DesignTokens.Colors.textTertiary
        }
        checkView.setContentHuggingPriority(.required, for: .horizontal)

        let textStack = UIStackView(arrangedSubviews: [titleLbl, descLbl])
        textStack.axis = .vertical
        textStack.spacing = DesignTokens.Spacing.xs

        let row = UIStackView(arrangedSubviews: [iconView, textStack, checkView])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.lg
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        row.isUserInteractionEnabled = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 32),
            checkView.widthAnchor.constraint(equalToConstant: 24),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: DesignTokens.Spacing.lg),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -DesignTokens.Spacing.lg),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: DesignTokens.Spacing.lg),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -DesignTokens.Spacing.lg),
        ])

        return card
    }

    // MARK: - Label Helpers

    func makeStepTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        label.textColor = DesignTokens.Colors.textPrimary
        return label
    }

    func makeStepSubtitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = DesignTokens.Typography.body
        label.textColor = DesignTokens.Colors.textSecondary
        label.numberOfLines = 0
        return label
    }
}
