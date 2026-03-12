import SwiftUI
import CloudKit
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var isResetting = false
    @State private var resetError: Error?
    @AppStorage("lockEnabled") private var lockEnabled: Bool = true
    @AppStorage("lockOnForeground") private var lockOnForeground: Bool = true
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled: Bool = false
    @AppStorage("dailyReminderTime") private var dailyReminderTime: Double = 9 * 3600 // 9:00 AM default
    @State private var notificationMessage: String?
    @State private var showNotificationAlert = false

    var body: some View {
        Form {
            Section(header: Text("Reminders"), footer: Text("Receive one gentle check-in notification each day at your chosen time.")) {
                Toggle("Daily Check-In", isOn: $dailyReminderEnabled)
                DatePicker("Time",
                           selection: reminderTimeBinding,
                           displayedComponents: .hourAndMinute)
                .disabled(!dailyReminderEnabled)
            }

            if let notificationMessage {
                Section {
                    Text(notificationMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Security")) {
                Toggle("Require Unlock on Launch", isOn: $lockEnabled)
                Toggle("Require Unlock When Returning", isOn: $lockOnForeground)
            }
            Section(footer: Text("Deletes **all** data stored in iCloud for this app and wipes the on-device database. This cannot be undone.")) {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    if isResetting {
                        ProgressView()
                    } else {
                        Text("Reset iCloud Data")
                    }
                }
                .disabled(isResetting)
            }

            if let resetError {
                Section {
                    Text("Failed: \(resetError.localizedDescription)")
                        .foregroundStyle(.red)
                }
            }

            Section(header: Text("Import Data from JSON")) {
                // Paste-in fallback
                TextEditor(text: $importText)
                    .frame(minHeight: 100)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.secondary)

                HStack {
                    Button("Paste Import") { importFromText() }
                    Spacer()
                    Button("Choose File…") { showingImporter = true }
                }
            }

            if let importError {
                Section {
                    Text("Import failed: \(importError.localizedDescription)")
                        .foregroundStyle(.red)
                }
            }

            if importSuccess {
                Section {
                    Text("Import succeeded ✅")
                        .foregroundStyle(.green)
                }
            }

            Section(header: Text("Export All Data")) {
                Button("Generate JSON") {
                    Task {
                        do {
                            let data = try DataImporter.export(from: context)
                            exportURL = try writeTemp(data: data)
                        } catch {
                            exportError = error
                        }
                    }
                }

                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Share Export", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if let exportError {
                Section {
                    Text("Export failed: \(exportError.localizedDescription)")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            if dailyReminderEnabled {
                await NotificationScheduler.refreshDailyReminder(enabled: true, time: reminderDate)
            }
        }
        .alert("This will permanently delete all data in iCloud and on this device.", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await resetAllData() }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                var data: Data?
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                data = try? Data(contentsOf: url)
                if let d = data {
                    Task { await performImport(data: d) }
                }
            case .failure(let err):
                importError = err
            }
        }
        .alert("Notifications are disabled", isPresented: $showNotificationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enable notifications in iOS Settings to receive daily check-ins.")
        }
        .onChange(of: dailyReminderEnabled) { enabled in
            Task { await updateDailyReminder(enabled: enabled) }
        }
        .onChange(of: dailyReminderTime) { _ in
            guard dailyReminderEnabled else { return }
            Task { await NotificationScheduler.refreshDailyReminder(enabled: true, time: reminderDate) }
        }
    }

    // MARK: - Full reset routine
    @MainActor
    private func resetAllData() async {
        guard !isResetting else { return }
        isResetting = true
        resetError = nil

        do {
            try await deleteCloudKitZone()
            try deleteLocalObjects()
            try SeedData.populateIfNeeded(container: context.container)
        } catch {
            resetError = error
        }

        isResetting = false
    }

    /// Delete the `SwiftData` record zone in the user's private database.
    private func deleteCloudKitZone() async throws {
        let zoneID = CKRecordZone.ID(zoneName: "SwiftData", ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await CKContainer(identifier: "iCloud.com.prototypemeapp")
                .privateCloudDatabase
                .deleteRecordZone(withID: zoneID)
        } catch {
            // Ignore "zone not found" errors so repeated resets don't fail.
            if let ckErr = error as? CKError, ckErr.code == .zoneNotFound {
                return
            }
            throw error
        }
    }

    /// Remove all objects from the local SwiftData store.
    private func deleteLocalObjects() throws {
        // Iterate through each model type in the schema and delete all instances.
        try context.transaction {
            let trackables = try context.fetch(FetchDescriptor<Trackable>())
            trackables.forEach(context.delete)

            let folders = try context.fetch(FetchDescriptor<Folder>())
            folders.forEach(context.delete)

            let pages = try context.fetch(FetchDescriptor<NotePage>())
            pages.forEach(context.delete)

            let interventions = try context.fetch(FetchDescriptor<Intervention>())
            interventions.forEach(context.delete)

            let situations = try context.fetch(FetchDescriptor<Situation>())
            situations.forEach(context.delete)

            let curated = try context.fetch(FetchDescriptor<DailyCuratedNote>())
            curated.forEach(context.delete)
        }
    }

    // MARK: - State
    @State private var showConfirm = false
    @State private var importText: String = ""
    @State private var showingImporter = false
    @State private var importError: Error?
    @State private var exportURL: URL?
    @State private var exportError: Error?
    @State private var importSuccess: Bool = false
}

private func writeTemp(data: Data) throws -> URL {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let dateStr = df.string(from: Date())
    let filename = "PrototypeMeExport-\(dateStr).json"
    let url = FileManager.default.temporaryDirectory.appending(path: filename)
    try data.write(to: url, options: .atomic)
    return url
}

// MARK: - Import helpers
extension SettingsView {
    private func importFromText() {
        guard let data = importText.data(using: .utf8) else { return }
        Task { await performImport(data: data) }
    }

    private func performImport(data: Data) async {
        do {
            try DataImporter.import(data: data, into: context)
            importText = ""
            importError = nil
            importSuccess = true
        } catch {
            importError = error
            importSuccess = false
        }
    }

    private var reminderDate: Date {
        let midnight = Calendar.current.startOfDay(for: Date())
        let clamped = max(0, min(86340, dailyReminderTime))
        return midnight.addingTimeInterval(clamped)
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding<Date>(
            get: { reminderDate },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let seconds = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
                dailyReminderTime = max(0, min(86340, seconds))
            }
        )
    }

    private func formattedReminderTime() -> String {
        Self.timeFormatter.string(from: reminderDate)
    }

    @MainActor
    private func updateDailyReminder(enabled: Bool) async {
        if enabled {
            let granted = await NotificationScheduler.requestAuthorization()
            if granted {
                await NotificationScheduler.scheduleDailyReminder(at: reminderDate)
                notificationMessage = "Daily reminder set for \(formattedReminderTime())."
            } else {
                dailyReminderEnabled = false
                notificationMessage = "Notifications are disabled. Turn them on in iOS Settings."
                showNotificationAlert = true
            }
        } else {
            await NotificationScheduler.cancelDailyReminder()
            notificationMessage = "Daily reminder turned off."
        }
    }

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }()
}
