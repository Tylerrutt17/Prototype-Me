import UIKit

class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []

    private let window: UIWindow
    private let environment: AppEnvironment
    private let tabBarController: UITabBarController
    private var focusCoordinator: FocusCoordinator?

    init(window: UIWindow, environment: AppEnvironment) {
        self.window = window
        self.environment = environment
        self.tabBarController = UITabBarController()
    }

    func start() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if hasCompleted {
            // Already onboarded — check if signed in
            if environment.authService.isSignedIn {
                showMainApp(animated: false)
            } else {
                showLogin(animated: false)
            }
        } else {
            showWelcome()
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
            try? await self?.environment.syncEngine.seedFullPush()
            try? await self?.environment.syncEngine.sync()
        }
        syncVC.onComplete = { [weak self] in
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
        let journalCoordinator = JournalCoordinator(environment: environment)
        let settingsCoordinator = SettingsCoordinator(environment: environment)

        focusCoordinator.onFreshStartRequested = { [weak self] in
            self?.showWelcome()
        }
        settingsCoordinator.onReplayTourRequested = { [weak self] in
            self?.startGuidedTour()
        }

        let coordinators: [Coordinator] = [
            focusCoordinator,
            notesCoordinator,
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
