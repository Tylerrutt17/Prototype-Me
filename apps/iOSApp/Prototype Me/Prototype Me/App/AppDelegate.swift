import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // Force-try is acceptable at app launch — if the DB can't open, the app can't function.
    // swiftlint:disable:next force_try
    let environment = try! AppEnvironment.live()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureGlobalAppearance()

        // Notification delegate must be set before app finishes launching
        UNUserNotificationCenter.current().delegate = environment.balloonNotificationService

        // Seed sample data on first launch (no-op if DB already has data)
        try? DatabaseSeeder.seedIfNeeded(db: environment.db)

        // Ensure all active balloon notifications are scheduled on launch
        environment.balloonNotificationService.rescheduleAll(dbQueue: environment.db.dbQueue)

        return true
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
