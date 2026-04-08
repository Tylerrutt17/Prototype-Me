import UIKit

class SettingsCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController
    private let environment: AppEnvironment
    var onReplayTourRequested: (() -> Void)?

    init(environment: AppEnvironment) {
        self.environment = environment
        self.navigationController = UINavigationController()
        navigationController.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )
    }

    func start() {
        let vc = SettingsViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.syncEngine = environment.syncEngine

        vc.onSyncDebugTapped = { [weak self] in self?.showSyncDebug() }
        vc.onProfileTapped = { [weak self] in self?.showProfile() }
        vc.onSubscriptionTapped = { [weak self] in self?.showSubscription() }
        vc.onUsageTapped = { [weak self] in self?.showUsageLimit() }
        vc.onFriendsTapped = { [weak self] in self?.showFriends() }
        vc.onReplayTourTapped = { [weak self] in self?.showCoachMarks() }
        vc.onReplayIntroTapped = { [weak self] in self?.showIntroStory() }
        vc.onLegalTapped = { [weak self] title in self?.showLegal(title: title) }

        navigationController.viewControllers = [vc]
    }

    // MARK: - Navigation

    private func showSyncDebug() {
        let vc = SyncDebugViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.syncEngine = environment.syncEngine
        navigationController.pushViewController(vc, animated: true)
    }

    private func showProfile() {
        let vc = ProfileViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.isSelf = true
        vc.onFriendsTapped = { [weak self] in self?.showFriends() }
        vc.onUpgradeTapped = { [weak self] in self?.showPaywall() }
        navigationController.pushViewController(vc, animated: true)

        // Load data async
        Task {
            do {
                let profile: UserProfile = try await environment.apiClient.get("/v1/profile")
                await MainActor.run { vc.profile = profile }
            } catch {
                await MainActor.run { vc.showLoadError("Couldn't load profile") }
            }
        }
    }

    private func showSubscription() {
        let vc = SubscriptionViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.onUpgradeTapped = { [weak self] in self?.showPaywall() }
        navigationController.pushViewController(vc, animated: true)

        Task {
            do {
                async let subReq: SubscriptionInfo = environment.apiClient.get("/v1/subscription")
                async let quotaReq: UsageQuota = environment.apiClient.get("/v1/usage")
                let (sub, quota) = try await (subReq, quotaReq)
                await MainActor.run {
                    vc.subscriptionInfo = sub
                    vc.usageQuota = quota
                }
            } catch {
                await MainActor.run { vc.showLoadError("Couldn't load subscription info") }
            }
        }
    }

    private func showUsageLimit() {
        let vc = UsageLimitViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.onUpgradeTapped = { [weak self] in self?.showPaywall() }
        navigationController.pushViewController(vc, animated: true)

        Task {
            do {
                async let quotaReq: UsageQuota = environment.apiClient.get("/v1/usage")
                async let subReq: SubscriptionInfo = environment.apiClient.get("/v1/subscription")
                let (quota, sub) = try await (quotaReq, subReq)
                await MainActor.run {
                    vc.quota = quota
                    vc.plan = sub.plan
                }
            } catch {
                await MainActor.run { vc.showLoadError("Couldn't load usage info") }
            }
        }
    }

    private func showFriends() {
        let vc = FriendsListViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.onFriendTapped = { [weak self] friend in
            self?.showFriendProfile(friend)
        }
        navigationController.pushViewController(vc, animated: true)

        Task {
            do {
                let friends: [FriendItem] = try await environment.apiClient.get("/v1/friends")
                await MainActor.run { vc.friends = friends }
            } catch {
                await MainActor.run { vc.showLoadError("Couldn't load friends") }
            }
        }
    }

    private func showFriendProfile(_ friend: FriendItem) {
        let vc = ProfileViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.profile = UserProfile(
            id: friend.id,
            displayName: friend.displayName,
            bio: nil,
            avatarSystemImage: friend.avatarSystemImage,
            moodChips: [],
            joinedAt: friend.since ?? .now,
            plan: .free
        )
        vc.isSelf = false
        navigationController.pushViewController(vc, animated: true)
    }

    private func showPaywall() {
        let vc = PaywallViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.purchaseService = environment.purchaseService
        vc.onDismiss = { [weak self] in
            self?.navigationController.dismiss(animated: true) {
                self?.refreshSubscriptionScreen()
            }
        }
        vc.onUpgraded = { [weak self] in
            guard let self else { return }
            // Dismiss paywall, then show sync choice
            self.navigationController.dismiss(animated: true) {
                self.showSyncChoice()
            }
        }

        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        navigationController.present(nav, animated: true)
    }

    private func showSyncChoice() {
        let vc = SyncChoiceViewController()
        vc.apiClient = environment.apiClient
        vc.dbQueue = environment.db.dbQueue
        vc.onChoice = { [weak self] direction in
            guard let self else { return }
            PurchaseService.clearPendingSyncChoice()

            // Show loading while sync runs
            let loadingVC = SyncLoadingViewController()
            loadingVC.syncTask = {
                switch direction {
                case .useCloud:
                    await self.environment.purchaseService.pullFromCloud()
                case .useDevice:
                    await self.environment.purchaseService.seedFullPush()
                }
            }
            loadingVC.onComplete = { [weak self] in
                self?.navigationController.dismiss(animated: true) {
                    self?.refreshSubscriptionScreen()
                }
            }

            let nav = UINavigationController(rootViewController: loadingVC)
            nav.setNavigationBarHidden(true, animated: false)
            nav.modalPresentationStyle = .fullScreen
            vc.present(nav, animated: true)
        }

        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        navigationController.present(nav, animated: true)
    }

    /// Refreshes the subscription screen if it's currently visible.
    private func refreshSubscriptionScreen() {
        guard let subVC = navigationController.viewControllers.last as? SubscriptionViewController else { return }
        Task {
            do {
                async let subReq: SubscriptionInfo = environment.apiClient.get("/v1/subscription")
                async let quotaReq: UsageQuota = environment.apiClient.get("/v1/usage")
                let (sub, quota) = try await (subReq, quotaReq)
                await MainActor.run {
                    subVC.subscriptionInfo = sub
                    subVC.usageQuota = quota
                }
            } catch {}
        }
    }

    private func showLegal(title: String) {
        let vc = LegalViewController()
        vc.documentTitle = title
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        navigationController.present(nav, animated: true)
    }

    private func showCoachMarks() {
        onReplayTourRequested?()
    }

    private func showIntroStory() {
        let vc = OnboardingStoryViewController()
        vc.onFinished = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .fullScreen
        navigationController.present(vc, animated: true)
    }
}
