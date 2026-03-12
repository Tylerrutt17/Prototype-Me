import UIKit

class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let environment: AppEnvironment
    private let tabBarController: UITabBarController

    init(window: UIWindow, environment: AppEnvironment) {
        self.window = window
        self.environment = environment
        self.tabBarController = UITabBarController()
    }

    func start() {
        let focusCoordinator = FocusCoordinator(environment: environment)
        let notesCoordinator = NotesCoordinator(environment: environment)
        let playbooksCoordinator = PlaybooksCoordinator(environment: environment)
        let diaryCoordinator = DiaryCoordinator(environment: environment)
        let settingsCoordinator = SettingsCoordinator(environment: environment)

        let coordinators: [Coordinator] = [
            focusCoordinator,
            notesCoordinator,
            playbooksCoordinator,
            diaryCoordinator,
            settingsCoordinator
        ]

        coordinators.forEach { coordinator in
            addChild(coordinator)
            coordinator.start()
        }

        tabBarController.viewControllers = [
            focusCoordinator.navigationController,
            notesCoordinator.navigationController,
            playbooksCoordinator.navigationController,
            diaryCoordinator.navigationController,
            settingsCoordinator.navigationController
        ]

        tabBarController.selectedIndex = 0

        window.rootViewController = tabBarController
    }
}
