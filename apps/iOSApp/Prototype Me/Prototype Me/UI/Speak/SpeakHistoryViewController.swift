import UIKit

/// Sheet-presented list of recent AI-driven changes with per-row Undo buttons.
/// Data lives in memory on the parent SpeakViewController; this VC just renders it.
final class SpeakHistoryViewController: UIViewController {

    var entries: [SpeakHistoryEntry] = []

    /// Called with the entry the user tapped undo on. Returns a human-readable result.
    var onUndo: ((SpeakHistoryEntry) async -> String)?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel()
    private let titleBar = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DesignTokens.Colors.background
        setupTitleBar()
        setupTable()
        setupEmptyState()
        refreshList()
    }

    // MARK: - Layout

    private func setupTitleBar() {
        titleBar.backgroundColor = DesignTokens.Colors.background
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBar)

        let titleLabel = UILabel()
        titleLabel.text = "Recent Changes"
        titleLabel.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(titleLabel)

        let closeButton = UIButton(type: .system)
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(systemName: "xmark")
        closeConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        closeConfig.baseForegroundColor = DesignTokens.Colors.textTertiary
        closeConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        closeButton.configuration = closeConfig
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(closeButton)

        let separator = UIView()
        separator.backgroundColor = DesignTokens.Colors.separator.withAlphaComponent(0.3)
        separator.translatesAutoresizingMaskIntoConstraints = false
        titleBar.addSubview(separator)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor, constant: -DesignTokens.Spacing.md),
            closeButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: titleBar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: titleBar.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.register(SpeakHistoryCell.self, forCellReuseIdentifier: SpeakHistoryCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.contentInset = UIEdgeInsets(top: DesignTokens.Spacing.sm, left: 0, bottom: DesignTokens.Spacing.lg, right: 0)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyState() {
        emptyLabel.text = "No recent changes.\nChanges made through Speak will show up here."
        emptyLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .regular)
        emptyLabel.textColor = DesignTokens.Colors.textTertiary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    private func refreshList() {
        emptyLabel.isHidden = !entries.isEmpty
        tableView.isHidden = entries.isEmpty
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Undo handling

    private func handleUndo(at index: Int) {
        guard index < entries.count else { return }
        let entry = entries[index]
        Task {
            _ = await onUndo?(entry)
            await MainActor.run {
                // Remove the entry from our local copy and refresh
                self.entries.remove(at: index)
                if self.entries.isEmpty {
                    self.refreshList()
                } else {
                    let indexPath = IndexPath(row: index, section: 0)
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension SpeakHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SpeakHistoryCell.reuseID, for: indexPath) as! SpeakHistoryCell
        cell.configure(with: entries[indexPath.row])
        cell.onUndoTapped = { [weak self] in self?.handleUndo(at: indexPath.row) }
        return cell
    }
}

// MARK: - SpeakHistoryCell

private final class SpeakHistoryCell: UITableViewCell {

    static let reuseID = "SpeakHistoryCell"

    var onUndoTapped: (() -> Void)?

    private let cardView = UIView()
    private let iconView = UIImageView()
    private let typeLabel = UILabel()
    private let dotLabel = UILabel()
    private let actionLabel = UILabel()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let undoButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { super.init(coder: coder); setupCell() }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.backgroundColor = DesignTokens.Colors.surfacePrimary
        cardView.layer.cornerRadius = DesignTokens.Radii.md
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        iconView.preferredSymbolConfiguration = iconConfig
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        typeLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .semibold)
        typeLabel.textColor = DesignTokens.Colors.textPrimary

        dotLabel.text = "\u{00B7}"
        dotLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .bold)
        dotLabel.textColor = DesignTokens.Colors.textTertiary

        actionLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .bold)

        nameLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .medium)
        nameLabel.textColor = DesignTokens.Colors.textSecondary
        nameLabel.numberOfLines = 1

        timeLabel.font = DesignTokens.Typography.rounded(style: .caption2, weight: .regular)
        timeLabel.textColor = DesignTokens.Colors.textTertiary

        var undoConfig = UIButton.Configuration.tinted()
        undoConfig.title = "Undo"
        undoConfig.image = UIImage(systemName: "arrow.uturn.backward")
        undoConfig.imagePadding = 4
        undoConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        undoConfig.baseBackgroundColor = DesignTokens.Colors.accent
        undoConfig.baseForegroundColor = DesignTokens.Colors.accent
        undoConfig.cornerStyle = .capsule
        undoConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        undoConfig.titleTextAttributesTransformer = .init { c in
            var c = c; c.font = DesignTokens.Typography.rounded(style: .caption1, weight: .semibold); return c
        }
        undoButton.configuration = undoConfig
        undoButton.addTarget(self, action: #selector(undoTapped), for: .touchUpInside)
        undoButton.setContentHuggingPriority(.required, for: .horizontal)

        let headerRow = UIStackView(arrangedSubviews: [iconView, typeLabel, dotLabel, actionLabel, UIView()])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.xs
        headerRow.alignment = .center

        let leftStack = UIStackView(arrangedSubviews: [headerRow, nameLabel, timeLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 2

        let mainRow = UIStackView(arrangedSubviews: [leftStack, undoButton])
        mainRow.axis = .horizontal
        mainRow.spacing = DesignTokens.Spacing.md
        mainRow.alignment = .center
        mainRow.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(mainRow)

        let inset = DesignTokens.Spacing.md
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.xs),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.xs),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.md),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.md),

            mainRow.topAnchor.constraint(equalTo: cardView.topAnchor, constant: inset),
            mainRow.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -inset),
            mainRow.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: inset),
            mainRow.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -inset),
        ])
    }

    func configure(with entry: SpeakHistoryEntry) {
        let entityType = Self.entityTypeName(entry.entityKind)
        iconView.image = UIImage(systemName: Self.iconName(for: entityType))
        iconView.tintColor = entry.actionType.color
        typeLabel.text = entityType.capitalized
        actionLabel.text = entry.actionType.appliedLabel.uppercased()
        actionLabel.textColor = entry.actionType.color
        nameLabel.text = entry.itemName
        timeLabel.text = Self.relativeTime(entry.timestamp)
    }

    @objc private func undoTapped() { onUndoTapped?() }

    private static func entityTypeName(_ kind: SpeakHistoryEntry.EntityKind) -> String {
        switch kind {
        case .directive: return "directive"
        case .note: return "note"
        case .journal: return "journal"
        case .folder: return "folder"
        case .mode: return "mode"
        }
    }

    private static func iconName(for itemType: String) -> String {
        switch itemType.lowercased() {
        case "directive":   return "target"
        case "journal":     return "book.fill"
        case "note":        return "doc.text.fill"
        case "mode":        return "bolt.fill"
        case "folder":      return "folder.fill"
        default:            return "doc.fill"
        }
    }

    private static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
