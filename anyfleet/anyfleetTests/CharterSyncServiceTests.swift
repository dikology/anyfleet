//
//  CharterSyncServiceTests.swift
//  anyfleetTests
//
//  Unit tests for CharterSyncService using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterSyncService Tests")
struct CharterSyncServiceTests {

    // MARK: - Helpers

    @MainActor
    private func makeDependencies(
        isAuthenticated: Bool = true
    ) -> (
        repository: MockLocalRepository,
        apiClient: MockAPIClient,
        store: CharterStore,
        authService: MockAuthService,
        service: CharterSyncService
    ) {
        let repository = MockLocalRepository()
        let apiClient = MockAPIClient()
        let store = CharterStore(repository: repository)
        let authService = MockAuthService()
        authService.mockIsAuthenticated = isAuthenticated
        let service = CharterSyncService(
            repository: repository,
            apiClient: apiClient,
            charterStore: store,
            authService: authService
        )
        return (repository, apiClient, store, authService, service)
    }

    private func makeCharter(
        serverID: UUID? = nil,
        visibility: CharterVisibility = .community,
        needsSync: Bool = true
    ) -> CharterModel {
        var charter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: "Blue Wave",
            location: "Mallorca",
            startDate: Date().addingTimeInterval(86400),
            endDate: Date().addingTimeInterval(86400 * 8),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        charter.serverID = serverID
        charter.visibility = visibility
        charter.needsSync = needsSync
        return charter
    }

    // MARK: - pushPendingCharters

