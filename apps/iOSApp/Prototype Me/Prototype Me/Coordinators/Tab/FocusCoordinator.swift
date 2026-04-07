import UIKit

class FocusCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onFreshStartRequested: (() -> Void)?
    var onAskAIForDirective: ((UUID) -> Void)?
    var onAskAISuggestion: ((String) -> Void)?
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
        vc.dbQueue = environment.db.dbQueue
        vc.balloonNotificationService = environment.balloonNotificationService
        vc.modeService = environment.modeService
        vc.onModeSelected = { [weak self] noteId in
            self?.showModeDetail(noteId: noteId)
        }
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onBalloonSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onViewAllBalloonsTapped = { [weak self] in
            self?.showBalloons()
        }
        vc.onPickModesTapped = { [weak self] in
            self?.presentActiveModePicker()
        }
        vc.onReplayOnboardingTapped = { [weak self] in
            self?.presentOnboardingPreview()
        }
        navigationController.viewControllers = [vc]
    }

    private func showModeDetail(noteId: UUID) {
        let vc = ModeDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.modeService = environment.modeService
        vc.noteService = environment.noteService
        vc.noteId = noteId
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        vc.onEditTapped = { [weak self] noteId in
            self?.presentNoteEditor(noteId: noteId)
        }
        vc.onLinkDirectiveTapped = { [weak self] noteId in
            self?.presentDirectivePicker(forNoteId: noteId)
        }
        vc.onAskAIForDirective = { [weak self] directiveId in
            self?.onAskAIForDirective?(directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showBalloons() {
        let vc = BalloonsViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.balloonNotificationService = environment.balloonNotificationService
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    func showDirectiveDetail(directiveId: UUID, fromNotification: Bool = false) {
        let vc = DirectiveDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.directiveId = directiveId
        vc.balloonNotificationService = environment.balloonNotificationService
        vc.fromNotification = fromNotification
        vc.onEditTapped = { [weak self] directiveId in
            self?.presentDirectiveEditor(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    // MARK: - Modal Editors

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
                self?.onAskAISuggestion?(problemText)
            }
        }
        let nav = UINavigationController(rootViewController: editor)
        navigationController.present(nav, animated: true)
    }

    private func presentDirectivePicker(forNoteId noteId: UUID) {
        let picker = DirectivePickerViewController()
        picker.dbQueue = environment.db.dbQueue
        picker.noteService = environment.noteService
        picker.directiveService = environment.directiveService
        picker.noteId = noteId
        picker.onDirectiveLinked = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: picker)
        navigationController.present(nav, animated: true)
    }

    private func presentPaywall() {
        let vc = PaywallViewController()
        vc.purchaseService = environment.purchaseService
        vc.onDismiss = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .fullScreen
        navigationController.present(vc, animated: true)
    }

    private var onboardingCoordinator: OnboardingCoordinator?

    private func presentOnboardingPreview() {
        // Full fresh start: clear onboarding, sign out, restart at welcome screen
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        environment.authService.signOut()
        onFreshStartRequested?()
    }

    private func presentActiveModePicker() {
        let picker = ActiveModePickerViewController()
        picker.dbQueue = environment.db.dbQueue
        picker.modeService = environment.modeService
        picker.onDone = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: picker)
        navigationController.present(nav, animated: true)
    }
}
