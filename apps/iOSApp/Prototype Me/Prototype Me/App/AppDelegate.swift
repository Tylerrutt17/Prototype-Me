import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    let environment = AppEnvironment.stub()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        configureGlobalAppearance()
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
