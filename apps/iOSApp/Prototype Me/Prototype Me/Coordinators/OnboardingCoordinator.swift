import UIKit

/// Manages the full onboarding flow: Intro → FocusConsole → AI Chat → Seed Review → Welcome.
/// Signals completion via `onComplete` so AppCoordinator can transition to the main app.
class OnboardingCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var onComplete: (() -> Void)?

    private let window: UIWindow?
    private let environment: AppEnvironment
    let navigationController: UINavigationController
    private var isModal = false

    init(window: UIWindow, environment: AppEnvironment) {
        self.window = window
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        navigationController.interactivePopGestureRecognizer?.isEnabled = false
    }

    /// Modal init — for replaying onboarding from within the app.
    init(environment: AppEnvironment) {
        self.window = nil
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        navigationController.interactivePopGestureRecognizer?.isEnabled = false
        navigationController.modalPresentationStyle = .fullScreen
        self.isModal = true
    }

    func start() {
        let intro = IntroPageViewController()
        intro.onFinished = { [weak self] in
            self?.showFocusConsole()
        }
        navigationController.setViewControllers([intro], animated: false)
        if !isModal {
            window?.rootViewController = navigationController
        }
    }

    // MARK: - Flow

    private func showFocusConsole() {
        let vc = FocusConsoleViewController()
        vc.onGetStarted = { [weak self] in
            self?.showAISignupChat()
        }
        crossfadeTo(vc, duration: 0.8)
    }

    private func showAISignupChat() {
        let vc = AISignupChatViewController()
        vc.onSeedPlanReady = { [weak self] cards in
            self?.showSeedPlanReview(cards: cards)
        }
        vc.onSkipped = { [weak self] in
            self?.showWelcome()
        }
        crossfadeTo(vc, duration: 0.6)
    }

    private func showSeedPlanReview(cards: [SeedPlanCard]) {
        let vc = SeedPlanReviewViewController()
        vc.cards = cards
        vc.onConfirmed = { [weak self] in
            self?.showWelcome()
        }
        crossfadeTo(vc, duration: 0.5)
    }

    private func showWelcome() {
        let vc = WelcomeViewController()
        vc.onReady = { [weak self] in
            self?.completeOnboarding()
        }
        flashBurstTo(vc)
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete?()
    }

    // MARK: - Transitions

    /// Snapshot-based crossfade: takes a snapshot of the current view, swaps the VC,
    /// then fades the snapshot out to reveal the new screen underneath.
    private func crossfadeTo(_ vc: UIViewController, duration: TimeInterval) {
        let snapshot = navigationController.view.snapshotView(afterScreenUpdates: false)
        navigationController.setViewControllers([vc], animated: false)
        if let snapshot {
            navigationController.view.addSubview(snapshot)
            snapshot.isUserInteractionEnabled = false
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut) {
                snapshot.alpha = 0
            } completion: { _ in
                snapshot.removeFromSuperview()
            }
        }
    }

    /// Brief white flash, then reveal the new screen.
    private func flashBurstTo(_ vc: UIViewController) {
        let flash = UIView(frame: navigationController.view.bounds)
        flash.backgroundColor = .white
        flash.alpha = 0
        navigationController.view.addSubview(flash)

        UIView.animate(withDuration: 0.15) {
            flash.alpha = 0.3
        } completion: { _ in
            self.navigationController.setViewControllers([vc], animated: false)
            UIView.animate(withDuration: 0.25) {
                flash.alpha = 0
            } completion: { _ in
                flash.removeFromSuperview()
            }
        }
    }
}
