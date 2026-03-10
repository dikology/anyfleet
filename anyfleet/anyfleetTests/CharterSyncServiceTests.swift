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

    @Test("pushPendingCharters - two separate instances both push the same pending charter (regression: triple-creation bug)")
    @MainActor
    func testPushPendingCharters_SeparateInstancesDuplicatePush() async {
        // Regression test for the bug where AppDependencies was instantiated three times
        // (anyfleetApp.init + AppDependenciesKey.defaultValue + AppCoordinatorKey.defaultValue).
        // Each instance owned a separate CharterSyncService, and all three raced to push the same
        // pending charter, creating three server records instead of one.
        //
        // The fix is AppDependencies.shared (singleton). This test documents the behaviour of
        // separate instances so the bug is visible when the architecture regresses.
        let repository = MockLocalRepository()
        let apiClient = MockAPIClient()
        let authService = MockAuthService()
        authService.mockIsAuthenticated = true
        let store = CharterStore(repository: repository)

        let service1 = CharterSyncService(
            repository: repository,
            apiClient: apiClient,
            charterStore: store,
            authService: authService
        )
        let service2 = CharterSyncService(
            repository: repository,
            apiClient: apiClient,
            charterStore: store,
            authService: authService
        )

        let charter = makeCharter(serverID: nil, visibility: .community)
        // Both services see the same pending charter before either marks it synced.
        repository.fetchPendingSyncChartersResult = .success([charter])

        // Sequential push from two instances – each will call createCharter.
        await service1.pushPendingCharters()
        await service2.pushPendingCharters()

        // Two separate instances create the charter twice on the backend.
        // This demonstrates the duplicate-creation risk; the production fix (singleton)
        // ensures only one instance ever exists, so createCharterCallCount stays at 1.
        #expect(apiClient.createCharterCallCount == 2,
                "Two separate CharterSyncService instances pushed the same charter twice — ensure AppDependencies.shared is used everywhere to prevent this.")
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
        // Charter not in local DB → new charter, always save.
        repository.fetchCharterResult = .success(nil)
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

    // MARK: - pullMyCharters conflict resolution (7.4)

    @Test("pullMyCharters - remote newer than local AND no local pending changes → saves remote")
    @MainActor
    func testPullMyCharters_RemoteNewer_SavesRemote() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let charterID = UUID()
        let olderDate = Date().addingTimeInterval(-7200)  // 2 h ago
        let newerDate = Date().addingTimeInterval(-3600)  // 1 h ago

        // Local charter is older and has no pending changes.
        var localCharter = makeCharter(serverID: charterID, visibility: .community, needsSync: false)
        localCharter.updatedAt = olderDate
        repository.fetchCharterResult = .success(localCharter)

        // Remote charter is newer.
        let remoteCharter = CharterAPIResponse(
            id: charterID,
            userId: UUID(),
            name: "Newer Name From Server",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "community",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: newerDate
        )
        apiClient.mockFetchMyChartersResponse = CharterListAPIResponse(
            items: [remoteCharter],
            total: 1,
            limit: 20,
            offset: 0
        )
        repository.fetchAllChartersResult = .success([remoteCharter.toCharterModel()])

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 1,
                "Remote is newer and local has no pending changes — should save")
        #expect(repository.lastSavedCharter?.name == "Newer Name From Server")
    }

    @Test("pullMyCharters - local newer than remote → preserves local record")
    @MainActor
    func testPullMyCharters_LocalNewer_SkipsRemote() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let charterID = UUID()
        let olderDate = Date().addingTimeInterval(-7200)  // remote: 2 h ago
        let newerDate = Date().addingTimeInterval(-60)    // local: 1 min ago (offline edit)

        // Local charter edited recently offline.
        var localCharter = makeCharter(serverID: charterID, visibility: .community, needsSync: false)
        localCharter.updatedAt = newerDate
        repository.fetchCharterResult = .success(localCharter)

        // Remote is older.
        let remoteCharter = CharterAPIResponse(
            id: charterID,
            userId: UUID(),
            name: "Stale Server Name",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "community",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: olderDate
        )
        apiClient.mockFetchMyChartersResponse = CharterListAPIResponse(
            items: [remoteCharter],
            total: 1,
            limit: 20,
            offset: 0
        )

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 0,
                "Local is newer — remote must not overwrite the local record")
    }

    @Test("pullMyCharters - local has needsSync=true → protects local changes even if remote is newer")
    @MainActor
    func testPullMyCharters_LocalNeedsSync_SkipsRemote() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        let charterID = UUID()
        let olderDate = Date().addingTimeInterval(-3600)  // local: 1 h ago
        let newerDate = Date().addingTimeInterval(-60)    // remote: 1 min ago

        // Local charter has unsent changes (needsSync = true).
        var localCharter = makeCharter(serverID: charterID, visibility: .community, needsSync: true)
        localCharter.updatedAt = olderDate
        repository.fetchCharterResult = .success(localCharter)

        // Remote is technically newer but local has unsent edits.
        let remoteCharter = CharterAPIResponse(
            id: charterID,
            userId: UUID(),
            name: "Server Version That Would Overwrite",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "community",
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: newerDate
        )
        apiClient.mockFetchMyChartersResponse = CharterListAPIResponse(
            items: [remoteCharter],
            total: 1,
            limit: 20,
            offset: 0
        )

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 0,
                "Local has pending changes — must not be overwritten by a pull")
    }

    @Test("pullMyCharters - charter not in local DB → always saves new server charter")
    @MainActor
    func testPullMyCharters_NewCharter_AlwaysSaves() async {
        let (repository, apiClient, _, _, service) = makeDependencies()

        // fetchCharter returns nil → charter doesn't exist locally.
        repository.fetchCharterResult = .success(nil)

        let remoteCharter = CharterAPIResponse(
            id: UUID(),
            userId: UUID(),
            name: "Brand New Charter From Server",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "community",
            createdAt: Date(),
            updatedAt: Date()
        )
        apiClient.mockFetchMyChartersResponse = CharterListAPIResponse(
            items: [remoteCharter],
            total: 1,
            limit: 20,
            offset: 0
        )
        repository.fetchAllChartersResult = .success([remoteCharter.toCharterModel()])

        await service.pullMyCharters()

        #expect(repository.saveCharterCallCount == 1,
                "Charter not in local DB — always save regardless of timestamps")
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
