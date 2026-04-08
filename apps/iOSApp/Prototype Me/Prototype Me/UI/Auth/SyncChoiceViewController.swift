import UIKit
import GRDB

/// Lets the user choose between pulling cloud data or pushing local data
/// when enabling sync (e.g., after a free→pro upgrade).
final class SyncChoiceViewController: UIViewController {

    // MARK: - Dependencies

    var apiClient: APIClient!
    var dbQueue: DatabaseQueue!
    var onChoice: ((SyncDirection) -> Void)?

    enum SyncDirection {
        case useCloud   // pull server data, wipe local
        case useDevice  // push local data, wipe server
    }

    // MARK: - Stats

    private struct Stats {
        let directives: Int
        let notes: Int
        let folders: Int
        let dayEntries: Int
        let lastUpdatedAt: Date?

        var isEmpty: Bool { directives == 0 && notes == 0 && folders == 0 && dayEntries == 0 }

        var summary: String {
            var parts: [String] = []
            if directives > 0 { parts.append("\(directives) directive\(directives == 1 ? "" : "s")") }
            if notes > 0 { parts.append("\(notes) note\(notes == 1 ? "" : "s")") }
            if folders > 0 { parts.append("\(folders) folder\(folders == 1 ? "" : "s")") }
            if dayEntries > 0 { parts.append("\(dayEntries) journal entr\(dayEntries == 1 ? "y" : "ies")") }
            if parts.isEmpty { return "No data" }
            if let date = lastUpdatedAt {
                parts.append("last updated \(Self.relativeFormat(date))")
            }
            return parts.joined(separator: " · ")
        }

