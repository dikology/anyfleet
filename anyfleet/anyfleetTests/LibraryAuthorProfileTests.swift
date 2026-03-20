//
//  LibraryAuthorProfileTests.swift
//  anyfleetTests
//
//  Tests for author profile navigation from forked library content.
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Library Author Profile Tests")
struct LibraryAuthorProfileTests {

    // MARK: - Mock API Client

    /// Configurable mock that lets tests control success/failure and captured calls.
    class MockAuthorProfileAPIClient: APIClientProtocol {
        var profileToReturn: PublicProfileResponse?
        var shouldFail = false
        private(set) var fetchProfileCalls: [String] = []

        func fetchPublicProfile(username: String) async throws -> PublicProfileResponse {
            fetchProfileCalls.append(username)
            if shouldFail { throw APIError.serverError }
            return profileToReturn ?? PublicProfileResponse(
                id: UUID(),
                username: username,
                profileImageUrl: nil,
                profileImageThumbnailUrl: nil,
                bio: "Test bio",
                location: "Test location",
                nationality: "Test nationality",
                isVerified: true,
                verificationTier: nil,
                createdAt: Date(),
                stats: PublicProfileStatsResponse(
                    totalContributions: 10,
                    averageRating: 4.5,
                    totalForks: 5
                ),
                socialLinks: nil,
                primaryCommunity: nil
            )
        }

        func fetchPublicProfileByUserId(_ userId: UUID) async throws -> PublicProfileResponse {
            return try await fetchPublicProfile(username: "user-\(userId.uuidString.prefix(8))")
        }

        func fetchProfileStats() async throws -> ProfileStatsAPIResponse {
            ProfileStatsAPIResponse(totalContributions: 0, averageRating: nil, totalForks: 0, communitiesJoined: 0, daysAtSea: 0)
        }
        func searchCommunities(query: String, limit: Int = 10) async throws -> [CommunitySearchResult] { [] }
        func createCommunity(name: String) async throws -> CreateAndJoinCommunityResponse {
            CreateAndJoinCommunityResponse(communityId: UUID().uuidString, communityName: name, role: .member, message: "Joined community")
        }
        func joinCommunity(id: String) async throws {}
        func leaveCommunity(id: String) async throws {}

        // Content API stubs (unused in these tests)
        func publishContent(title: String, description: String?, contentType: String, contentData: [String: Any], tags: [String], language: String, publicID: String, canFork: Bool, forkedFromID: UUID?) async throws -> PublishContentResponse {
            PublishContentResponse(id: UUID(), publicID: publicID, publishedAt: Date(), authorUsername: "mock", authorUserId: nil, canFork: canFork)
        }
        func unpublishContent(publicID: String) async throws {}
        func fetchPublicContent() async throws -> [SharedContentSummary] { [] }
        func fetchPublicContent(publicID: String) async throws -> SharedContentDetail {
            SharedContentDetail(id: UUID(), title: "Mock", description: nil, contentType: "checklist", contentData: [:], tags: [], publicID: publicID, canFork: true, authorUsername: "mock", authorUserId: nil, viewCount: 0, forkCount: 0, createdAt: Date(), updatedAt: Date())
        }
        func incrementForkCount(publicID: String) async throws {}
        func updatePublishedContent(publicID: String, title: String, description: String?, contentType: String, contentData: [String: Any], tags: [String], language: String) async throws -> UpdateContentResponse {
            UpdateContentResponse(id: UUID(), publicID: publicID, updatedAt: Date())
        }

