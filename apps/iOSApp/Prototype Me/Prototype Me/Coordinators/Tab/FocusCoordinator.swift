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
        vc.dbQueue = environment.db.dbQueue
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
        vc.onAITapped = { [weak self] in
            self?.presentAIPanel()
        }
        vc.onReplayOnboardingTapped = { [weak self] in
            self?.presentOnboardingPreview()
        }
        navigationController.viewControllers = [vc]
    }

    private func showModeDetail(noteId: UUID) {
        let vc = ModeDetailViewController()
        vc.dbQueue = environment.db.dbQueue
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
        navigationController.pushViewController(vc, animated: true)
    }

    private func showBalloons() {
        let vc = BalloonsViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.onDirectiveSelected = { [weak self] directiveId in
            self?.showDirectiveDetail(directiveId: directiveId)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showDirectiveDetail(directiveId: UUID) {
        let vc = DirectiveDetailViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.directiveId = directiveId
        vc.onEditTapped = { [weak self] directiveId in
            self?.presentDirectiveEditor(directiveId: directiveId)
        }
        vc.onAddScheduleTapped = { [weak self] directiveId in
            self?.presentScheduleEditor(directiveId: directiveId)
        }
        vc.onEditScheduleTapped = { [weak self] directiveId, rule in
            self?.presentScheduleEditor(directiveId: directiveId, existingRule: rule)
        }
        navigationController.pushViewController(vc, animated: true)
    }

    private func presentScheduleEditor(directiveId: UUID, existingRule: ScheduleRule? = nil) {
        let editor = ScheduleRuleEditorViewController()
        editor.dbQueue = environment.db.dbQueue
        editor.directiveId = directiveId
        editor.existingRule = existingRule
        editor.onSave = { [weak editor] in
            editor?.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: editor)
        nav.isNavigationBarHidden = true
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        navigationController.present(nav, animated: true)
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
        editor.directiveId = directiveId
        editor.onSave = { [weak self] in
            self?.navigationController.dismiss(animated: true)
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

    // MARK: - AI Panel

    private func presentAIPanel() {
        let panel = AIPanelViewController()
        panel.initialQuota = SampleData.usageQuota  // TODO: fetch from API/cache
        panel.onChipSelected = { [weak self] chip in
            self?.presentChipConfirm(chip: chip)
        }
        panel.onUpgradeTapped = { [weak self] in
            self?.navigationController.dismiss(animated: true) {
                self?.presentPaywall()
            }
        }
        panel.onDismissed = { [weak self] in
            _ = self // Dismiss tracking — will wire to service layer later
        }

        // Present as page sheet with medium detent
        if let sheet = panel.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = false // custom grabber in VC
            sheet.preferredCornerRadius = DesignTokens.Radii.xl
        }
        navigationController.present(panel, animated: true)
    }

    private func presentChipConfirm(chip: AiChip) {
        let vc = ChipConfirmViewController()
        vc.chip = chip
        vc.onConfirm = { [weak self] acceptedChip in
            // Will wire to service layer later to create/update entities
            _ = acceptedChip
            self?.navigationController.dismiss(animated: true)
        }
        vc.onCancel = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: vc)
        navigationController.presentedViewController?.present(nav, animated: true)
    }

    private func presentPaywall() {
        let vc = PaywallViewController()
        vc.onDismiss = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        vc.onRestore = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .fullScreen
        navigationController.present(vc, animated: true)
    }

    private var onboardingCoordinator: OnboardingCoordinator?

    private func presentOnboardingPreview() {
        // Reset the flag so it can be replayed freely
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        let coordinator = OnboardingCoordinator(environment: environment)
        coordinator.onComplete = { [weak self] in
            self?.navigationController.dismiss(animated: true)
            self?.onboardingCoordinator = nil
        }
        coordinator.start()
        onboardingCoordinator = coordinator
        navigationController.present(coordinator.navigationController, animated: true)
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
