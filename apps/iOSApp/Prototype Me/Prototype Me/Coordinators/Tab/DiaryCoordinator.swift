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
        vc.dbQueue = environment.db.dbQueue
        vc.dayEntryService = environment.dayEntryService
        vc.onAddTapped = { [weak self] in
            self?.presentDayEntryEditor(entryId: nil)
        }
        vc.onEntrySelected = { [weak self] entryId in
            self?.presentDayEntryEditor(entryId: entryId)
        }
        vc.onHistoryTapped = { [weak self] in
            self?.showHistory()
        }
        // Calendar (embedded as child VC)
        vc.onEditEntry = { [weak self] entryId in
            self?.presentDayEntryEditor(entryId: entryId)
        }
        vc.onCreateEntry = { [weak self] dateString in
            self?.presentDayEntryEditor(entryId: nil, dateString: dateString)
        }
        navigationController.viewControllers = [vc]
    }

    private func showHistory() {
        let vc = HistoryViewController()
        vc.dbQueue = environment.db.dbQueue
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Modal Editors

    private func presentDayEntryEditor(entryId: UUID?, dateString: String? = nil) {
        let editor = DayEntryEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.dayEntryService = environment.dayEntryService
        editor.entryId = entryId
        editor.preselectedDate = dateString
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }
}
