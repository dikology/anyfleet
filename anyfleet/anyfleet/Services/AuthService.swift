import Foundation
import AuthenticationServices
import Observation
import OSLog

enum AuthError: Error {
    case invalidToken
    case networkError
    case invalidResponse
    case unauthorized
    
    @MainActor
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

    // Phase 1 additions
    let profileImageUrl: String?
    let profileImageThumbnailUrl: String?
    let bio: String?
    let location: String?
    let nationality: String?
    let profileVisibility: String?

    // Phase 2 additions — defaulting to nil keeps all existing call sites unchanged
    var socialLinks: [SocialLink]? = nil
    var communities: [CommunityMembership]? = nil

    enum CodingKeys: String, CodingKey {
        case id, email, username, bio, location, nationality
        case createdAt = "created_at"
        case profileImageUrl = "profile_image_url"
        case profileImageThumbnailUrl = "profile_image_thumbnail_url"
        case profileVisibility = "profile_visibility"
        case socialLinks = "social_links"
        case communities = "community_memberships"
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

struct ProfileImageUploadResponse: Codable {
    let profileImageUrl: String
    let profileImageThumbnailUrl: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case profileImageUrl = "profile_image_url"
        case profileImageThumbnailUrl = "profile_image_thumbnail_url"
        case message
    }
}

/// Request body for `PUT /auth/me`. Only non-nil fields are sent to the backend.
struct UpdateProfileBody: Encodable {
    var username: String?
    var bio: String?
    var location: String?
    var nationality: String?
    var profileVisibility: String?
    var socialLinks: [SocialLink]?
    var communityMemberships: [CommunityMembership]?

    enum CodingKeys: String, CodingKey {
        case username, bio, location, nationality
        case profileVisibility = "profile_visibility"
        case socialLinks = "social_links"
        case communityMemberships = "community_memberships"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(nationality, forKey: .nationality)
        try container.encodeIfPresent(profileVisibility, forKey: .profileVisibility)
        try container.encodeIfPresent(socialLinks, forKey: .socialLinks)
        try container.encodeIfPresent(communityMemberships, forKey: .communityMemberships)
    }
}

extension UserInfo {
    /// Returns a copy with `https://` prepended when the API sends host-relative image paths.
    fileprivate func withAbsoluteImageURLsIfNeeded() -> UserInfo {
        guard let imageUrl = profileImageUrl, !imageUrl.hasPrefix("http") else { return self }
        let thumbnail: String?
        if let t = profileImageThumbnailUrl, !t.hasPrefix("http") {
            thumbnail = "https://\(t)"
        } else {
            thumbnail = profileImageThumbnailUrl
        }
        return UserInfo(
            id: id,
            email: email,
            username: username,
            createdAt: createdAt,
            profileImageUrl: "https://\(imageUrl)",
            profileImageThumbnailUrl: thumbnail,
            bio: bio,
            location: location,
            nationality: nationality,
            profileVisibility: profileVisibility,
            socialLinks: socialLinks,
            communities: communities
        )
    }
}

@MainActor
@Observable
final class AuthService: AuthServiceProtocol {
    var isAuthenticated = false
    var currentUser: UserInfo?

    private let baseURL: String
    private let keychain = KeychainService.shared
    private let session: URLSession
    /// Serialises concurrent refresh calls: the second caller awaits the first task's result
    /// instead of firing a duplicate network request (which would burn the single-use refresh token).
    private var tokenRefreshTask: Task<Void, Error>?

