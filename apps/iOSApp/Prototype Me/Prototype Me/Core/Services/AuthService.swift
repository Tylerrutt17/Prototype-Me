import AuthenticationServices
import UIKit

/// Handles Sign in with Apple and token management.
final class AuthService: NSObject, Sendable {

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - Sign in with Apple

    /// Trigger the Sign in with Apple flow. Call from a view controller.
    func signInWithApple(presentingVC: UIViewController) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = presentingVC as? ASAuthorizationControllerDelegate
        controller.presentationContextProvider = presentingVC as? ASAuthorizationControllerPresentationContextProviding
        controller.performRequests()
    }

    /// Process the Apple credential and authenticate with the backend.
    func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws -> AuthResponse {
        guard let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        // Build full name if provided (Apple only sends it on first sign-in)
        var fullName: String?
        if let nameComponents = credential.fullName {
            let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
            if !parts.isEmpty {
                fullName = parts.joined(separator: " ")
            }
        }

        // Call backend
        let response: AuthResponse = try await apiClient.post(
            "/v1/auth/apple",
            body: AppleLoginRequest(identityToken: identityToken, fullName: fullName),
            timeout: APIClient.Timeout.normal
        )

        // Store tokens
        apiClient.setTokens(access: response.accessToken, refresh: response.refreshToken)

        // Save user info
        UserDefaults.standard.set(response.user.id, forKey: "userId")
        UserDefaults.standard.set(response.user.displayName, forKey: "userDisplayName")
        UserDefaults.standard.set(response.user.plan, forKey: "userPlan")

        // Enable sync for pro users
        SyncEngine.isSyncEnabled = response.user.plan == "pro"

        return response
    }

    /// Check if the user is already signed in (has valid tokens).
    var isSignedIn: Bool {
        apiClient.isAuthenticated
    }

    /// Whether the current user has a Pro plan. Cached in UserDefaults, refreshed on login and via refreshPlan().
    static var isPro: Bool {
        UserDefaults.standard.string(forKey: "userPlan") == "pro"
    }

    /// Fetch the current plan from the server and update local cache.
    /// Call on app launch or after purchase.
    func refreshPlan() async {
        do {
            let sub: SubscriptionInfo = try await apiClient.get("/v1/subscription")
            let plan = sub.plan.rawValue
            UserDefaults.standard.set(plan, forKey: "userPlan")
            SyncEngine.isSyncEnabled = sub.plan == .pro
        } catch {
            // Keep whatever's cached
        }
    }

    func signOut() {
        apiClient.clearTokens()
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userDisplayName")
        UserDefaults.standard.removeObject(forKey: "userPlan")
        SyncEngine.isSyncEnabled = false
    }

    // MARK: - Types

    enum AuthError: Error {
        case missingToken
        case serverError(String)
    }
}

// MARK: - API Types

struct AppleLoginRequest: Encodable {
    let identityToken: String
    let fullName: String?
}

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let isNewUser: Bool?
    let user: AuthUser
}

struct AuthUser: Decodable {
    let id: String
    let email: String
    let displayName: String
    let plan: String
}
