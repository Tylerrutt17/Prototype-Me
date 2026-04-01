import UIKit
import GRDB

/// Standalone modal for moving a note or folder into a different folder.
final class FolderPickerViewController: BaseViewController {

    // MARK: - Public

    /// The entity being moved — exactly one must be set.
    var noteId: UUID?
    var folderId: UUID?

    var noteService: NoteService?
    var folderService: FolderService?
    var onDone: (() -> Void)?

    // MARK: - State

    private var selectedFolderId: UUID?
    private var currentFolderId: UUID?   // where the item lives now
    private var folders: [Folder] = []
    private var expandedFolderIds: Set<UUID> = []
    private var folderListStack: UIStackView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navBar.setTitle("Move to Folder", animated: false)
        navBar.setLeftButton(title: "Cancel", systemImage: nil, action: { [weak self] in
            self?.dismiss(animated: true)
        })

        loadCurrentFolder()
        loadFolders()
        buildUI()
    }

    // MARK: - Data

    private func loadCurrentFolder() {
        if let noteId {
            currentFolderId = try? dbQueue.read { db in
                try NotePage.fetchOne(db, key: noteId)?.folderId
            }
        } else if let folderId {
            currentFolderId = try? dbQueue.read { db in
                try Folder.fetchOne(db, key: folderId)?.parentFolderId
            }
        }
        selectedFolderId = currentFolderId
    }

    private func loadFolders() {
        folders = (try? dbQueue.read { db in
            try Folder.order(Column("name")).fetchAll(db)
        }) ?? []
    }

    // MARK: - UI

    private func buildUI() {
        let titleLabel = makeLabel(
            "Where should it go?",
            font: DesignTokens.Typography.rounded(style: .title2, weight: .bold),
            color: DesignTokens.Colors.textPrimary
        )
        let subtitleLabel = makeLabel(
            "Pick a folder or keep at root.",
            font: DesignTokens.Typography.body,
            color: DesignTokens.Colors.textSecondary
        )
        subtitleLabel.numberOfLines = 0

        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = DesignTokens.Spacing.xs
        self.folderListStack = cardsStack

        let moveButton = AppButton(title: "Move Here")
        moveButton.addAction(UIAction { [weak self] _ in self?.performMove() }, for: .touchUpInside)

        let mainStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, cardsStack, moveButton])
        mainStack.axis = .vertical
        mainStack.spacing = DesignTokens.Spacing.lg
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(mainStack)
        view.addSubview(scroll)

        let padding = DesignTokens.Spacing.xl
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: contentTopAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainStack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: DesignTokens.Spacing.xl),
            mainStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: padding),
            mainStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -padding),
            mainStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -DesignTokens.Spacing.xxxl),
            mainStack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -padding * 2),
        ])

        populateFolderList()
    }

    // MARK: - Folder List

    private func populateFolderList() {
        guard let stack = folderListStack else { return }

        let rootFolders = folders.filter { $0.parentFolderId == nil }.sorted { $0.sortIndex < $1.sortIndex }
        func children(of parentId: UUID) -> [Folder] {
            folders.filter { $0.parentFolderId == parentId }.sorted { $0.sortIndex < $1.sortIndex }
        }

        let oldViews = stack.arrangedSubviews
        var newViews: [UIView] = []

        // "No Folder" (root) option
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

            // Don't allow moving a folder into itself or its descendants
            let isDisabled = fId == folderId || isDescendant(of: folderId, folderId: fId)

            let row = TappableCardView(onTap: { [weak self] in
                guard let self, !isDisabled else { return }
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
            row.alpha = isDisabled ? 0.4 : 1.0
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
                for child in subs { addFolderRows(folder: child, depth: depth + 1) }
            }
        }

        for folder in rootFolders { addFolderRows(folder: folder, depth: 0) }

        oldViews.forEach { $0.removeFromSuperview() }
        for v in newViews { stack.addArrangedSubview(v) }
    }

    /// Returns true if `candidateId` is a descendant of `ancestorId`.
    private func isDescendant(of ancestorId: UUID?, folderId candidateId: UUID) -> Bool {
        guard let ancestorId else { return false }
        var current: UUID? = candidateId
        while let c = current {
            if c == ancestorId { return true }
            current = folders.first(where: { $0.id == c })?.parentFolderId
        }
        return false
    }

    // MARK: - Move

    private func performMove() {
        Task {
            do {
                if let noteId {
                    try await noteService?.moveToFolder(noteId: noteId, folderId: selectedFolderId)
                } else if let folderId {
                    try await folderService?.moveFolder(folderId: folderId, toParentId: selectedFolderId)
                }
                Haptics.success()
                onDone?()
            } catch {
                Haptics.error()
            }
        }
    }

    // MARK: - Option Card

    private func makeOptionCard(icon: String, title: String, description: String, isSelected: Bool, onTap: @escaping () -> Void) -> UIView {
        let card = TappableCardView(onTap: onTap)

        card.backgroundColor = isSelected
            ? DesignTokens.Colors.accent.withAlphaComponent(0.12)
            : DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.md
        card.layer.borderWidth = isSelected ? 1.5 : 1
        card.layer.borderColor = isSelected
            ? DesignTokens.Colors.accent.cgColor
            : DesignTokens.Colors.separator.cgColor
        card.clipsToBounds = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = DesignTokens.Typography.rounded(style: .subheadline, weight: isSelected ? .semibold : .medium)
        titleLbl.textColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textPrimary

        let descLbl = UILabel()
        descLbl.text = description
        descLbl.font = DesignTokens.Typography.caption2
        descLbl.textColor = DesignTokens.Colors.textTertiary
        descLbl.numberOfLines = 0

        let checkConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let checkView = UIImageView()
        checkView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle", withConfiguration: checkConfig)
        checkView.tintColor = isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.textTertiary
        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let textStack = UIStackView(arrangedSubviews: [titleLbl, descLbl])
        textStack.axis = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconView, textStack, UIView(), checkView])
        row.axis = .horizontal
        row.spacing = DesignTokens.Spacing.sm
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let pad = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])

        return card
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        return label
    }
}
