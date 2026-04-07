import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The app environment. Nil if database initialization failed — SceneDelegate
    /// checks this and shows a recovery screen instead of the main app.
    private(set) var environment: AppEnvironment!
    private(set) var dbInitError: Error?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureGlobalAppearance()

        do {
            let env = try AppEnvironment.live()
            self.environment = env

            // Notification delegate must be set before app finishes launching
            UNUserNotificationCenter.current().delegate = env.balloonNotificationService

            // Seed sample data on first launch (no-op if DB already has data)
            try? DatabaseSeeder.seedIfNeeded(db: env.db)

            // Ensure all active balloon notifications are scheduled on launch
            env.balloonNotificationService.rescheduleAll(dbQueue: env.db.dbQueue)
        } catch {
            self.dbInitError = error
            print("[App] Database initialization failed: \(error)")
        }

        return true
    }

    /// Called by SceneDelegate when the recovery screen successfully retries initialization.
    func setRecoveredEnvironment(_ env: AppEnvironment) {
        self.environment = env
        self.dbInitError = nil
        UNUserNotificationCenter.current().delegate = env.balloonNotificationService
        try? DatabaseSeeder.seedIfNeeded(db: env.db)
        env.balloonNotificationService.rescheduleAll(dbQueue: env.db.dbQueue)
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}

    // MARK: - Global Appearance

    private func configureGlobalAppearance() {
        // Navigation bar
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = DesignTokens.Colors.background
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: DesignTokens.Colors.textPrimary
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: DesignTokens.Colors.textPrimary
        ]
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = DesignTokens.Colors.accent

        // Tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = DesignTokens.Colors.tabBarBackground
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = DesignTokens.Colors.tabBarSelected
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: DesignTokens.Colors.tabBarSelected
        ]
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = DesignTokens.Colors.tabBarUnselected
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: DesignTokens.Colors.tabBarUnselected
        ]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
