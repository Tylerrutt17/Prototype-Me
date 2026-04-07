import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        self.window = window

        if let error = appDelegate.dbInitError {
            // Database failed to initialize — show recovery screen instead of crashing
            showRecoveryScreen(error: error, window: window)
        } else {
            let environment = appDelegate.environment!
            startApp(environment: environment, window: window)
        }

        window.makeKeyAndVisible()
    }

    private func startApp(environment: AppEnvironment, window: UIWindow) {
        let coordinator = AppCoordinator(window: window, environment: environment)
        coordinator.start()
        self.appCoordinator = coordinator
    }

    private func showRecoveryScreen(error: Error, window: UIWindow) {
        let recoveryVC = DatabaseRecoveryViewController(error: error)
        recoveryVC.onRetrySuccess = { [weak self] environment in
            guard let self, let window = self.window else { return }
            // Update AppDelegate's environment so the rest of the app can use it
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.setRecoveredEnvironment(environment)
            self.startApp(environment: environment, window: window)
        }
        window.rootViewController = recoveryVC
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {
        guard let env = (UIApplication.shared.delegate as! AppDelegate).environment else { return }
        env.balloonNotificationService.rescheduleAll(dbQueue: env.db.dbQueue)
        StorageMonitor.checkAndNotify()
    }
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