        private static func relativeFormat(_ date: Date) -> String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }
    }

    private var cloudStats: Stats?
    private var localStats: Stats?

    // MARK: - UI

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let cloudCard = UIView()
    private let deviceCard = UIView()
    private let cloudButton = AppButton(title: "Use Cloud")
    private let deviceButton = AppButton(title: "Use This Device")
    private let cloudStatsLabel = UILabel()
    private let deviceStatsLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        isModalInPresentation = true  // prevent swipe-to-dismiss
        view.backgroundColor = DesignTokens.Colors.background
        buildLayout()
        loadStats()
    }

    // MARK: - Layout

    private func buildLayout() {
        titleLabel.text = "Sync Your Data"
        titleLabel.font = DesignTokens.Typography.rounded(style: .title2, weight: .bold)
        titleLabel.textColor = DesignTokens.Colors.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "We found data on both this device and the cloud.\nWhich version would you like to keep?"
        subtitleLabel.font = DesignTokens.Typography.rounded(style: .subheadline, weight: .regular)
        subtitleLabel.textColor = DesignTokens.Colors.textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        buildCard(cloudCard, icon: "cloud.fill", iconColor: .systemBlue, title: "Cloud",
                  statsLabel: cloudStatsLabel, button: cloudButton, action: #selector(cloudTapped))
        buildCard(deviceCard, icon: "iphone", iconColor: .systemGreen, title: "This Device",
                  statsLabel: deviceStatsLabel, button: deviceButton, action: #selector(deviceTapped))

        let cardStack = UIStackView(arrangedSubviews: [cloudCard, deviceCard])
        cardStack.axis = .vertical
        cardStack.spacing = DesignTokens.Spacing.lg
        cardStack.translatesAutoresizingMaskIntoConstraints = false

        spinner.color = DesignTokens.Colors.textSecondary
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(cardStack)
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xxxl),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            cardStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DesignTokens.Spacing.xxxl),
            cardStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            cardStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: cardStack.bottomAnchor, constant: DesignTokens.Spacing.xl),
        ])

        // Hide cards until stats load
        cardStack.alpha = 0
        cloudButton.isEnabled = false
        deviceButton.isEnabled = false
    }

    private func buildCard(_ card: UIView, icon: String, iconColor: UIColor, title: String,
                           statsLabel: UILabel, button: AppButton, action: Selector) {
        card.backgroundColor = DesignTokens.Colors.surfacePrimary
        card.layer.cornerRadius = DesignTokens.Radii.lg

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = DesignTokens.Typography.rounded(style: .headline, weight: .semibold)
        titleLbl.textColor = DesignTokens.Colors.textPrimary

        let headerRow = UIStackView(arrangedSubviews: [iconView, titleLbl])
        headerRow.axis = .horizontal
        headerRow.spacing = DesignTokens.Spacing.md
        headerRow.alignment = .center

        statsLabel.text = "Loading..."
        statsLabel.font = DesignTokens.Typography.rounded(style: .footnote, weight: .regular)
        statsLabel.textColor = DesignTokens.Colors.textSecondary
        statsLabel.numberOfLines = 0

        button.addTarget(self, action: action, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [headerRow, statsLabel, button])
        stack.axis = .vertical
        stack.spacing = DesignTokens.Spacing.md
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let pad = DesignTokens.Spacing.lg
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -pad),
        ])
    }

    // MARK: - Load Stats

    private func loadStats() {
        Task {
            // Load both in parallel
            async let cloudTask = fetchCloudStats()
            async let localTask = fetchLocalStats()

            let (cloud, local) = await (cloudTask, localTask)

            await MainActor.run {
                self.cloudStats = cloud
                self.localStats = local
                self.spinner.stopAnimating()

                self.cloudStatsLabel.text = cloud?.summary ?? "Could not load cloud data"
                self.deviceStatsLabel.text = local?.summary ?? "Could not load device data"

                // If cloud is empty, skip the choice — just push
                if let cloud, cloud.isEmpty {
                    self.subtitleLabel.text = "No data found in the cloud.\nYour local data will be synced up."
                    self.cloudCard.alpha = 0.4
                    self.cloudButton.isEnabled = false
                    self.cloudButton.alpha = 0.5
                }

                // If local is empty, skip the choice — just pull
                if let local, local.isEmpty {
                    self.subtitleLabel.text = "No data on this device.\nYour cloud data will be restored."
                    self.deviceCard.alpha = 0.4
                    self.deviceButton.isEnabled = false
                    self.deviceButton.alpha = 0.5
                }

                self.cloudButton.isEnabled = !(cloud?.isEmpty ?? true)
                self.deviceButton.isEnabled = !(local?.isEmpty ?? true)

                // If both empty, just proceed with cloud (nothing to conflict)
                if cloud?.isEmpty == true && local?.isEmpty == true {
                    self.onChoice?(.useCloud)
                    return
                }

                // If only one side has data, auto-select after a brief pause
                if cloud?.isEmpty == true && local?.isEmpty == false {
                    self.deviceButton.isEnabled = true
                }
                if local?.isEmpty == true && cloud?.isEmpty == false {
                    self.cloudButton.isEnabled = true
                }

                UIView.animate(withDuration: 0.4) {
                    self.cloudCard.superview?.alpha = 1
                }
            }
        }
    }

    private func fetchCloudStats() async -> Stats? {
        struct CloudStats: Decodable {
            let directives: Int
            let notes: Int
            let folders: Int
            let dayEntries: Int
            let lastUpdatedAt: String?
        }

        do {
            let response: CloudStats = try await apiClient.get("/v1/sync/stats")

            var lastDate: Date?
            if let dateStr = response.lastUpdatedAt {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastDate = formatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
            }

            return Stats(directives: response.directives, notes: response.notes,
                         folders: response.folders, dayEntries: response.dayEntries,
                         lastUpdatedAt: lastDate)
        } catch {
            print("[SyncChoice] Failed to fetch cloud stats: \(error)")
            return nil
        }
    }

    private func fetchLocalStats() async -> Stats? {
        do {
            return try await dbQueue.read { db in
                // Find the most recent updatedAt across local tables
                let dates: [Date?] = [
                    try Directive.select(max(Column("updatedAt"))).fetchOne(db),
                    try NotePage.select(max(Column("updatedAt"))).fetchOne(db),
                    try Folder.select(max(Column("updatedAt"))).fetchOne(db),
                    try DayEntry.select(max(Column("updatedAt"))).fetchOne(db),
                ]
                let lastUpdated = dates.compactMap { $0 }.max()

                return Stats(
                    directives: try Directive.fetchCount(db),
                    notes: try NotePage.fetchCount(db),
                    folders: try Folder.fetchCount(db),
                    dayEntries: try DayEntry.fetchCount(db),
                    lastUpdatedAt: lastUpdated
                )
            }
        } catch {
            print("[SyncChoice] Failed to fetch local stats: \(error)")
            return nil
        }
    }

    // MARK: - Actions

    @objc private func cloudTapped() {
        confirmChoice(
            title: "Use Cloud Data?",
            message: "Local data on this device will be replaced with your cloud data.",
            direction: .useCloud
        )
    }

    @objc private func deviceTapped() {
        confirmChoice(
            title: "Use This Device's Data?",
            message: "Cloud data will be replaced with what's on this device.",
            direction: .useDevice
        )
    }

    private func confirmChoice(title: String, message: String, direction: SyncDirection) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .destructive) { [weak self] _ in
            self?.onChoice?(direction)
        })
        present(alert, animated: true)
    }
}
