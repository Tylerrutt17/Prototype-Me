import UIKit

class SettingsCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
    }

    func start() {
        let vc = SettingsViewController()
        vc.onSyncDebugTapped = { [weak self] in
            self?.showSyncDebug()
        }
        navigationController.viewControllers = [vc]
    }

    private func showSyncDebug() {
        let vc = SyncDebugViewController()
        navigationController.pushViewController(vc, animated: true)
    }
}