    // Public initializer for DI; `session` is injectable for unit tests.
    init(baseURL: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL ?? {
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8000/api/v1"
            #else
            return "https://anyfleet-api-staging.up.railway.app/api/v1"
            #endif
        }()
        self.session = session

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

    private func apiURL(path: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
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
        guard let url = apiURL(path: "/auth/apple-signin") else {
            AppLogger.auth.error("Invalid apple-signin URL for base \(baseURL)")
            throw AuthError.invalidResponse
        }
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

        let user = tokenResponse.user.withAbsoluteImageURLsIfNeeded()
        currentUser = user
        isAuthenticated = true
        let usernameInfo = user.username.map { " (username: \($0))" } ?? " (no username)"
        AppLogger.auth.info("Sign-in successful for user: \(user.email)\(usernameInfo)")
    }
    
    // MARK: - Token Management

    func refreshAccessToken() async throws {
        // Coalesce concurrent callers: if a refresh is already in flight, piggyback on it
        // rather than firing a second request (the backend issues single-use rotating tokens).
        if let existing = tokenRefreshTask {
            AppLogger.auth.debug("Token refresh already in progress, awaiting existing task")
            try await existing.value
            return
        }

        let task = Task<Void, Error> { [weak self] in
            guard let self else { throw AuthError.unauthorized }
            try await self.performTokenRefresh()
        }
        tokenRefreshTask = task
        do {
            try await task.value
            tokenRefreshTask = nil
        } catch {
            tokenRefreshTask = nil
            throw error
        }
    }

    private func performTokenRefresh() async throws {
        AppLogger.auth.debug("Refreshing access token")

        guard let refreshToken = keychain.getRefreshToken() else {
            AppLogger.auth.warning("No refresh token found in keychain")
            throw AuthError.unauthorized
        }

        guard let url = apiURL(path: "/auth/refresh") else {
            throw AuthError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            AppLogger.auth.error("Network error during token refresh", error: error)
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.auth.error("Invalid response type during token refresh")
            throw AuthError.invalidResponse
        }

        AppLogger.auth.info("Token refresh response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            AppLogger.auth.warning("Token refresh failed with status \(httpResponse.statusCode), logging out")
            await logout()
            throw AuthError.unauthorized
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let user = tokenResponse.user.withAbsoluteImageURLsIfNeeded()

        keychain.saveAccessToken(tokenResponse.accessToken)
        keychain.saveRefreshToken(tokenResponse.refreshToken)
        AppLogger.auth.info("Tokens refreshed successfully")

        currentUser = user
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

        guard let url = apiURL(path: endpoint) else {
            throw AuthError.invalidResponse
        }
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
            let user = try JSONDecoder().decode(UserInfo.self, from: data).withAbsoluteImageURLsIfNeeded()

            currentUser = user
            AppLogger.auth.info("Current user loaded: \(currentUser?.email ?? "unknown")")
        } catch {
            AppLogger.auth.error("Failed to load user", error: error)
            await logout()
        }
    }

    // MARK: - Profile Update

    /// Builds the URLRequest for profile update. Exposed for testing to verify HTTP method and body.
    nonisolated static func buildUpdateProfileRequest(
        baseURL: String,
        username: String?,
        bio: String?,
        location: String?,
        nationality: String?,
        profileVisibility: String?,
        socialLinks: [SocialLink]? = nil,
        communityMemberships: [CommunityMembership]? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/auth/me") else {
            throw AuthError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpdateProfileBody(
            username: username,
            bio: bio,
            location: location,
            nationality: nationality,
            profileVisibility: profileVisibility,
            socialLinks: socialLinks,
            communityMemberships: communityMemberships
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    func updateProfile(
        username: String? = nil,
        bio: String? = nil,
        location: String? = nil,
        nationality: String? = nil,
        profileVisibility: String? = nil,
        socialLinks: [SocialLink]? = nil,
        communityMemberships: [CommunityMembership]? = nil
    ) async throws -> UserInfo {
        AppLogger.auth.info("Updating profile")

        let request = try Self.buildUpdateProfileRequest(
            baseURL: baseURL,
            username: username,
            bio: bio,
            location: location,
            nationality: nationality,
            profileVisibility: profileVisibility,
            socialLinks: socialLinks,
            communityMemberships: communityMemberships
        )

        let data = try await makeAuthenticatedRequestWithRetry(request: request)
        let updatedUser = try JSONDecoder().decode(UserInfo.self, from: data)

        currentUser = updatedUser
        AppLogger.auth.info("Profile updated successfully for user: \(updatedUser.email)")
        return updatedUser
    }
    
    func uploadProfileImage(_ imageData: Data) async throws -> UserInfo {
        AppLogger.auth.info("Uploading profile image (\(imageData.count) bytes)")

        guard let url = apiURL(path: "/profile/upload-image") else {
            throw AuthError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        request.httpBody = body

        AppLogger.auth.debug("Sending multipart request with boundary: \(boundary)")
        AppLogger.auth.debug("Request body size: \(body.count) bytes")

        let data = try await makeAuthenticatedRequestWithRetry(request: request)

        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            AppLogger.auth.debug("Upload response: \(responseString)")
        }

        let uploadResponse = try JSONDecoder().decode(ProfileImageUploadResponse.self, from: data)

        // Update current user with new image URLs
        if let currentUser = currentUser {
            let oldImageUrl = currentUser.profileImageUrl

            // Ensure URLs have proper protocol
            let imageUrl = uploadResponse.profileImageUrl.hasPrefix("http") ? uploadResponse.profileImageUrl : "https://\(uploadResponse.profileImageUrl)"
            let thumbnailUrl = uploadResponse.profileImageThumbnailUrl.hasPrefix("http") ? uploadResponse.profileImageThumbnailUrl : "https://\(uploadResponse.profileImageThumbnailUrl)"

            let updatedUser = UserInfo(
                id: currentUser.id,
                email: currentUser.email,
                username: currentUser.username,
                createdAt: currentUser.createdAt,
                profileImageUrl: imageUrl,
                profileImageThumbnailUrl: thumbnailUrl,
                bio: currentUser.bio,
                location: currentUser.location,
                nationality: currentUser.nationality,
                profileVisibility: currentUser.profileVisibility,
                socialLinks: currentUser.socialLinks,
                communities: currentUser.communities
            )
            self.currentUser = updatedUser
            AppLogger.auth.info("Updated currentUser image URLs: \(oldImageUrl ?? "nil") -> \(updatedUser.profileImageUrl ?? "nil")")
        } else {
            AppLogger.auth.warning("No currentUser to update with image URLs")
        }

        AppLogger.auth.info("Profile image uploaded successfully")

        // Return the updated current user
        guard let updatedUser = currentUser else {
            throw AuthError.invalidResponse
        }

        return updatedUser
    }

    // MARK: - Logout

    private func clearLocalSessionOnly() {
        keychain.deleteAccessToken()
        keychain.deleteRefreshToken()
        isAuthenticated = false
        currentUser = nil
        AppLogger.auth.debug("Local session cleared")
    }
    
    func logout() async {
        AppLogger.auth.info("Logging out user")
        
        // Call backend logout endpoint
        if let accessToken = keychain.getAccessToken() {
            if let url = apiURL(path: "/auth/logout") {
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
                AppLogger.auth.warning("Invalid logout URL, skipping backend logout")
            }
        } else {
            AppLogger.auth.debug("No access token found, skipping backend logout")
        }

        clearLocalSessionOnly()
        AppLogger.auth.info("Logout complete")
    }

    func deleteAccount() async throws {
        AppLogger.auth.info("Deleting account on server")
        guard let url = apiURL(path: "/auth/me") else {
            throw AuthError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        _ = try await makeAuthenticatedRequestWithRetry(request: request)
        clearLocalSessionOnly()
        AppLogger.auth.info("Account deleted; local session cleared")
    }
}