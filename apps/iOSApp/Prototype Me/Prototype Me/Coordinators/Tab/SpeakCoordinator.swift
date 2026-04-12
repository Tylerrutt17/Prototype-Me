import UIKit

class SpeakCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Ask",
            image: UIImage(systemName: "waveform.circle"),
            selectedImage: UIImage(systemName: "waveform.circle.fill")
        )
    }

    func start() {
        let vc = SpeakViewController()
        vc.apiClient = environment.apiClient
        vc.aiReadQueryService = environment.aiReadQueryService
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
        vc.onAddDirectiveSuggestion = { [weak self] title, body in
            self?.presentDirectiveEditorWithSuggestion(title: title, body: body)
        }
        vc.onAddNoteSuggestion = { [weak self] title, body in
            self?.presentNoteEditorWithSuggestion(title: title, body: body)
        }
        vc.onAddJournalSuggestion = { [weak self] date, rating, diary, tags in
            self?.presentJournalEditorWithSuggestion(date: date, rating: rating, diary: diary, tags: tags)
        }
        vc.onEditDirective = { [weak self] id, title, body in
            self?.presentDirectiveEditorForUpdate(id: id, title: title, body: body)
        }
        vc.onEditNote = { [weak self] id, title, body in
            self?.presentNoteEditorForUpdate(id: id, title: title, body: body)
        }
        vc.onEditJournal = { [weak self] date, rating, diary, tags in
            self?.presentJournalEditorWithSuggestion(date: date, rating: rating, diary: diary, tags: tags)
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
        editor.onAskAISuggestion = { [weak self] problemText in
            self?.navigationController.dismiss(animated: true) {
                // Already on Speak tab — send directly
                guard let speakVC = self?.navigationController.viewControllers.first as? SpeakViewController else { return }
                self?.navigationController.popToRootViewController(animated: false)
                guard !speakVC.isProcessing else { return }
                let prompt = "I need help with: \(problemText). Suggest up to 3 directives I could try. Use the create_directive tool for each one so I can pick which to add."
                speakVC.showThinkingContext("Suggesting directives")
                speakVC.sendMessage(prompt)
            }
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private var speakVC: SpeakViewController? {
        navigationController.viewControllers.first as? SpeakViewController
    }

    private func dismissAndMarkApplied() {
        navigationController.dismiss(animated: true) { [weak self] in
            self?.speakVC?.markSuggestionApplied()
        }
    }

    private func presentDirectiveEditorWithSuggestion(title: String, body: String?) {
        let editor = DirectiveEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.directiveService = environment.directiveService
        editor.balloonNotificationService = environment.balloonNotificationService
        editor.apiClient = environment.apiClient
        editor.prefillTitle = title
        editor.prefillBody = body
        editor.onSave = { [weak self] in self?.dismissAndMarkApplied() }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentNoteEditorWithSuggestion(title: String, body: String?) {
        let editor = NoteEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.noteService = environment.noteService
        editor.prefillTitle = title
        editor.prefillBody = body
        editor.onSave = { [weak self] in self?.dismissAndMarkApplied() }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentNoteEditorForUpdate(id: UUID, title: String?, body: String?) {
        let editor = NoteEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.noteService = environment.noteService
        editor.noteId = id
        editor.prefillTitle = title
        editor.prefillBody = body
        editor.onSave = { [weak self] in self?.dismissAndMarkApplied() }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentJournalEditorWithSuggestion(date: String, rating: Int?, diary: String?, tags: [String]?) {
        let editor = DayEntryEditorViewController()
        editor.dayEntryService = environment.dayEntryService
        editor.dbQueue = environment.db.dbQueue
        editor.preselectedDate = date
        editor.prefillRating = rating
        editor.prefillDiary = diary
        editor.prefillTags = tags
        Task {
            if let existing = try? await environment.dayEntryService.fetch(date: date) {
                await MainActor.run { editor.entryId = existing.id }
            }
            await MainActor.run {
                editor.onSave = { [weak self] in self?.dismissAndMarkApplied() }
                let nav = UINavigationController(rootViewController: editor)
                self.navigationController.present(nav, animated: true)
            }
        }
    }

    private func presentDirectiveEditorForUpdate(id: UUID, title: String?, body: String?) {
        let editor = DirectiveEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.directiveService = environment.directiveService
        editor.balloonNotificationService = environment.balloonNotificationService
        editor.apiClient = environment.apiClient
        editor.directiveId = id
        editor.prefillTitle = title
        editor.prefillBody = body
        editor.onSave = { [weak self] in self?.dismissAndMarkApplied() }
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
