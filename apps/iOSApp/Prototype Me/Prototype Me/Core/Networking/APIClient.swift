import Foundation

/// Thin `URLSession` wrapper for all HTTP calls to the Prototype Me backend.
/// Injects auth headers, handles token refresh on 401, and applies retry + backoff.
final class APIClient: Sendable {

    // MARK: - Configuration

    struct Config: Sendable {
        let baseURL: URL
        let apiVersion: String

        static let `default` = Config(
            baseURL: URL(string: Self.resolvedBaseURL)!,
            apiVersion: "1"
        )

        private static var resolvedBaseURL: String {
            // Railway staging — swap to localhost:3000 for local dev
            return "https://prototype-me-production.up.railway.app"
        }
    }

    enum Timeout {
        static let normal: TimeInterval = 15
        static let sync: TimeInterval = 30
        static let ai: TimeInterval = 60
    }

    // MARK: - Errors

    enum APIError: Error, Sendable {
        case unauthorized                       // 401 after refresh attempt
        case clientError(Int, String?, Data?)    // 4xx + parsed message
        case serverError(Int, Data?)             // 5xx
        case networkError(Error)
        case decodingError(Error)
        case noData

        /// Human-readable description from the server's error envelope.
        var serverMessage: String? {
            switch self {
            case .clientError(_, let msg, _): return msg
            default: return nil
            }
        }
    }

    // MARK: - Auth State

    private struct AuthState {
        var accessToken: String?
        var refreshToken: String?
        var deviceId: String
    }

    // MARK: - Properties

    private let config: Config
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let lock = NSLock()
    private var authState: AuthState

    // MARK: - Init

    init(config: Config = .default) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = Timeout.normal
        self.session = URLSession(configuration: sessionConfig)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // Load or generate device ID
        let deviceId = Self.loadOrCreateDeviceId()
        self.authState = AuthState(
            accessToken: Self.loadToken(key: "accessToken"),
            refreshToken: Self.loadToken(key: "refreshToken"),
            deviceId: deviceId
        )
    }

    // MARK: - Public API

    /// Perform a GET request and decode the response.
    func get<T: Decodable>(_ path: String, timeout: TimeInterval = Timeout.normal) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, timeout: timeout)
        return try await perform(request)
    }

    /// Perform a POST request with an encodable body and decode the response.
    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, timeout: TimeInterval = Timeout.normal) async throws -> T {
        var request = try buildRequest(method: "POST", path: path, timeout: timeout)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    /// Perform a POST with no response body expected.
    func post<Body: Encodable>(_ path: String, body: Body, timeout: TimeInterval = Timeout.normal) async throws {
        var request = try buildRequest(method: "POST", path: path, timeout: timeout)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let _: EmptyResponse = try await perform(request)
    }

    /// Perform a PATCH request with an encodable body and decode the response.
    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body, timeout: TimeInterval = Timeout.normal) async throws -> T {
        var request = try buildRequest(method: "PATCH", path: path, timeout: timeout)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    /// Perform a DELETE request.
    func delete(_ path: String) async throws {
        let request = try buildRequest(method: "DELETE", path: path, timeout: Timeout.normal)
        let _: EmptyResponse = try await perform(request)
    }

    // MARK: - Token Management

    func setTokens(access: String, refresh: String) {
        lock.lock()
        authState.accessToken = access
        authState.refreshToken = refresh
        lock.unlock()
        Self.saveToken(access, key: "accessToken")
        Self.saveToken(refresh, key: "refreshToken")
    }

    func clearTokens() {
        lock.lock()
        authState.accessToken = nil
        authState.refreshToken = nil
        lock.unlock()
        Self.deleteToken(key: "accessToken")
        Self.deleteToken(key: "refreshToken")
    }

    var deviceId: String {
        lock.lock()
        defer { lock.unlock() }
        return authState.deviceId
    }

    var isAuthenticated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return authState.accessToken != nil
    }

    // MARK: - Request Building

    private func buildRequest(method: String, path: String, timeout: TimeInterval) throws -> URLRequest {
        // Use string concatenation instead of appendingPathComponent to preserve query strings
        guard let url = URL(string: config.baseURL.absoluteString + path) else {
            throw APIError.networkError(NSError(domain: "APIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(path)"]))
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue(config.apiVersion, forHTTPHeaderField: "X-API-Version")

        lock.lock()
        let token = authState.accessToken
        let devId = authState.deviceId
        lock.unlock()

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(devId, forHTTPHeaderField: "X-Device-Id")

        return request
    }

    // MARK: - Request Execution

    private func perform<T: Decodable>(_ request: URLRequest, isRetry: Bool = false) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        // 401 → attempt token refresh once
        if http.statusCode == 401, !isRetry {
            try await refreshAccessToken()
            var retryRequest = request
            lock.lock()
            let newToken = authState.accessToken
            lock.unlock()
            if let newToken {
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            }
            return try await perform(retryRequest, isRetry: true)
        }

        switch http.statusCode {
        case 200...299:
            // Handle empty body for Void-like responses (204 No Content)
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            // Unwrap the { success, data, error, message } envelope
            do {
                let envelope = try decoder.decode(APIResponse<T>.self, from: data)
                guard envelope.success, let payload = envelope.data else {
                    throw APIError.serverError(http.statusCode, data)
                }
                return payload
            } catch let error as APIError {
                throw error
            } catch {
                throw APIError.decodingError(error)
            }
        case 400...499:
            // Try to parse error envelope for a descriptive message
            if let envelope = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data) {
                throw APIError.clientError(http.statusCode, envelope.message, data)
            }
            throw APIError.clientError(http.statusCode, nil, data)
        default:
            throw APIError.serverError(http.statusCode, data)
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws {
        lock.lock()
        guard let refresh = authState.refreshToken else {
            lock.unlock()
            throw APIError.unauthorized
        }
        lock.unlock()

        let url = config.baseURL.appendingPathComponent("/auth/refresh")
        var request = URLRequest(url: url, timeoutInterval: Timeout.normal)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["refreshToken": refresh]
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            clearTokens()
            // Notify the app that the session expired — AppCoordinator will redirect to login
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            throw APIError.unauthorized
        }

        struct RefreshResponse: Decodable {
            let accessToken: String
            let refreshToken: String?
        }

        let decoded = try decoder.decode(RefreshResponse.self, from: data)
        setTokens(access: decoded.accessToken, refresh: decoded.refreshToken ?? refresh)
    }

    // MARK: - Keychain Helpers (UserDefaults stub — swap to Keychain for production)

    private static func loadOrCreateDeviceId() -> String {
        let key = "com.prototypeme.deviceId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private static func saveToken(_ value: String, key: String) {
        UserDefaults.standard.set(value, forKey: "com.prototypeme.\(key)")
    }

    private static func loadToken(key: String) -> String? {
        UserDefaults.standard.string(forKey: "com.prototypeme.\(key)")
    }

    private static func deleteToken(key: String) {
        UserDefaults.standard.removeObject(forKey: "com.prototypeme.\(key)")
    }
}

// MARK: - Response Envelope

/// Matches the backend's unified response shape:
/// `{ "success": true/false, "data": T?, "error": String?, "message": String? }`
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

// MARK: - Helper Types

private struct EmptyResponse: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when the access token refresh fails — session is expired, user needs to re-authenticate.
    static let authSessionExpired = Notification.Name("authSessionExpired")
}