        // Charter API stubs (unused in these tests)
        func createCharter(_ request: CharterCreateRequest) async throws -> CharterAPIResponse {
            CharterAPIResponse(id: UUID(), userId: UUID(), name: request.name, boatName: nil, locationText: nil, startDate: request.startDate, endDate: request.endDate, latitude: nil, longitude: nil, locationPlaceId: nil, visibility: "private", createdAt: Date(), updatedAt: Date(), virtualCaptainId: nil)
        }
        func fetchMyCharters() async throws -> CharterListAPIResponse { CharterListAPIResponse(items: [], total: 0, limit: 20, offset: 0) }
        func fetchCharter(id: UUID) async throws -> CharterAPIResponse {
            CharterAPIResponse(id: id, userId: UUID(), name: "Mock", boatName: nil, locationText: nil, startDate: Date(), endDate: Date(), latitude: nil, longitude: nil, locationPlaceId: nil, visibility: "private", createdAt: Date(), updatedAt: Date(), virtualCaptainId: nil)
        }
        func updateCharter(id: UUID, request: CharterUpdateRequest) async throws -> CharterAPIResponse {
            CharterAPIResponse(id: id, userId: UUID(), name: request.name ?? "Mock", boatName: nil, locationText: nil, startDate: request.startDate ?? Date(), endDate: request.endDate ?? Date(), latitude: nil, longitude: nil, locationPlaceId: nil, visibility: "private", createdAt: Date(), updatedAt: Date(), virtualCaptainId: nil)
        }
        func deleteCharter(id: UUID) async throws {}
        func discoverCharters(dateFrom: Date?, dateTo: Date?, nearLat: Double?, nearLon: Double?, radiusKm: Double, sortBy: String, limit: Int, offset: Int) async throws -> CharterDiscoveryAPIResponse {
            CharterDiscoveryAPIResponse(items: [], total: 0, limit: limit, offset: offset)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(apiClient: APIClientProtocol) -> LibraryListViewModel {
        LibraryListViewModel(
            libraryStore: MockMinimalLibraryStore(),
            visibilityService: MockMinimalVisibilityService(),
            authObserver: MockMinimalAuthObserver(),
            coordinator: MockMinimalCoordinator(),
            apiClient: apiClient
        )
    }

    // MARK: - fetchAndShowAuthorProfile Tests

    @MainActor
    @Test("fetchAndShowAuthorProfile sets activeModal to .authorProfile on success")
    func testFetchAuthorProfileSuccess() async {
        let apiClient = MockAuthorProfileAPIClient()
        let viewModel = makeViewModel(apiClient: apiClient)

        await viewModel.fetchAndShowAuthorProfile(username: "SailorMaria")

        guard case .authorProfile(let author) = viewModel.activeModal else {
            Issue.record("Expected activeModal to be .authorProfile, got \(String(describing: viewModel.activeModal))")
            return
        }
        #expect(author.username == "SailorMaria")
        #expect(apiClient.fetchProfileCalls == ["SailorMaria"])
    }

    @MainActor
    @Test("fetchAndShowAuthorProfile maps profile fields correctly")
    func testFetchAuthorProfileFieldMapping() async {
        let apiClient = MockAuthorProfileAPIClient()
        apiClient.profileToReturn = PublicProfileResponse(
            id: UUID(),
            username: "CaptainJohn",
            profileImageUrl: "https://example.com/avatar.jpg",
            profileImageThumbnailUrl: nil,
            bio: "Master sailor",
            location: "Atlantic Ocean",
            nationality: "British",
            isVerified: true,
            verificationTier: nil,
            createdAt: Date(),
            stats: PublicProfileStatsResponse(
                totalContributions: 42,
                averageRating: 4.9,
                totalForks: 18
            ),
            socialLinks: nil,
            primaryCommunity: nil
        )
        let viewModel = makeViewModel(apiClient: apiClient)

        await viewModel.fetchAndShowAuthorProfile(username: "CaptainJohn")

        guard case .authorProfile(let author) = viewModel.activeModal else {
            Issue.record("Expected .authorProfile modal")
            return
        }
        #expect(author.username == "CaptainJohn")
        #expect(author.bio == "Master sailor")
        #expect(author.location == "Atlantic Ocean")
        #expect(author.isVerified == true)
        #expect(author.stats?.totalContributions == 42)
    }

    @MainActor
    @Test("fetchAndShowAuthorProfile sets error and does not show modal on API failure")
    func testFetchAuthorProfileFailure() async {
        let apiClient = MockAuthorProfileAPIClient()
        apiClient.shouldFail = true
        let viewModel = makeViewModel(apiClient: apiClient)

        await viewModel.fetchAndShowAuthorProfile(username: "NavExpert")

        #expect(viewModel.activeModal == nil, "Modal should not be set when API fails")
        #expect(viewModel.currentError != nil, "Error should be set when API fails")
        #expect(apiClient.fetchProfileCalls == ["NavExpert"], "API should have been called once")
    }

    @MainActor
    @Test("dismissModal clears the authorProfile modal")
    func testDismissAuthorProfileModal() async {
        let apiClient = MockAuthorProfileAPIClient()
        let viewModel = makeViewModel(apiClient: apiClient)

        await viewModel.fetchAndShowAuthorProfile(username: "SailorMaria")
        #expect(viewModel.activeModal != nil, "Modal should be set after successful fetch")

        viewModel.dismissModal()

        #expect(viewModel.activeModal == nil, "Modal should be cleared after dismiss")
    }

    @MainActor
    @Test("Consecutive fetches update activeModal to the most recent author")
    func testConsecutiveFetchesSetsCorrectAuthor() async {
        let apiClient = MockAuthorProfileAPIClient()
        let viewModel = makeViewModel(apiClient: apiClient)

        await viewModel.fetchAndShowAuthorProfile(username: "FirstAuthor")
        guard case .authorProfile(let first) = viewModel.activeModal else {
            Issue.record("Expected .authorProfile after first fetch")
            return
        }
        #expect(first.username == "FirstAuthor")

        viewModel.dismissModal()

        await viewModel.fetchAndShowAuthorProfile(username: "SecondAuthor")
        guard case .authorProfile(let second) = viewModel.activeModal else {
            Issue.record("Expected .authorProfile after second fetch")
            return
        }
        #expect(second.username == "SecondAuthor")
        #expect(apiClient.fetchProfileCalls == ["FirstAuthor", "SecondAuthor"])
    }

    // MARK: - LibraryModal.authorProfile Tests

    @Test("LibraryModal.authorProfile id is stable and username-based")
    func testLibraryModalAuthorProfileId() {
        let author = AuthorProfile(
            username: "TestSailor",
            email: "",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            isVerified: false,
            stats: nil
        )
        let modal = LibraryModal.authorProfile(author)
        #expect(modal.id == "author-TestSailor")
    }

    @Test("LibraryModal.authorProfile id is distinct from other modal ids")
    func testLibraryModalAuthorProfileIdIsDistinct() {
        let author = AuthorProfile(
            username: "SomeUser",
            email: "",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            isVerified: false,
            stats: nil
        )
        let authorModal = LibraryModal.authorProfile(author)
        let signInModal = LibraryModal.signIn

        #expect(authorModal.id != signInModal.id)
        #expect(authorModal.id == "author-SomeUser")
    }
}

// MARK: - Minimal protocol stubs for LibraryAuthorProfileTests

@MainActor
private class MockMinimalLibraryStore: LibraryStoreProtocol {
    var library: [LibraryModel] { [] }
    var myChecklists: [LibraryModel] { [] }
    var myGuides: [LibraryModel] { [] }
    func fetchLibraryItem(_ id: UUID) async throws -> LibraryModel? { nil }
    func loadLibrary() async {}
    func createChecklist(_ checklist: Checklist) async throws {}
    func createGuide(_ guide: PracticeGuide) async throws {}
    func createDeck(_ deck: FlashcardDeck) async throws {}
    func forkContent(from sharedContent: SharedContentDetail) async throws {}
    func saveChecklist(_ checklist: Checklist) async throws {}
    func saveGuide(_ guide: PracticeGuide) async throws {}
    func updateLibraryMetadata(_ item: LibraryModel) async throws {}
    func deleteContent(_ item: LibraryModel, shouldUnpublish: Bool) async throws {}
    func fetchChecklist(_ checklistID: UUID) async throws -> Checklist { throw LibraryError.notFound(checklistID) }
    func fetchGuide(_ guideID: UUID) async throws -> PracticeGuide { throw LibraryError.notFound(guideID) }
    func fetchFullContent<T>(_ id: UUID) async throws -> T? { nil }
    func togglePin(for item: LibraryModel) async {}
}

private class MockMinimalVisibilityService: VisibilityServiceProtocol {
    func publishContent(_ item: LibraryModel) async throws -> SyncSummary { SyncSummary(succeeded: 1, failed: 0) }
    func unpublishContent(_ item: LibraryModel) async throws -> SyncSummary { SyncSummary(succeeded: 1, failed: 0) }
    func retrySync(for item: LibraryModel) async {}
}

@MainActor
private class MockMinimalAuthObserver: AuthStateObserverProtocol {
    var isSignedIn: Bool { false }
    var currentUser: UserInfo? { nil }
    var currentUserID: UUID? { nil }
}

private class MockMinimalCoordinator: AppCoordinatorProtocol {
    func editChecklist(_ id: UUID?) {}
    func editGuide(_ id: UUID?) {}
    func editDeck(_ id: UUID?) {}
    func viewChecklist(_ id: UUID) {}
    func viewGuide(_ id: UUID) {}
    func push(_ route: AppRoute, to tab: AppView.Tab) {}
    func navigateToLibrary() {}
}
