//
//  MockAuthService.swift
//  anyfleetTests
//
//  Mock auth service for unit testing
//

import Foundation
import AuthenticationServices
@testable import anyfleet

/// Mock auth service that implements AuthServiceProtocol for testing
final class MockAuthService: AuthServiceProtocol {
    var mockAccessToken: String = "mock_access_token_123"
    var shouldFail = false
    var getAccessTokenCallCount = 0
    var refreshCallCount = 0
    var shouldFailRefresh = false
    /// When set, `getAccessToken` returns the first element then advances to the next.
    /// Use this to simulate an expired token followed by a fresh one post-refresh.
    var tokenSequence: [String] = []
    var mockIsAuthenticated = true
    var mockCurrentUser: UserInfo?

    var isAuthenticated: Bool {
        mockIsAuthenticated
    }

    var currentUser: UserInfo? {
        mockCurrentUser
    }

    func getAccessToken() async throws -> String {
        getAccessTokenCallCount += 1
        if shouldFail {
            throw AuthError.invalidToken
        }
        if !tokenSequence.isEmpty {
            return tokenSequence.removeFirst()
        }
        return mockAccessToken
    }

    func refreshAccessToken() async throws {
        refreshCallCount += 1
        if shouldFailRefresh {
            throw AuthError.unauthorized
        }
    }

    func ensureCurrentUserLoaded() async throws {
        // For mock, just ensure currentUser is set if authenticated
        if mockIsAuthenticated && mockCurrentUser == nil {
            mockCurrentUser = UserInfo(
                id: "mock-user-id",
                email: "mock@example.com",
                username: "mockuser",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                profileImageUrl: nil,
                profileImageThumbnailUrl: nil,
                bio: nil,
                location: nil,
                nationality: nil,
                profileVisibility: "public",
                socialLinks: nil,
                communities: nil
            )
        }

        if !mockIsAuthenticated {
            throw AuthError.unauthorized
        }
    }

    func loadCurrentUser() async {
        // Mock: no-op or could refresh from a mock source
    }

    func logout() async {
        mockIsAuthenticated = false
        mockCurrentUser = nil
    }

    func deleteAccount() async throws {
        mockIsAuthenticated = false
        mockCurrentUser = nil
    }

    func updateProfile(
        username: String?,
        bio: String?,
        location: String?,
        nationality: String?,
        profileVisibility: String?,
        socialLinks: [SocialLink]?,
        communityMemberships: [CommunityMembership]?
    ) async throws -> UserInfo {
        guard var user = mockCurrentUser else {
            throw AuthError.unauthorized
        }

        user = UserInfo(
            id: user.id,
            email: user.email,
            username: username ?? user.username,
            createdAt: user.createdAt,
            profileImageUrl: user.profileImageUrl,
            profileImageThumbnailUrl: user.profileImageThumbnailUrl,
            bio: bio ?? user.bio,
            location: location ?? user.location,
            nationality: nationality ?? user.nationality,
            profileVisibility: profileVisibility ?? user.profileVisibility,
            socialLinks: socialLinks ?? user.socialLinks,
            communities: communityMemberships ?? user.communities
        )

        mockCurrentUser = user
        return user
    }

    func uploadProfileImage(_ imageData: Data) async throws -> UserInfo {
        // For mock, simulate successful upload by updating current user with new image URLs
        guard var user = mockCurrentUser else {
            throw AuthError.unauthorized
        }

        // Create mock URLs for the uploaded image
        let mockImageUrl = "https://example.com/uploads/profile_\(UUID().uuidString).jpg"
        let mockThumbnailUrl = "https://example.com/uploads/profile_\(UUID().uuidString)_thumb.jpg"

        user = UserInfo(
            id: user.id,
            email: user.email,
            username: user.username,
            createdAt: user.createdAt,
            profileImageUrl: mockImageUrl,
            profileImageThumbnailUrl: mockThumbnailUrl,
            bio: user.bio,
            location: user.location,
            nationality: user.nationality,
            profileVisibility: user.profileVisibility,
            socialLinks: user.socialLinks,
            communities: user.communities
        )

        mockCurrentUser = user
        return user
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async throws {
        // For mock, just set authenticated state
        switch result {
        case .success:
            mockIsAuthenticated = true
            mockCurrentUser = UserInfo(
                id: "apple-user-id",
                email: "apple@example.com",
                username: "Apple User",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                profileImageUrl: nil,
                profileImageThumbnailUrl: nil,
                bio: nil,
                location: nil,
                nationality: nil,
                profileVisibility: "public",
                socialLinks: nil,
                communities: nil
            )
        case .failure:
            throw AuthError.invalidToken
        }
    }
}
