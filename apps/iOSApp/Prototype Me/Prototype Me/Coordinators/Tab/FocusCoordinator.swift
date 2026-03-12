import UIKit

class FocusCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Focus",
            image: UIImage(systemName: "scope"),
            selectedImage: UIImage(systemName: "scope")
        )
    }

    func start() {
        let vc = FocusViewController()
        vc.onModeSelected = { [weak self] noteId in
            self?.showNoteDetail(noteId: noteId)
        }
        vc.onBalloonSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        navigationController.viewControllers = [vc]
    }

    private func showNoteDetail(noteId: UUID) {
        let vc = NoteDetailViewController()
        vc.noteId = noteId
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showDirectiveDetail(directiveId: UUID) {
        let vc = DirectiveDetailViewController()
        vc.directiveId = directiveId
        navigationController.pushViewController(vc, animated: true)
    }
}
