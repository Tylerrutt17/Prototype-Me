import Foundation
import UserNotifications
import GRDB

/// Manages local push notifications for balloon expiry on directives.
final class BalloonNotificationService: NSObject, UNUserNotificationCenterDelegate {

    private let center = UNUserNotificationCenter.current()

    /// Set by AppCoordinator — called with the directive UUID when the user taps a notification.
    var onNotificationTapped: ((UUID) -> Void)?

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permissions

    /// Requests notification authorization if not yet determined.
    /// Call when the user first enables a balloon.
    func requestPermissionIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: - Scheduling

    /// Schedules (or reschedules) a local notification for when a balloon expires.
    func scheduleBalloonNotification(for directive: Directive) {
        guard directive.balloonEnabled, directive.balloonDurationSec > 0 else {
            cancelBalloonNotification(directiveId: directive.id)
            return
        }

        let remaining = directive.liveRemainingSec
        guard remaining > 0 else { return }

        // Cancel any existing notification for this directive
        center.removePendingNotificationRequests(withIdentifiers: [directive.id.uuidString])

        let content = UNMutableNotificationContent()
        content.title = "Balloon Expired"
        content.body = "\"\(directive.title)\" needs your attention — the balloon has run out of air."
        content.sound = .default
        content.userInfo = ["directiveId": directive.id.uuidString]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(
            identifier: directive.id.uuidString,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Cancels a pending notification for a specific directive.
    func cancelBalloonNotification(directiveId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [directiveId.uuidString])
    }

    /// Reschedules all active balloon notifications.
    /// Call on foreground entry to correct for clock drift.
    func rescheduleAll(dbQueue: DatabaseQueue) {
        do {
            let directives = try dbQueue.read { db in
                try Directive
                    .filter(Column("balloonEnabled") == true && Column("status") == DirectiveStatus.active.rawValue)
                    .fetchAll(db)
            }
            guard !directives.isEmpty else { return }

            // Ensure we have permission if there are active balloons
            requestPermissionIfNeeded()

            let ids = directives.map { $0.id.uuidString }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            for directive in directives {
                scheduleBalloonNotification(for: directive)
            }
        } catch {}
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["directiveId"] as? String,
           let directiveId = UUID(uuidString: idString) {
            DispatchQueue.main.async {
                self.onNotificationTapped?(directiveId)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
