import Foundation
import UserNotifications
import SwiftData

/// Centralizes notification permission checks and scheduling for the app.
enum NotificationScheduler {
    private static let dailyIdentifier = "daily-check-in"
    private static let dailyFollowup1Identifier = "daily-check-in-followup-1"
    private static let dailyFollowup2Identifier = "daily-check-in-followup-2"
    private static func directiveCountdownIdentifier(for id: String) -> String { "directive-countdown-\(id)" }
    private static func directiveNextCountdownIdentifier(for id: String) -> String { "directive-countdown-next-\(id)" }
    private static func directiveDailyIdentifier(for id: String) -> String { "directive-daily-\(id)" }

    /// Requests notification authorization, returning the current grant status.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                return granted
            } catch {
                print("⚠️ Notification authorization failed: \(error)")
                return false
            }
        @unknown default:
            return false
        }
    }

    /// Refreshes the daily reminder schedule based on user preferences.
    static func refreshDailyReminder(enabled: Bool, time: Date) async {
        if enabled {
            let granted = await requestAuthorization()
            guard granted else { return }
            await scheduleDailyReminder(at: time)
        } else {
            await cancelDailyReminder()
        }
    }

    /// Creates (or replaces) the daily reminder notification at the given time.
    static func scheduleDailyReminder(at time: Date) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [
            dailyIdentifier,
            dailyFollowup1Identifier,
            dailyFollowup2Identifier
        ])

        var components = Calendar.current.dateComponents([.hour, .minute], from: time)
        components.second = 0

        func scheduleDailyRequest(identifier: String, components: DateComponents, stage: DailyReminderStage) async {
            let content = UNMutableNotificationContent()
            content.title = "Daily check-in"
            content.body = DailyReminderMessages.random(for: stage)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            do {
                try await center.add(request)
            } catch {
                print("⚠️ Failed to schedule daily reminder (\(identifier)): \(error)")
            }
        }

        await scheduleDailyRequest(identifier: dailyIdentifier, components: components, stage: .primary)

        if let plus3 = Calendar.current.date(byAdding: .minute, value: 3, to: time) {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: plus3)
            comps.second = 0
            await scheduleDailyRequest(identifier: dailyFollowup1Identifier, components: comps, stage: .followup1)
        }

        if let plus6 = Calendar.current.date(byAdding: .minute, value: 6, to: time) {
            var comps = Calendar.current.dateComponents([.hour, .minute], from: plus6)
            comps.second = 0
            await scheduleDailyRequest(identifier: dailyFollowup2Identifier, components: comps, stage: .followup2)
        }
    }

    /// Removes the daily reminder notification request if it exists.
    static func cancelDailyReminder() async {
        await UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                dailyIdentifier,
                dailyFollowup1Identifier,
                dailyFollowup2Identifier
            ])
    }

    // MARK: - Directive countdowns
    /// Schedules reminder(s) for a directive countdown. Queues the current cycle and one future cycle so reminders still fire if the app stays closed.
    static func scheduleDirectiveCountdown(id: String, title: String, expiresAt: Date, durationSeconds: TimeInterval) async {
        let interval = expiresAt.timeIntervalSinceNow
        guard interval > 0 else {
            await cancelDirectiveCountdown(id: id)
            return
        }

        let granted = await requestAuthorization()
        guard granted else { return }

        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [
            directiveCountdownIdentifier(for: id),
            directiveNextCountdownIdentifier(for: id)
        ])

        scheduleCycle(for: id,
                      title: title,
                      targetDate: expiresAt,
                      expiryId: directiveCountdownIdentifier(for: id),
                      center: center)

        // Also schedule the next cycle so notifications continue even if the app stays closed.
        // Next cycle starts at the next reset window: at least 24h later, aligned to 9am, then duration added.
        if durationSeconds > 0 {
            let resetStart = nextResetStart(after: expiresAt)
            let nextExpiry = resetStart.addingTimeInterval(durationSeconds)
            scheduleCycle(for: id,
                          title: title,
                          targetDate: resetStart,
                          expiryId: directiveNextCountdownIdentifier(for: id),
                          center: center,
                          durationSeconds: durationSeconds)
        }
    }

    /// Cancels previously scheduled directive countdown reminders.
    static func cancelDirectiveCountdown(id: String) async {
        await UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                directiveCountdownIdentifier(for: id),
                directiveNextCountdownIdentifier(for: id)
            ])
    }

    private static func scheduleCycle(for id: String,
                                      title: String,
                                      targetDate: Date,
                                      expiryId: String,
                                      center: UNUserNotificationCenter,
                                      durationSeconds: TimeInterval? = nil) {
        let interval = targetDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let expiryInterval: TimeInterval
        if let dur = durationSeconds {
            expiryInterval = interval + dur
        } else {
            expiryInterval = interval
        }

        let content = UNMutableNotificationContent()
        content.body = "A balloon is about to deflate. Tap to check in and pump it up."
        content.sound = .default
        content.userInfo = ["directiveId": id]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, expiryInterval), repeats: false)
        let request = UNNotificationRequest(identifier: expiryId, content: content, trigger: trigger)

        try? center.add(request)
    }

    /// Returns the next 9am that is at least 24 hours after the provided date.
    private static func nextResetStart(after date: Date, calendar: Calendar = .current) -> Date {
        let minimum = date.addingTimeInterval(86_400) // 24h later
        var comps = calendar.dateComponents([.year, .month, .day], from: minimum)
        comps.hour = 9
        comps.minute = 0
        comps.second = 0
        var candidate = calendar.date(from: comps) ?? minimum.addingTimeInterval(86_400)
        if candidate < minimum {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86_400)
        }
        return candidate
    }

    // MARK: - Directive daily notifications

    /// Schedules a repeating daily notification for a directive at the given time.
    /// - Parameters:
    ///   - id: The directive's unique id.
    ///   - title: The directive title shown in the notification.
    ///   - timeSeconds: Time of day as seconds since midnight.
    static func scheduleDirectiveDailyNotification(id: String, title: String, timeSeconds: Double) async {
        let granted = await requestAuthorization()
        guard granted else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = directiveDailyIdentifier(for: id)
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let totalSeconds = Int(max(0, min(86340, timeSeconds)))
        var components = DateComponents()
        components.hour = totalSeconds / 3600
        components.minute = (totalSeconds % 3600) / 60
        components.second = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Daily reminder for your directive."
        content.sound = .default
        content.userInfo = ["directiveId": id]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("⚠️ Failed to schedule directive daily notification (\(identifier)): \(error)")
        }
    }

    /// Cancels a previously scheduled directive daily notification.
    static func cancelDirectiveDailyNotification(id: String) async {
        await UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [directiveDailyIdentifier(for: id)])
    }

    /// Re-schedules daily notifications for all directives that have them enabled.
    @MainActor
    static func refreshAllDirectiveDailyNotifications(in context: ModelContext) async {
        let descriptor = FetchDescriptor<Intervention>(predicate: #Predicate { $0.dailyNotificationEnabled == true })
        let interventions = (try? context.fetch(descriptor)) ?? []
        for iv in interventions {
            await scheduleDirectiveDailyNotification(id: iv.id, title: iv.title, timeSeconds: iv.dailyNotificationTime)
        }
    }
}

