import Foundation
import RevenueCat
import GRDB

/// Manages in-app purchases via RevenueCat.
final class PurchaseService {

    static let apiKey = "appl_oEbuLzXbsmhGCPkiovPoDYNfWty"

    private let apiClient: APIClient
    private let syncEngine: SyncEngine?
    private let db: DatabaseManager?

    init(apiClient: APIClient, syncEngine: SyncEngine? = nil, db: DatabaseManager? = nil) {
        self.apiClient = apiClient
        self.syncEngine = syncEngine
        self.db = db
    }

    // MARK: - Configure

    /// Call once on app launch (AppDelegate or AppEnvironment).
    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)

        // Sync subscriber info with our backend when it changes
        Purchases.shared.delegate = RevenueCatDelegate.shared
    }

    /// Set the RevenueCat user ID after login (links purchases to your backend user).
    func identify(userId: String) async throws {
        _ = try await Purchases.shared.logIn(userId)
    }

    /// Clear RevenueCat identity on logout.
    func logout() async throws {
        _ = try await Purchases.shared.logOut()
    }

    // MARK: - Offerings

    /// Fetch available subscription packages.
    func fetchOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    // MARK: - Purchase

    /// Purchase a package. Returns the transaction info.
    func purchase(package: Package) async throws -> PurchaseResultData {
        try await Purchases.shared.purchase(package: package)
    }

    /// Restore previous purchases (e.g., after reinstall).
    func restorePurchases() async throws -> CustomerInfo {
        try await Purchases.shared.restorePurchases()
    }

    // MARK: - Entitlement Check

    /// Check if the user has an active "pro" entitlement.
    func isPro() async throws -> Bool {
        let info = try await Purchases.shared.customerInfo()
        let allEntitlements = info.entitlements.all.mapValues { $0.isActive }
        print("[PurchaseService] Customer ID: \(info.originalAppUserId)")
        print("[PurchaseService] Entitlements: \(allEntitlements)")
        print("[PurchaseService] Active subscriptions: \(info.activeSubscriptions)")
        return info.entitlements["Pro"]?.isActive == true
    }

    // MARK: - Sync with Backend

    /// Update the user's plan on our backend based on RevenueCat entitlements.
    /// Returns `true` if the user just upgraded from free → pro (caller should present sync choice).
    @discardableResult
    func syncPlanWithBackend() async -> Bool {
        do {
            let wasPro = UserDefaults.standard.string(forKey: "userPlan") == "pro"
            let isPro = try await isPro()
            let plan = isPro ? "pro" : "free"
            let _: EmptyResponse = try await apiClient.patch("/v1/profile", body: ["plan": plan])

            // Update local state
            UserDefaults.standard.set(plan, forKey: "userPlan")
            SyncEngine.isSyncEnabled = isPro

            let justUpgraded = isPro && !wasPro
            if justUpgraded {
                print("[PurchaseService] Free → Pro upgrade detected")
            }
            return justUpgraded
        } catch {
            print("[PurchaseService] Failed to sync plan with backend: \(error)")
            return false
        }
    }

    /// Push all local data up (wipe server first).
    func seedFullPush() async {
        guard let syncEngine else { return }
        do {
            print("[PurchaseService] Seeding full push")
            try await syncEngine.seedFullPush()
        } catch {
            print("[PurchaseService] Seed full push failed: \(error)")
        }
    }

    /// Pull cloud data down (wipe local first).
    func pullFromCloud() async {
        guard let syncEngine, let db else { return }
        do {
            print("[PurchaseService] Pulling cloud data — wiping local first")

            // Clear local user data
            try await db.dbQueue.write { db in
                try Directive.deleteAll(db)
                try NotePage.deleteAll(db)
                try Folder.deleteAll(db)
                try DayEntry.deleteAll(db)
                try Tag.deleteAll(db)
                try ScheduleRule.deleteAll(db)
                try NoteDirective.deleteAll(db)
                try ActiveMode.deleteAll(db)
                try OutboxOp.deleteAll(db)
                try Tombstone.deleteAll(db)

                // Reset sync cursor so pull starts from the beginning
                if var state = try SyncState.current(in: db) {
                    state.lastSyncToken = nil
                    state.lastPushAt = nil
                    state.lastPullAt = nil
                    try state.update(db)
                }
            }

            try await syncEngine.pull()
            print("[PurchaseService] Cloud pull complete")
        } catch {
            print("[PurchaseService] Pull from cloud failed: \(error)")
        }
    }
}

// MARK: - EmptyResponse for PATCH

private struct EmptyResponse: Decodable {}

// MARK: - RevenueCat Delegate

/// Singleton delegate that listens for subscription changes.
final class RevenueCatDelegate: NSObject, PurchasesDelegate {

    static let shared = RevenueCatDelegate()

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let isPro = customerInfo.entitlements["Pro"]?.isActive == true
        print("[RevenueCat] Entitlement updated — pro: \(isPro)")

        // Post notification so the app can react
        NotificationCenter.default.post(
            name: .subscriptionStatusChanged,
            object: nil,
            userInfo: ["isPro": isPro]
        )
    }
}

extension Notification.Name {
    static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}
