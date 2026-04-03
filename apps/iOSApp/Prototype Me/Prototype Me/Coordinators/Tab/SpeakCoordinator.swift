import UIKit

class SpeakCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Speak",
            image: UIImage(systemName: "waveform.circle"),
            selectedImage: UIImage(systemName: "waveform.circle.fill")
        )
    }

    func start() {
        let vc = SpeakViewController()
        vc.apiClient = environment.apiClient
        vc.directiveService = environment.directiveService
        vc.dbQueue = environment.db.dbQueue
        vc.onUpgradeTapped = { [weak self] in
            self?.presentPaywall()
        }
        navigationController.viewControllers = [vc]
    }

    private func presentPaywall() {
        let vc = PaywallViewController()
        vc.purchaseService = environment.purchaseService
        vc.onDismiss = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        navigationController.present(nav, animated: true)
    }
}
