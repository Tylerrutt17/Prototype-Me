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
        vc.noteService = environment.noteService
        vc.dayEntryService = environment.dayEntryService
        vc.modeService = environment.modeService
        vc.folderService = environment.folderService
        vc.speakHistoryService = environment.speakHistoryService
        vc.dbQueue = environment.db.dbQueue
        vc.onUpgradeTapped = { [weak self] in
            self?.presentPaywall()
        }
        vc.onNavigateToDirective = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onNavigateToNote = { [weak self] noteId in
            self?.showNoteDetail(noteId: noteId)
        }
        vc.onNavigateToJournal = { [weak self] date in
            self?.showJournalEditor(date: date)
        }
        navigationController.viewControllers = [vc]
    }

    // MARK: - Navigation

    private func showDirectiveDetail(directiveId: UUID) {
        let vc = DirectiveDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.directiveId = directiveId
        vc.balloonNotificationService = environment.balloonNotificationService
        vc.onEditTapped = { [weak self] directiveId in
            self?.presentDirectiveEditor(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showNoteDetail(noteId: UUID) {
        let vc = NoteDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.noteId = noteId
        vc.noteService = environment.noteService
        vc.onEditTapped = { [weak self] noteId in
            self?.presentNoteEditor(noteId: noteId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showJournalEditor(date: String) {
        let editor = DayEntryEditorViewController()
        editor.preselectedDate = date
        editor.dayEntryService = environment.dayEntryService
        editor.dbQueue = environment.db.dbQueue
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    // MARK: - Modal Editors

    private func presentDirectiveEditor(directiveId: UUID?) {
        let editor = DirectiveEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.directiveService = environment.directiveService
        editor.balloonNotificationService = environment.balloonNotificationService
        editor.apiClient = environment.apiClient
        editor.directiveId = directiveId
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentNoteEditor(noteId: UUID?) {
        let editor = NoteEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.noteService = environment.noteService
        editor.noteId = noteId
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
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