    @Test("pushPendingCharters - skips when no pending charters")
    @MainActor
    func testPushPendingCharters_NoPending() async {
        let (repository, apiClient, _, _, service) = makeDependencies()
        repository.fetchPendingSyncChartersResult = .success([])

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 0)
        #expect(apiClient.updateCharterCallCount == 0)
        #expect(repository.markCharterSyncedCallCount == 0)
    }

    @Test("pushPendingCharters - skips private charters")
    @MainActor
    func testPushPendingCharters_SkipsPrivate() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let privateCharter = makeCharter(visibility: .private)
        repository.fetchPendingSyncChartersResult = .success([privateCharter])

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 0)
        #expect(apiClient.updateCharterCallCount == 0)
        #expect(repository.markCharterSyncedCallCount == 0)
    }

    @Test("pushPendingCharters - creates new charter when no serverID")
    @MainActor
    func testPushPendingCharters_CreatesNewCharter() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let charter = makeCharter(serverID: nil, visibility: .community)
        repository.fetchPendingSyncChartersResult = .success([charter])

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 1)
        #expect(apiClient.updateCharterCallCount == 0)
        #expect(repository.markCharterSyncedCallCount == 1)
        #expect(repository.lastMarkedSyncedID == charter.id)
        #expect(service.lastSyncDate != nil)
        #expect(service.lastSyncError == nil)
    }

    @Test("pushPendingCharters - updates existing charter when serverID present")
    @MainActor
    func testPushPendingCharters_UpdatesExistingCharter() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let existingServerID = UUID()
        let charter = makeCharter(serverID: existingServerID, visibility: .public)
        repository.fetchPendingSyncChartersResult = .success([charter])

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 0)
        #expect(apiClient.updateCharterCallCount == 1)
        #expect(repository.markCharterSyncedCallCount == 1)
        #expect(repository.lastMarkedSyncedID == charter.id)
    }

    @Test("pushPendingCharters - mixes create and update for multiple charters")
    @MainActor
    func testPushPendingCharters_MixedCreateUpdate() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let newCharter = makeCharter(serverID: nil, visibility: .community)
        let existingCharter = makeCharter(serverID: UUID(), visibility: .public)
        let privateCharter = makeCharter(visibility: .private)
        repository.fetchPendingSyncChartersResult = .success([newCharter, existingCharter, privateCharter])

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 1)
        #expect(apiClient.updateCharterCallCount == 1)
        #expect(repository.markCharterSyncedCallCount == 2)
    }

    @Test("pushPendingCharters - handles repository fetch error gracefully")
    @MainActor
    func testPushPendingCharters_FetchError() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let testError = NSError(domain: "TestError", code: 1)
        repository.fetchPendingSyncChartersResult = .failure(testError)

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 0)
        #expect(service.lastSyncError != nil)
        #expect(service.lastSyncDate == nil)
    }

    @Test("pushPendingCharters - handles API error gracefully without crashing")
    @MainActor
    func testPushPendingCharters_APIError() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let charter = makeCharter(serverID: nil, visibility: .community)
        repository.fetchPendingSyncChartersResult = .success([charter])
        apiClient.shouldFail = true

        await service.pushPendingCharters()

        #expect(repository.markCharterSyncedCallCount == 0)
        #expect(service.lastSyncError != nil)
    }

    @Test("pushPendingCharters - isSyncing guard prevents concurrent calls")
    @MainActor
    func testPushPendingCharters_IsSyncingGuard() async {
        let (repository, apiClient, _, _, service) = makeDependencies()
        repository.fetchPendingSyncChartersResult = .success([])

        // First call
        await service.pushPendingCharters()
        #expect(service.isSyncing == false) // should be false after completion

        // Second call while not syncing should work
        await service.pushPendingCharters()
        #expect(repository.fetchPendingSyncChartersCallCount == 2)
    }

    @Test("pushPendingCharters - skips sync and sets needsAuthForSync when unauthenticated")
    @MainActor
    func testPushPendingCharters_UnauthenticatedSetsFlag() async {
        let (repository, apiClient, _, _, service) = makeDependencies(isAuthenticated: false)

        let charter = makeCharter(serverID: nil, visibility: .community)
        repository.fetchPendingSyncChartersResult = .success([charter])

        await service.pushPendingCharters()

        #expect(apiClient.createCharterCallCount == 0)
        #expect(service.needsAuthForSync == true)
        #expect(service.lastSyncDate == nil)
    }

    @Test("pushPendingCharters - clears needsAuthForSync when authenticated")
    @MainActor
    func testPushPendingCharters_ClearsNeedsAuthWhenAuthenticated() async {
        let (repository, apiClient, _, _, service) = makeDependencies(isAuthenticated: true)
        repository.fetchPendingSyncChartersResult = .success([])

        await service.pushPendingCharters()

        #expect(service.needsAuthForSync == false)
        #expect(apiClient.createCharterCallCount == 0)
    }

    // MARK: - pullMyCharters

    @Test("pullMyCharters - calls API and saves returned charters")
    @MainActor
    func testPullMyCharters_Success() async {
        let (repository, apiClient, store, _, service) = makeDependencies()

        let serverID = UUID()
        let remoteCharter = CharterAPIResponse(
            id: serverID,
            userId: UUID(),
            name: "Remote Charter",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "private",
            createdAt: Date(),
            updatedAt: Date()
        )
        apiClient.mockFetchMyChartersResponse = CharterListAPIResponse(
            items: [remoteCharter],
            total: 1,
            limit: 20,
            offset: 0
        )
        // Let loadCharters succeed
        repository.fetchAllChartersResult = .success([remoteCharter.toCharterModel()])

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 1)
        #expect(service.lastSyncDate != nil)
        #expect(service.lastSyncError == nil)
    }

    @Test("pullMyCharters - handles API error gracefully")
    @MainActor
    func testPullMyCharters_APIError() async {
        let (repository, apiClient, _, _, service) = makeDependencies()
        apiClient.shouldFail = true

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 0)
        #expect(service.lastSyncError != nil)
        #expect(service.lastSyncDate == nil)
    }

    @Test("pullMyCharters - empty response results in no saves")
    @MainActor
    func testPullMyCharters_EmptyResponse() async {
        let (repository, _, _, _, service) = makeDependencies()
        // mockFetchMyChartersResponse is nil → defaults to empty list

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 0)
        #expect(service.lastSyncDate != nil)
    }

    // MARK: - syncAll

    @Test("syncAll - calls both push and pull")
    @MainActor
    func testSyncAll_CallsBothOperations() async {
        let (repository, _, _, _, service) = makeDependencies()
        repository.fetchPendingSyncChartersResult = .success([])

        await service.syncAll()

        #expect(repository.fetchPendingSyncChartersCallCount == 1) // push was called
    }

    // MARK: - State Tracking

    @Test("isSyncing - is false initially")
    @MainActor
    func testIsSyncing_InitiallyFalse() {
        let (_, _, _, _, service) = makeDependencies()
        #expect(service.isSyncing == false)
    }

    @Test("lastSyncDate - is nil initially")
    @MainActor
    func testLastSyncDate_InitiallyNil() {
        let (_, _, _, _, service) = makeDependencies()
        #expect(service.lastSyncDate == nil)
    }

    @Test("lastSyncError - is nil initially")
    @MainActor
    func testLastSyncError_InitiallyNil() {
        let (_, _, _, _, service) = makeDependencies()
        #expect(service.lastSyncError == nil)
    }

    @Test("lastSyncDate - is set after successful push")
    @MainActor
    func testLastSyncDate_SetAfterSuccess() async {
        let (repository, _, _, _, service) = makeDependencies()
        let charter = makeCharter(serverID: nil, visibility: .community)
        repository.fetchPendingSyncChartersResult = .success([charter])

        let before = Date()
        await service.pushPendingCharters()
        let after = Date()

        #expect(service.lastSyncDate != nil)
        if let syncDate = service.lastSyncDate {
            #expect(syncDate >= before)
            #expect(syncDate <= after)
        }
    }
}
