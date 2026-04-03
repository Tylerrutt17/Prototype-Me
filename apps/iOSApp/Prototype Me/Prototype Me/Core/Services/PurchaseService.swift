import Foundation
import RevenueCat

/// Manages in-app purchases via RevenueCat.
final class PurchaseService {

    static let apiKey = "appl_oEbuLzXbsmhGCPkiovPoDYNfWty"

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
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
        return info.entitlements["pro"]?.isActive == true
    }

    // MARK: - Sync with Backend

    /// Update the user's plan on our backend based on RevenueCat entitlements.
    func syncPlanWithBackend() async {
        do {
            let isPro = try await isPro()
            let plan = isPro ? "pro" : "free"
            let _: EmptyResponse = try await apiClient.patch("/v1/profile", body: ["plan": plan])

            // Update local state
            UserDefaults.standard.set(plan, forKey: "userPlan")
            SyncEngine.isSyncEnabled = isPro
        } catch {
            print("[PurchaseService] Failed to sync plan with backend: \(error)")
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
        let isPro = customerInfo.entitlements["pro"]?.isActive == true
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
