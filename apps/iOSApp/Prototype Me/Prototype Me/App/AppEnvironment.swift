import UIKit

/// Dependency container for the app. Real services (GRDB, APIClient, SyncEngine, etc.)
/// will be added here later. For the UI shell, this is a passthrough stub.
struct AppEnvironment {
    // Future:
    // let database: DatabaseManager
    // let apiClient: APIClient
    // let syncEngine: SyncEngine
    // let reachability: ReachabilityMonitor
    // let notificationScheduler: NotificationScheduler
    // let deepLinkRouter: DeepLinkRouter

    static func stub() -> AppEnvironment {
        return AppEnvironment()
    }
}
