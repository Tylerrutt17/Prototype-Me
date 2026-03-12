import UIKit

class PlaybooksCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Playbooks",
            image: UIImage(systemName: "book.closed"),
            selectedImage: UIImage(systemName: "book.closed.fill")
        )
    }

    func start() {
        let vc = PlaybookListViewController()
        vc.onPlaybookSelected = { [weak self] folderId in
            self?.showPlaybookDetail(folderId: folderId)
        }
        navigationController.viewControllers = [vc]
    }

    private func showPlaybookDetail(folderId: UUID) {
        let vc = PlaybookDetailViewController()
        vc.folderId = folderId
        vc.onNoteSelected = { [weak self] noteId in
            self?.showNoteDetail(noteId: noteId)
        }
        navigationController.pushViewController(vc, animated: true)
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
