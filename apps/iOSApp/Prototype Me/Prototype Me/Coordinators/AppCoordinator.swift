import UIKit
import GRDB

class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let environment: AppEnvironment
    private let tabBarController: UITabBarController
    private var focusCoordinator: FocusCoordinator?
    private var speakCoordinator: SpeakCoordinator?

    init(window: UIWindow, environment: AppEnvironment) {
        self.window = window
        self.environment = environment
        self.tabBarController = UITabBarController()
    }

    func start() {
        // Listen for session expiry — redirect to login when tokens expire
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSessionExpired),
            name: .authSessionExpired, object: nil
        )

        // Listen for 426 Upgrade Required — block sync until app is updated
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleSyncUpgradeRequired),
            name: .syncUpgradeRequired, object: nil
        )

        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if hasCompleted {
            // Already onboarded — check if signed in
            if environment.authService.isSignedIn {
                showMainApp(animated: false)
                // Refresh plan from server in background
                Task { await environment.authService.refreshPlan() }

                // If user closed the app before completing sync choice, show it again
                if PurchaseService.hasPendingSyncChoice {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.showSyncChoice()
                    }
                }
            } else {
                showLogin(animated: false)
            }
        } else {
            showWelcome()
        }
    }

    @objc private func handleSyncUpgradeRequired() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            print("[AppCoordinator] syncUpgradeRequired received")

            // Dismiss any existing modal first, then present update screen
            let presenter = self.tabBarController.presentedViewController != nil ? self.tabBarController : self.tabBarController
            if presenter.presentedViewController is UpdateRequiredViewController { return }

            let present = { [weak self] in
                guard let self else { return }
                let vc = UpdateRequiredViewController()
                vc.modalPresentationStyle = .fullScreen
                self.tabBarController.present(vc, animated: true)
            }

            if let existing = self.tabBarController.presentedViewController {
                existing.dismiss(animated: false) { present() }
            } else {
                present()
            }
        }
    }

    @objc private func handleSessionExpired() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Dismiss any modals
            self.tabBarController.presentedViewController?.dismiss(animated: false)
            // Show login screen
            self.showLogin(animated: true)
        }
    }

    // MARK: - Welcome (pre-onboarding)

    private func showWelcome() {
        let welcomeVC = WelcomeLoginViewController()
        welcomeVC.authService = environment.authService
        welcomeVC.onSignedIn = { [weak self] isNewUser in
            if isNewUser {
                self?.showOnboarding()
            } else {
                self?.showSyncLoading()
            }
        }
        window.rootViewController = welcomeVC
    }

    // MARK: - Sync Loading (Returning Users)

    private func showSyncLoading() {
        let syncVC = SyncLoadingViewController()
        syncVC.syncTask = { [weak self] in
            try await self?.environment.syncEngine.pull()
        }
        syncVC.onComplete = { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            self?.showMainApp(animated: true)
        }
        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve) {
            self.window.rootViewController = syncVC
        }
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let onboardingCoordinator = OnboardingCoordinator(window: window, environment: environment)
        onboardingCoordinator.onComplete = { [weak self] in
            guard let self else { return }
            self.removeChild(onboardingCoordinator)
            self.showLogin(animated: true)
        }
        addChild(onboardingCoordinator)
        onboardingCoordinator.start()
    }

    // MARK: - Login

    private func showLogin(animated: Bool) {
        // If already signed in, skip straight to main app
        if environment.authService.isSignedIn {
            showMainApp(animated: animated)
            return
        }

        let loginVC = LoginViewController()
        loginVC.authService = environment.authService
        loginVC.onLoginSuccess = { [weak self] in
            guard let self else { return }
            self.showSyncLoading()
        }
        if animated {
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve) {
                self.window.rootViewController = loginVC
            }
        } else {
            window.rootViewController = loginVC
        }
    }

    // MARK: - Main App

    private func showMainApp(animated: Bool) {
        let focusCoordinator = FocusCoordinator(environment: environment)
        self.focusCoordinator = focusCoordinator
        let notesCoordinator = NotesCoordinator(environment: environment)
        let speakCoordinator = SpeakCoordinator(environment: environment)
        self.speakCoordinator = speakCoordinator
        let journalCoordinator = JournalCoordinator(environment: environment)
        let settingsCoordinator = SettingsCoordinator(environment: environment)

        focusCoordinator.onFreshStartRequested = { [weak self] in
            self?.showWelcome()
        }
        focusCoordinator.onAskAIForDirective = { [weak self] directiveId in
            self?.askAIAboutDirective(directiveId: directiveId)
        }
        focusCoordinator.onAskAISuggestion = { [weak self] problemText in
            self?.askAIForDirectiveSuggestion(problemText: problemText)
        }
        notesCoordinator.onAskAIForDirective = { [weak self] directiveId in
            self?.askAIAboutDirective(directiveId: directiveId)
        }
        notesCoordinator.onAskAISuggestion = { [weak self] problemText in
            self?.askAIForDirectiveSuggestion(problemText: problemText)
        }
        settingsCoordinator.onReplayTourRequested = { [weak self] in
            self?.startGuidedTour()
        }

        let coordinators: [Coordinator] = [
            focusCoordinator,
            notesCoordinator,
            speakCoordinator,
            journalCoordinator,
            settingsCoordinator
        ]

        coordinators.forEach { coordinator in
            addChild(coordinator)
            coordinator.start()
        }

        tabBarController.viewControllers = [
            focusCoordinator.navigationController,
            notesCoordinator.navigationController,
            speakCoordinator.navigationController,
            journalCoordinator.navigationController,
            settingsCoordinator.navigationController
        ]

        tabBarController.selectedIndex = 0

        if animated {
            UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve) {
                self.window.rootViewController = self.tabBarController
            }
        } else {
            window.rootViewController = tabBarController
        }

        // Link RevenueCat to our backend user
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            Task { try? await environment.purchaseService.identify(userId: userId) }
        }

        // Wire balloon notification deep link
        environment.balloonNotificationService.onNotificationTapped = { [weak self] directiveId in
            self?.navigateToDirective(directiveId: directiveId)
        }
    }

    // MARK: - Deep Link

    func navigateToDirective(directiveId: UUID) {
        guard let focusCoordinator else { return }
        // Dismiss any presented modal
        if let presented = tabBarController.presentedViewController {
            presented.dismiss(animated: false)
        }
        tabBarController.selectedIndex = 0
        focusCoordinator.navigationController.popToRootViewController(animated: false)
        focusCoordinator.showDirectiveDetail(directiveId: directiveId, fromNotification: true)
    }

    // MARK: - Ask AI About Directive

    private func askAIAboutDirective(directiveId: UUID) {
        guard let speakCoordinator,
              let speakVC = speakCoordinator.navigationController.viewControllers.first as? SpeakViewController
        else { return }

        // Fetch directive title (double-optional: try? + optional chain)
        let titleOpt = (try? environment.db.dbQueue.read { db in
            try Directive.fetchOne(db, key: directiveId)?.title
        }) ?? nil
        guard let title = titleOpt, !title.isEmpty else { return }

        // Dismiss any presented modal, pop Speak to root, switch tabs
        if let presented = tabBarController.presentedViewController {
            presented.dismiss(animated: false)
        }
        speakCoordinator.navigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = 2

        let prompt = "The directive \"\(title)\" isn't working for me. Can you help me figure out what's going wrong and suggest an alternative approach?"

        // Wait one runloop tick so the Speak tab's view is loaded before sending
        DispatchQueue.main.async {
            guard !speakVC.isProcessing else { return }
            speakVC.showThinkingContext("Finding an alternative for \u{201C}\(title)\u{201D}")
            speakVC.sendMessage(prompt)
        }
    }

    // MARK: - Ask AI for Directive Suggestions

    private func askAIForDirectiveSuggestion(problemText: String) {
        guard let speakCoordinator,
              let speakVC = speakCoordinator.navigationController.viewControllers.first as? SpeakViewController
        else { return }

        // Dismiss any presented modal, pop Speak to root, switch tabs
        if let presented = tabBarController.presentedViewController {
            presented.dismiss(animated: false)
        }
        speakCoordinator.navigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = 2

        let prompt = "I need help with: \(problemText). Suggest up to 3 directives I could try. Use the create_directive tool for each one so I can pick which to add."

        DispatchQueue.main.async {
            guard !speakVC.isProcessing else { return }
            speakVC.showThinkingContext("Suggesting directives")
            speakVC.sendMessage(prompt)
        }
    }

    // MARK: - Sync Choice

    private func showSyncChoice() {
        let vc = SyncChoiceViewController()
        vc.apiClient = environment.apiClient
        vc.dbQueue = environment.db.dbQueue
        vc.onChoice = { [weak self] direction in
            guard let self else { return }

            let loadingVC = SyncLoadingViewController()
            loadingVC.syncTask = {
                switch direction {
                case .useCloud:
                    await self.environment.purchaseService.pullFromCloud()
                case .useDevice:
                    await self.environment.purchaseService.seedFullPush()
                }
                PurchaseService.clearPendingSyncChoice()
            }
            loadingVC.onComplete = {
                self.tabBarController.dismiss(animated: true)
            }

            let nav = UINavigationController(rootViewController: loadingVC)
            nav.setNavigationBarHidden(true, animated: false)
            nav.modalPresentationStyle = .fullScreen
            vc.present(nav, animated: true)
        }

        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        tabBarController.present(nav, animated: true)
    }

    // MARK: - Guided Tour

    private func startGuidedTour() {
        // Dismiss any presented modal first
        if let presented = tabBarController.presentedViewController {
            presented.dismiss(animated: false) { [weak self] in
                self?.runTour()
            }
        } else {
            runTour()
        }
    }

    private func runTour() {
        let steps = SampleData.coachMarks
        guard !steps.isEmpty else { return }

        // Pop all tabs to root
        for vc in tabBarController.viewControllers ?? [] {
            (vc as? UINavigationController)?.popToRootViewController(animated: false)
        }

        // Switch to first tab
        tabBarController.selectedIndex = steps[0].tabIndex

        var currentIndex = 0

        func showStep(at index: Int) {
            guard index < steps.count else { return }
            let step = steps[index]
            let currentTab = tabBarController.selectedIndex

            if step.tabIndex != currentTab {
                tabBarController.selectedIndex = step.tabIndex
                // Brief delay for the tab's view to layout
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    presentOverlay(for: step, index: index)
                }
            } else {
                presentOverlay(for: step, index: index)
            }
        }

        func presentOverlay(for step: CoachMark, index: Int) {
            let overlay = CoachMarkOverlayView()
            overlay.configure(mark: step, step: index + 1, of: steps.count)
            overlay.onNext = {
                overlay.dismissAnimated {
                    currentIndex += 1
                    if currentIndex < steps.count {
                        showStep(at: currentIndex)
                    }
                }
            }
            overlay.onDismiss = {
                overlay.dismissAnimated()
            }
            overlay.showAnimated(in: self.window)
        }

        showStep(at: 0)
    }
}
