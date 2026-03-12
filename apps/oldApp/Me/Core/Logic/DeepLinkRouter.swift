import Foundation
import Combine
import UserNotifications

/// Simple shared router for deep links triggered by notifications or URLs.
final class DeepLinkRouter: ObservableObject {
    /// When set, the UI should navigate to the matching directive.
    @Published var targetInterventionId: String? = nil

    func route(to interventionId: String) {
        targetInterventionId = interventionId
    }

    func consumeInterventionLink() {
        targetInterventionId = nil
    }
}

// MARK: - Notification delegate to capture taps
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    private weak var router: DeepLinkRouter?

    init(router: DeepLinkRouter) {
        self.router = router
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let directiveId = response.notification.request.content.userInfo["directiveId"] as? String {
            router?.route(to: directiveId)
        }
        completionHandler()
    }
}

