import Foundation
import AuthenticationServices
import Observation
import OSLog

enum AuthError: Error {
    case invalidToken
    case networkError
    case invalidResponse
    case unauthorized
    
    var localizedDescription: String {
        switch self {
        case .invalidToken: return L10n.Error.authInvalidToken
        case .networkError: return L10n.Error.authNetworkError
        case .invalidResponse: return L10n.Error.authInvalidResponse
        case .unauthorized: return L10n.Error.authUnauthorized
        }
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: UserInfo
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct UserInfo: Codable {
    let id: String
    let email: String
    let username: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, email, username
        case createdAt = "created_at"
    }
}

struct AppleSignInRequest: Encodable {
    let identityToken: String
    let userInfo: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case userInfo = "user_info"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identityToken, forKey: .identityToken)
        try container.encodeIfPresent(userInfo, forKey: .userInfo)
    }
}

@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    var isAuthenticated = false
    var currentUser: UserInfo?

    private let baseURL: String
    private let keychain = KeychainService.shared

    // Public initializer for DI
    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? {
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8000/api/v1"
            #else
            return "https://elegant-empathy-production-583b.up.railway.app/api/v1"
            #endif
        }()

        // Check if we have stored tokens
        if let _ = keychain.getAccessToken() {
            AppLogger.auth.info("Found stored access token, restoring session")
            isAuthenticated = true
            Task {
                await loadCurrentUser()
            }
        } else {
            AppLogger.auth.debug("No stored tokens found, user not authenticated")
        }
    }
    
    // MARK: - Apple Sign In
    
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async throws {
        AppLogger.auth.startOperation("Apple Sign In")
        
        switch result {
        case .success(let authorization):
            AppLogger.auth.debug("Received Apple authorization")
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8) else {
                AppLogger.auth.error("Failed to extract identity token from Apple credential")
                throw AuthError.invalidToken
            }

            // Extract user info including full name
            var userInfo: [String: Any] = [:]

            AppLogger.auth.debug("Apple credential - fullName: \(appleIDCredential.fullName != nil ? "available" : "nil"), email: \(appleIDCredential.email != nil ? "available" : "nil")")

            // Add full name if available
            if let fullName = appleIDCredential.fullName {
                AppLogger.auth.debug("Full name available: givenName=\(fullName.givenName ?? "nil"), familyName=\(fullName.familyName ?? "nil")")
                var nameComponents: [String: String] = [:]
                if let givenName = fullName.givenName {
                    nameComponents["firstName"] = givenName
                }
                if let familyName = fullName.familyName {
                    nameComponents["lastName"] = familyName
                }
                if !nameComponents.isEmpty {
                    userInfo["name"] = nameComponents
                }
            }

            // Add email if available (backup)
            if let email = appleIDCredential.email {
                userInfo["email"] = email
            }

            AppLogger.auth.debug("Identity token extracted, userInfo: \(userInfo.isEmpty ? "empty" : "contains \(userInfo.count) fields"), sending to backend")
            try await signInWithBackend(identityToken: tokenString, userInfo: userInfo.isEmpty ? nil : userInfo.mapValues { AnyCodable($0) })
            AppLogger.auth.completeOperation("Apple Sign In")
            
        case .failure(let error):
            AppLogger.auth.failOperation("Apple Sign In", error: error)
            throw error
        }
    }
    
    private func signInWithBackend(identityToken: String, userInfo: [String: AnyCodable]?) async throws {
        AppLogger.auth.debug("Signing in with backend")
        let url = URL(string: "\(baseURL)/auth/apple-signin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = AppleSignInRequest(identityToken: identityToken, userInfo: userInfo)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            AppLogger.auth.error("Network error during sign-in", error: error)
            // Re-throw network errors as-is so they can be converted to NetworkError
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.auth.error("Invalid response type from backend")
            throw AuthError.invalidResponse
        }
        
        AppLogger.auth.info("Backend response status: \(httpResponse.statusCode)")
        
        // Check for HTTP error status codes
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                AppLogger.auth.warning("Backend returned 401 Unauthorized")
                throw AuthError.unauthorized
            }
            AppLogger.auth.error("Backend returned error status: \(httpResponse.statusCode)")
            throw AuthError.invalidResponse
        }
        
        let tokenResponse: TokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            AppLogger.auth.error("Failed to decode token response", error: error)
            throw AuthError.invalidResponse
        }
        
        // Store tokens securely
        keychain.saveAccessToken(tokenResponse.accessToken)
        keychain.saveRefreshToken(tokenResponse.refreshToken)
        AppLogger.auth.info("Tokens stored securely in keychain")
        
        // Update state
        currentUser = tokenResponse.user
        isAuthenticated = true
        let usernameInfo = tokenResponse.user.username != nil ? " (username: \(tokenResponse.user.username!))" : " (no username)"
        AppLogger.auth.info("Sign-in successful for user: \(tokenResponse.user.email)\(usernameInfo)")
    }
    
    // MARK: - Token Management
    
    func refreshAccessToken() async throws {
        AppLogger.auth.debug("Refreshing access token")
        
        guard let refreshToken = keychain.getRefreshToken() else {
            AppLogger.auth.warning("No refresh token found in keychain")
            throw AuthError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            AppLogger.auth.error("Network error during token refresh", error: error)
            // Re-throw network errors as-is so they can be converted to NetworkError
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.auth.error("Invalid response type during token refresh")
            throw AuthError.invalidResponse
        }
        
        AppLogger.auth.info("Token refresh response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            AppLogger.auth.warning("Token refresh failed with status \(httpResponse.statusCode), logging out")
            // Refresh token is invalid, logout user
            await logout()
            throw AuthError.unauthorized
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Update stored tokens
        keychain.saveAccessToken(tokenResponse.accessToken)
        keychain.saveRefreshToken(tokenResponse.refreshToken)
        AppLogger.auth.info("Tokens refreshed successfully")
        
        currentUser = tokenResponse.user
    }
    
    // MARK: - Token Access

    func getAccessToken() async throws -> String {
        // Try to get current token
        if let token = keychain.getAccessToken() {
            return token
        }

        // If no token, try to refresh (this will throw if refresh fails)
        try await refreshAccessToken()

        // After refresh, get the new token
        guard let token = keychain.getAccessToken() else {
            throw AuthError.unauthorized
        }

        return token
    }

    // MARK: - Authenticated Requests

    func makeAuthenticatedRequest(to endpoint: String) async throws -> Data {
        guard let accessToken = keychain.getAccessToken() else {
            AppLogger.auth.warning("No access token available for authenticated request")
            throw AuthError.unauthorized
        }

        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        // If unauthorized, try refreshing token
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            try await refreshAccessToken()

            // Get refreshed token safely
            guard let newAccessToken = keychain.getAccessToken() else {
                throw AuthError.unauthorized
            }

            request.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)

            guard let httpRetryResponse = retryResponse as? HTTPURLResponse,
                  (200...299).contains(httpRetryResponse.statusCode) else {
                throw AuthError.invalidResponse
            }

            return retryData
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        return data
    }

    func makeAuthenticatedRequestWithRetry(request: URLRequest) async throws -> Data {
        var mutableRequest = request

        guard let accessToken = keychain.getAccessToken() else {
            AppLogger.auth.warning("No access token available for authenticated request")
            throw AuthError.unauthorized
        }

        mutableRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: mutableRequest)

        // If unauthorized, try refreshing token
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            try await refreshAccessToken()

            // Get refreshed token safely
            guard let newAccessToken = keychain.getAccessToken() else {
                throw AuthError.unauthorized
            }

            mutableRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: mutableRequest)

            guard let httpRetryResponse = retryResponse as? HTTPURLResponse,
                  (200...299).contains(httpRetryResponse.statusCode) else {
                throw AuthError.invalidResponse
            }

            return retryData
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidResponse
        }

        return data
    }

    // MARK: - User Info

    /// Ensures currentUser is loaded before proceeding with authenticated operations
    /// - Throws: AuthError if user cannot be loaded or authentication fails
    func ensureCurrentUserLoaded() async throws {
        // If we already have currentUser, return immediately
        if currentUser != nil {
            return
        }

        // If not authenticated, throw error
        guard isAuthenticated else {
            throw AuthError.unauthorized
        }

        // Load current user if we have tokens but no user info yet
        if keychain.getAccessToken() != nil {
            await loadCurrentUser()

            // Check if loading succeeded
            guard currentUser != nil else {
                AppLogger.auth.error("Failed to load current user despite having valid tokens")
                throw AuthError.invalidResponse
            }
        } else {
            AppLogger.auth.error("No access token found when trying to ensure user is loaded")
            throw AuthError.unauthorized
        }
    }

    func loadCurrentUser() async {
        AppLogger.auth.debug("Loading current user info")
        do {
            let data = try await makeAuthenticatedRequest(to: "/auth/me")
            currentUser = try JSONDecoder().decode(UserInfo.self, from: data)
            AppLogger.auth.info("Current user loaded: \(currentUser?.email ?? "unknown")")
        } catch {
            AppLogger.auth.error("Failed to load user", error: error)
            await logout()
        }
    }

    // MARK: - Profile Update

    func updateProfile(username: String) async throws -> UserInfo {
        AppLogger.auth.info("Updating profile with username: \(username)")

        let url = URL(string: "\(baseURL)/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["username": username]
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await makeAuthenticatedRequestWithRetry(request: request)
        let updatedUser = try JSONDecoder().decode(UserInfo.self, from: data)

        // Update local state
        currentUser = updatedUser

        AppLogger.auth.info("Profile updated successfully for user: \(updatedUser.email)")
        return updatedUser
    }

    // MARK: - Logout
    
    func logout() async {
        AppLogger.auth.info("Logging out user")
        
        // Call backend logout endpoint
        if let accessToken = keychain.getAccessToken() {
            let url = URL(string: "\(baseURL)/auth/logout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            do {
                _ = try await URLSession.shared.data(for: request)
                AppLogger.auth.info("Backend logout successful")
            } catch {
                AppLogger.auth.warning("Backend logout failed (non-critical): \(error.localizedDescription)")
            }
        } else {
            AppLogger.auth.debug("No access token found, skipping backend logout")
        }
        
        // Clear stored tokens
        keychain.deleteAccessToken()
        keychain.deleteRefreshToken()
        AppLogger.auth.debug("Tokens cleared from keychain")
        
        // Update state
        isAuthenticated = false
        currentUser = nil
        AppLogger.auth.info("Logout complete")
    }
}

// MARK: - Environment Key

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: AuthService = AuthService()
}

extension EnvironmentValues {
    var authService: AuthService {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}