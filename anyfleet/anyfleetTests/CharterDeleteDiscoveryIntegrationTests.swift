//
//  CharterDeleteDiscoveryIntegrationTests.swift
//  anyfleetTests
//
//  Contract test: deleting a published charter triggers server delete and the charter disappears
//  from discovery (simulated API), without requiring a live backend.
//

import Foundation
import Testing
@testable import anyfleet

/// Holds discovery rows; `deleteCharter` on the mock removes by server id.
private final class MutableDiscoveryFeed {
    var items: [CharterWithUserAPIResponse]

    init(items: [CharterWithUserAPIResponse]) {
        self.items = items
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }
}

@Suite("Charter delete → discovery (integration contract)")
struct CharterDeleteDiscoveryIntegrationTests {

    private func makeDiscoveryRow(id: UUID, visibilityWire: String, startDate: Date) -> CharterWithUserAPIResponse {
        CharterWithUserAPIResponse(
            id: id,
            name: "Listed Charter",
            boatName: "Test Boat",
            locationText: "Adriatic",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(86400 * 7),
            latitude: 43.0,
            longitude: 16.0,
            visibility: visibilityWire,
            user: UserBasicAPIResponse(id: UUID(), username: "owner", profileImageThumbnailUrl: nil),
            distanceKm: nil,
            communityBadgeUrl: nil
        )
    }

    @MainActor
    private func assertDeleteRemovesFromDiscovery(visibility: CharterVisibility, visibilityWire: String) async throws {
        let localCharterID = UUID()
        let serverCharterID = UUID()
        let startDate = Date().addingTimeInterval(86400 * 5)

        let row = makeDiscoveryRow(id: serverCharterID, visibilityWire: visibilityWire, startDate: startDate)
        let feed = MutableDiscoveryFeed(items: [row])

        let api = MockAPIClient()
        api.discoverChartersProvider = {
            CharterDiscoveryAPIResponse(
                items: feed.items,
                total: feed.items.count,
                limit: 20,
                offset: 0
            )
        }
        api.deleteCharterSideEffect = { feed.remove(id: $0) }

        let vm = CharterDiscoveryViewModel(apiClient: api, filterDebounceNanoseconds: 0)
        await vm.loadInitial()
        #expect(vm.charters.contains { $0.id == serverCharterID })

        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let authService = MockAuthService()
        authService.mockIsAuthenticated = true
        let syncService = CharterSyncService(
            repository: mockRepository,
            apiClient: api,
            charterStore: store,
            authService: authService
        )
        store.setDiscoveryUnpublisher(syncService)

        var charter = CharterModel(
            id: localCharterID,
            name: row.name,
            boatName: row.boatName,
            location: row.locationText,
            startDate: row.startDate,
            endDate: row.endDate,
            createdAt: Date(),
            checkInChecklistID: nil
        )
        charter.serverID = serverCharterID
        charter.visibility = visibility

        mockRepository.saveCharterResult = .success(())
        try await store.saveCharter(charter)

        mockRepository.deleteCharterResult = .success(())
        try await store.deleteCharter(localCharterID)

        #expect(api.deleteCharterCallCount == 1)
        #expect(api.lastDeletedCharterID == serverCharterID)

        await vm.refresh()
        #expect(vm.charters.isEmpty)
    }

    @Test("Deleting community-synced charter removes it from subsequent discovery")
    @MainActor
    func testDeleteCommunityCharter_RemovedFromDiscoveryFeed() async throws {
        try await assertDeleteRemovesFromDiscovery(visibility: .community, visibilityWire: "community")
    }

    @Test("Deleting public-synced charter removes it from subsequent discovery")
    @MainActor
    func testDeletePublicCharter_RemovedFromDiscoveryFeed() async throws {
        try await assertDeleteRemovesFromDiscovery(visibility: .public, visibilityWire: "public")
    }
}
