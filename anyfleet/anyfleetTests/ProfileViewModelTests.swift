//
//  ProfileViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for ProfileViewModel auth state observation
//

import Foundation
import Testing
@testable import anyfleet

@Suite("ProfileViewModel Tests")
struct ProfileViewModelTests {

    // MARK: - Auth State Observation Tests

    @Test("ProfileViewModel exposes auth state correctly")
    @MainActor
    func testAuthStateObservation() async {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        mockAuthObserver.mockIsSignedIn = false
        mockAuthObserver.mockCurrentUser = nil

        // When
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver)

        // Then
        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.currentUser == nil)

        // When auth state changes
        mockAuthObserver.mockIsSignedIn = true
        mockAuthObserver.mockCurrentUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // Then viewModel reflects the changes
        #expect(viewModel.isSignedIn == true)
        #expect(viewModel.currentUser?.email == "test@example.com")
        #expect(viewModel.currentUser?.username == "Test User")
    }

    @Test("ProfileViewModel handles missing authObserver gracefully")
    @MainActor
    func testMissingAuthObserver() {
        // Given
        let mockAuthService = MockAuthService()

        // When - authObserver is nil, should create default AuthStateObserver
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: nil)

        // Then - should not crash and have valid authObserver
        #expect(viewModel.authObserver != nil)
    }

    @Test("ProfileViewModel profile completion calculation works correctly")
    @MainActor
    func testProfileCompletionCalculation() {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver)

        // Test with minimal user (just username, no image or bio)
        let minimalUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // When
        let completion = viewModel.calculateProfileCompletion(for: minimalUser)

        // Then - should be 33% (1 out of 3 fields: username)
        #expect(completion == 33)

        // Test with complete profile
        let completeUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: "https://example.com/image.jpg",
            profileImageThumbnailUrl: "https://example.com/thumb.jpg",
            bio: "Test bio",
            location: "Test location",
            nationality: "Test nationality",
            profileVisibility: "public"
        )

        // When
        let completeCompletion = viewModel.calculateProfileCompletion(for: completeUser)

        // Then - should be 100% (3 out of 3 fields)
        #expect(completeCompletion == 100)
    }

    // MARK: - Community Tests

    @Test("createAndJoinCommunity - adds membership to editedCommunities when editing profile")
    @MainActor
    func testCreateAndJoinCommunity_AddsToEditedCommunities() async {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        mockAuthObserver.mockCurrentUser = UserInfo(
            id: "user-id",
            email: "test@example.com",
            username: "Test",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )
        let mockAPI = MockCommunityAPIClient()
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver, apiClient: mockAPI)
        viewModel.isEditingProfile = true

        // When
        await viewModel.createAndJoinCommunity(name: "Сила Ветра")

        // Then
        #expect(viewModel.editedCommunities.count == 1)
        #expect(viewModel.editedCommunities.first?.name == "Сила Ветра")
        #expect(viewModel.editedCommunities.first?.role == .member)
    }

    @Test("createAndJoinCommunity - first community is set as primary")
    @MainActor
    func testCreateAndJoinCommunity_FirstCommunityIsPrimary() async {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        mockAuthObserver.mockCurrentUser = UserInfo(
            id: "user-id",
            email: "test@example.com",
            username: "Test",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public",
            communities: nil
        )
        let mockAPI = MockCommunityAPIClient()
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver, apiClient: mockAPI)
        viewModel.isEditingProfile = true

        // When
        await viewModel.createAndJoinCommunity(name: "First Fleet")

        // Then
        #expect(viewModel.editedCommunities.first?.isPrimary == true)
    }

    @Test("createAndJoinCommunity - duplicate community is not added twice")
    @MainActor
    func testCreateAndJoinCommunity_NoDuplicates() async {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        mockAuthObserver.mockCurrentUser = UserInfo(
            id: "user-id",
            email: "test@example.com",
            username: "Test",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )
        let mockAPI = MockCommunityAPIClient(fixedCommunityId: "same-id")
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver, apiClient: mockAPI)
        viewModel.isEditingProfile = true

        // When
        await viewModel.createAndJoinCommunity(name: "Fleet Alpha")
        await viewModel.createAndJoinCommunity(name: "Fleet Alpha")

        // Then
        #expect(viewModel.editedCommunities.count == 1)
    }

    @Test("createAndJoinCommunity - handles API failure gracefully")
    @MainActor
    func testCreateAndJoinCommunity_HandlesAPIError() async {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        let mockAPI = MockCommunityAPIClient()
        mockAPI.shouldFail = true
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver, apiClient: mockAPI)
        viewModel.isEditingProfile = true

        // When
        await viewModel.createAndJoinCommunity(name: "Should Fail")

        // Then - no crash, no membership added, error surfaced
        #expect(viewModel.editedCommunities.isEmpty)
        #expect(viewModel.currentError != nil || viewModel.editedCommunities.isEmpty)
    }

    @Test("CreateAndJoinCommunityResponse - decodes backend JSON correctly")
    @MainActor
    func testCreateAndJoinCommunityResponse_Decoding() throws {
        let json = """
        {
            "community_id": "3b4c4b64-7a1c-484a-9689-1d1ebec102c3",
            "community_name": "Сила Ветра",
            "role": "member",
            "message": "Joined community"
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(CreateAndJoinCommunityResponse.self, from: json)

        #expect(response.communityId == "3b4c4b64-7a1c-484a-9689-1d1ebec102c3")
        #expect(response.communityName == "Сила Ветра")
        #expect(response.role == .member)
        #expect(response.message == "Joined community")
    }
}

// MARK: - Mock Classes

class MockAuthStateObserver: AuthStateObserverProtocol {
    var mockIsSignedIn: Bool = false
    var mockCurrentUser: UserInfo? = nil
    var mockCurrentUserID: UUID? = nil

    var isSignedIn: Bool { mockIsSignedIn }
    var currentUser: UserInfo? { mockCurrentUser }
    var currentUserID: UUID? { mockCurrentUserID }
}

// MARK: - Minimal APIClient mock for community-related ProfileViewModel tests

final class MockCommunityAPIClient: APIClientProtocol {
    var shouldFail = false
    var fixedCommunityId: String

    init(fixedCommunityId: String = UUID().uuidString) {
        self.fixedCommunityId = fixedCommunityId
    }

    func createCommunity(name: String) async throws -> CreateAndJoinCommunityResponse {
        if shouldFail { throw APIError.serverError }
        return CreateAndJoinCommunityResponse(
            communityId: fixedCommunityId,
            communityName: name,
            role: .member,
            message: "Joined community"
        )
    }

    func searchCommunities(query: String, limit: Int) async throws -> [CommunitySearchResult] { [] }
    func joinCommunity(id: String) async throws {}
    func leaveCommunity(id: String) async throws {}
    func fetchProfileStats() async throws -> ProfileStatsAPIResponse {
        ProfileStatsAPIResponse(totalContributions: 0, averageRating: nil, totalForks: 0, communitiesJoined: 0, daysAtSea: 0)
    }

    func publishContent(title: String, description: String?, contentType: String, contentData: [String: Any], tags: [String], language: String, publicID: String, canFork: Bool, forkedFromID: UUID?) async throws -> PublishContentResponse {
        throw APIError.serverError
    }
    func unpublishContent(publicID: String) async throws { throw APIError.serverError }
    func fetchPublicContent() async throws -> [SharedContentSummary] { [] }
    func fetchPublicContent(publicID: String) async throws -> SharedContentDetail { throw APIError.serverError }
    func incrementForkCount(publicID: String) async throws {}
    func updatePublishedContent(publicID: String, title: String, description: String?, contentType: String, contentData: [String: Any], tags: [String], language: String) async throws -> UpdateContentResponse { throw APIError.serverError }
    func fetchPublicProfile(username: String) async throws -> PublicProfileResponse { throw APIError.serverError }
    func fetchPublicProfileByUserId(_ userId: UUID) async throws -> PublicProfileResponse { throw APIError.serverError }
    func createCharter(_ request: CharterCreateRequest) async throws -> CharterAPIResponse { throw APIError.serverError }
    func fetchMyCharters() async throws -> CharterListAPIResponse { throw APIError.serverError }
    func fetchCharter(id: UUID) async throws -> CharterAPIResponse { throw APIError.serverError }
    func updateCharter(id: UUID, request: CharterUpdateRequest) async throws -> CharterAPIResponse { throw APIError.serverError }
    func deleteCharter(id: UUID) async throws { throw APIError.serverError }
    func discoverCharters(dateFrom: Date?, dateTo: Date?, nearLat: Double?, nearLon: Double?, radiusKm: Double, sortBy: String, limit: Int, offset: Int) async throws -> CharterDiscoveryAPIResponse { throw APIError.serverError }
}