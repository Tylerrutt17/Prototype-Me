import UIKit

class DiaryCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Diary",
            image: UIImage(systemName: "calendar"),
            selectedImage: UIImage(systemName: "calendar")
        )
    }

    func start() {
        let vc = DiaryViewController()
        vc.onCalendarTapped = { [weak self] in
            self?.showCalendar()
        }
        navigationController.viewControllers = [vc]
    }

    private func showCalendar() {
        let vc = CalendarViewController()
        navigationController.pushViewController(vc, animated: true)
    }
}
