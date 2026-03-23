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

        vc.onSyncDebugTapped = { [weak self] in self?.showSyncDebug() }
        vc.onProfileTapped = { [weak self] in self?.showProfile() }
        vc.onSubscriptionTapped = { [weak self] in self?.showSubscription() }
        vc.onUsageTapped = { [weak self] in self?.showUsageLimit() }
        vc.onFriendsTapped = { [weak self] in self?.showFriends() }
        vc.onReplayTourTapped = { [weak self] in self?.showCoachMarks() }
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
        vc.profile = SampleData.currentUserProfile  // TODO: fetch from API/cache
        vc.isSelf = true
        vc.onFriendsTapped = { [weak self] in self?.showFriends() }
        vc.onUpgradeTapped = { [weak self] in self?.showPaywall() }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showSubscription() {
        let vc = SubscriptionViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.subscriptionInfo = SampleData.subscriptionInfo  // TODO: fetch from API/cache
        vc.usageQuota = SampleData.usageQuota              // TODO: fetch from API/cache
        vc.onUpgradeTapped = { [weak self] in self?.showPaywall() }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showUsageLimit() {
        let vc = UsageLimitViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.quota = SampleData.usageQuota                   // TODO: fetch from API/cache
        vc.plan = SampleData.subscriptionInfo.plan         // TODO: fetch from API/cache
        vc.onUpgradeTapped = { [weak self] in self?.showPaywall() }
        navigationController.pushViewController(vc, animated: true)
    }

    private func showFriends() {
        let vc = FriendsListViewController()
        vc.dbQueue = environment.db.dbQueue
        vc.friends = SampleData.friends                    // TODO: fetch from API/cache
        vc.onFriendTapped = { [weak self] friend in
            self?.showFriendProfile(friend)
        }
        navigationController.pushViewController(vc, animated: true)
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
        vc.onDismiss = { [weak self] in
            self?.navigationController.dismiss(animated: true)
        }

        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        navigationController.present(nav, animated: true)
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
}
