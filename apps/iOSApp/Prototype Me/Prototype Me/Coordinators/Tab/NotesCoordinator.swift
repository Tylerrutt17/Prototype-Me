import UIKit

class NotesCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Notes",
            image: UIImage(systemName: "doc.text"),
            selectedImage: UIImage(systemName: "doc.text.fill")
        )
    }

    func start() {
        let vc = NoteListViewController()
        vc.onNoteSelected = { [weak self] noteId in
            self?.showNoteDetail(noteId: noteId)
        }
        vc.onDirectivesTapped = { [weak self] in
            self?.showDirectiveList()
        }
        vc.onBalloonsTapped = { [weak self] in
            self?.showBalloons()
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

    private func showDirectiveList() {
        let vc = DirectiveListViewController()
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

    private func showBalloons() {
        let vc = BalloonsViewController()
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }
}
