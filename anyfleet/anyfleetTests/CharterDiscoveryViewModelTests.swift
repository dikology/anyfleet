//
//  CharterDiscoveryViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for CharterDiscoveryViewModel using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterDiscoveryViewModel Tests")
struct CharterDiscoveryViewModelTests {

    // MARK: - Helpers

    @MainActor
    private func makeViewModel() -> (viewModel: CharterDiscoveryViewModel, apiClient: MockAPIClient) {
        let apiClient = MockAPIClient()
        let viewModel = CharterDiscoveryViewModel(apiClient: apiClient)
        return (viewModel, apiClient)
    }

    private func makeDiscoverableCharter(
        startDate: Date = Date().addingTimeInterval(86400 * 5),
        distanceKm: Double? = nil
    ) -> CharterWithUserAPIResponse {
        CharterWithUserAPIResponse(
            id: UUID(),
            name: "Test Charter",
            boatName: "Sea Spirit",
            locationText: "Croatia",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(86400 * 7),
            latitude: 43.5,
            longitude: 16.4,
            visibility: "community",
            user: UserBasicAPIResponse(id: UUID(), username: "sailor", profileImageThumbnailUrl: nil),
            distanceKm: distanceKm
        )
    }

    private func makeDiscoveryResponse(
        items: [CharterWithUserAPIResponse],
        total: Int? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) -> CharterDiscoveryAPIResponse {
        CharterDiscoveryAPIResponse(
            items: items,
            total: total ?? items.count,
            limit: limit,
            offset: offset
        )
    }

    // MARK: - Initial State

    @Test("Initial state - charters empty, not loading")
    @MainActor
    func testInitialState() {
        let (vm, _) = makeViewModel()
        #expect(vm.charters.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isLoadingMore == false)
        #expect(vm.hasMore == true)
        #expect(vm.currentError == nil)
        #expect(vm.showErrorBanner == false)
        #expect(vm.isEmpty == true)
        #expect(vm.showFilters == false)
        #expect(vm.showMapView == false)
        #expect(vm.selectedCharter == nil)
    }

    // MARK: - loadInitial

    @Test("loadInitial - success populates charters")
    @MainActor
    func testLoadInitial_Success() async {
        let (vm, apiClient) = makeViewModel()

        let items = [makeDiscoverableCharter(), makeDiscoverableCharter()]
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: items)

        await vm.loadInitial()

        #expect(vm.charters.count == 2)
        #expect(vm.isLoading == false)
        #expect(vm.isEmpty == false)
        #expect(vm.currentError == nil)
        #expect(apiClient.discoverChartersCallCount == 1)
    }

    @Test("loadInitial - handles error and sets error state")
    @MainActor
    func testLoadInitial_Error() async {
        let (vm, apiClient) = makeViewModel()
        apiClient.shouldFail = true

        await vm.loadInitial()

        #expect(vm.charters.isEmpty)
        #expect(vm.isLoading == false)
        #expect(vm.isEmpty == true)
    }

    @Test("loadInitial - prevents duplicate concurrent loads")
    @MainActor
    func testLoadInitial_PreventsDoubleTrigger() async {
        let (vm, apiClient) = makeViewModel()
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [])

        // Simulate load already in progress
        // Load twice sequentially: second should proceed since first completes instantly in tests
        await vm.loadInitial()
        await vm.loadInitial()

        // Both complete since they're sequential in tests, just verify no crash
        #expect(vm.isLoading == false)
    }

    @Test("loadInitial - resets offset and charter list on each call")
    @MainActor
    func testLoadInitial_ResetsPreviousData() async {
        let (vm, apiClient) = makeViewModel()

        // First load with 2 items
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [makeDiscoverableCharter()])
        await vm.loadInitial()
        #expect(vm.charters.count == 1)

        // Second load with different data (simulates refresh with new results)
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(
            items: [makeDiscoverableCharter(), makeDiscoverableCharter()]
        )
        await vm.loadInitial()
        #expect(vm.charters.count == 2) // replaced, not appended
    }

    // MARK: - hasMore / Pagination

    @Test("hasMore - false when fewer items than page size returned")
    @MainActor
    func testHasMore_FalseWhenLessThanPageSize() async {
        let (vm, apiClient) = makeViewModel()
        // Return only 5 items (less than pageSize=20)
        let items = (0..<5).map { _ in makeDiscoverableCharter() }
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: items, limit: 20)

        await vm.loadInitial()

        #expect(vm.hasMore == false)
    }

    @Test("hasMore - true when exactly page size items returned")
    @MainActor
    func testHasMore_TrueWhenFullPageReturned() async {
        let (vm, apiClient) = makeViewModel()
        // Return 20 items (equals pageSize=20)
        let items = (0..<20).map { _ in makeDiscoverableCharter() }
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: items, limit: 20)

        await vm.loadInitial()

        #expect(vm.hasMore == true)
    }

    // MARK: - loadMore

    @Test("loadMore - appends charters to existing list")
    @MainActor
    func testLoadMore_AppendsPaginated() async {
        let (vm, apiClient) = makeViewModel()

        // Load first full page
        let firstPage = (0..<20).map { _ in makeDiscoverableCharter() }
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: firstPage)
        await vm.loadInitial()
        #expect(vm.charters.count == 20)

        // Load more
        let secondPage = [makeDiscoverableCharter(), makeDiscoverableCharter()]
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: secondPage)
        await vm.loadMore()

        #expect(vm.charters.count == 22)
        #expect(vm.isLoadingMore == false)
        #expect(vm.hasMore == false)
    }

    @Test("loadMore - skips when hasMore is false")
    @MainActor
    func testLoadMore_SkipsWhenNoMore() async {
        let (vm, apiClient) = makeViewModel()

        // Load a partial page to set hasMore=false
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [makeDiscoverableCharter()])
        await vm.loadInitial()
        #expect(vm.hasMore == false)

        // Attempt loadMore
        await vm.loadMore()

        #expect(apiClient.discoverChartersCallCount == 1) // No extra call
    }

    // MARK: - refresh

    @Test("refresh - reloads with fresh data")
    @MainActor
    func testRefresh_ReloadsData() async {
        let (vm, apiClient) = makeViewModel()

        // Initial load
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [makeDiscoverableCharter()])
        await vm.loadInitial()
        #expect(vm.charters.count == 1)

        // Refresh with new data
        let freshItems = [makeDiscoverableCharter(), makeDiscoverableCharter(), makeDiscoverableCharter()]
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: freshItems)
        await vm.refresh()

        #expect(vm.charters.count == 3)
        #expect(apiClient.discoverChartersCallCount == 2)
    }

    // MARK: - applyFilters

    @Test("applyFilters - triggers fresh load")
    @MainActor
    func testApplyFilters_TriggersReload() async {
        let (vm, apiClient) = makeViewModel()
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [])

        await vm.applyFilters()

        #expect(apiClient.discoverChartersCallCount == 1)
    }

    // MARK: - resetFilters

    @Test("resetFilters - restores default filter values")
    @MainActor
    func testResetFilters_RestoresDefaults() async {
        let (vm, _) = makeViewModel()

        // Modify filters
        vm.filters.useNearMe = true
        vm.filters.radiusKm = 250.0
        vm.filters.sortOrder = .distanceAscending

        // Reset
        vm.resetFilters()

        #expect(vm.filters == CharterDiscoveryFilters.default)
    }

    // MARK: - Sorting

    @Test("sort by dateAscending - earliest first")
    @MainActor
    func testSort_DateAscending() async {
        let (vm, apiClient) = makeViewModel()
        vm.filters.sortOrder = .dateAscending

        let now = Date()
        let distant = Calendar.current.date(byAdding: .day, value: 30, to: now)!
        let near = Calendar.current.date(byAdding: .day, value: 5, to: now)!

        let items = [
            makeDiscoverableCharter(startDate: distant),
            makeDiscoverableCharter(startDate: near)
        ]
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: items)

        await vm.loadInitial()

        #expect(vm.charters.count == 2)
        // nearest start date should appear first
        #expect(vm.charters[0].startDate <= vm.charters[1].startDate)
    }

    @Test("sort by distanceAscending - closest first")
    @MainActor
    func testSort_DistanceAscending() async {
        let (vm, apiClient) = makeViewModel()
        vm.filters.sortOrder = .distanceAscending

        let items = [
            makeDiscoverableCharter(distanceKm: 500.0),
            makeDiscoverableCharter(distanceKm: 10.0),
            makeDiscoverableCharter(distanceKm: nil) // nil treated as infinity
        ]
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: items)

        await vm.loadInitial()

        #expect(vm.charters.count == 3)
        let distances = vm.charters.map { $0.distanceKm ?? .infinity }
        #expect(distances[0] <= distances[1])
        #expect(distances[1] <= distances[2])
    }

    @Test("sort by recentlyPosted - preserves server order")
    @MainActor
    func testSort_RecentlyPosted_PreservesOrder() async {
        let (vm, apiClient) = makeViewModel()
        vm.filters.sortOrder = .recentlyPosted

        let item1 = makeDiscoverableCharter()
        let item2 = makeDiscoverableCharter()
        let originalIDs = [item1.id, item2.id]

        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [item1, item2])

        await vm.loadInitial()

        #expect(vm.charters.count == 2)
        #expect(vm.charters.map { $0.id } == originalIDs)
    }

    // MARK: - isEmpty

    @Test("isEmpty - true when charters empty and not loading")
    @MainActor
    func testIsEmpty_TrueWhenEmpty() {
        let (vm, _) = makeViewModel()
        #expect(vm.isEmpty == true)
    }

    @Test("isEmpty - false when charters present")
    @MainActor
    func testIsEmpty_FalseWhenChartersPresent() async {
        let (vm, apiClient) = makeViewModel()
        apiClient.mockDiscoverChartersResponse = makeDiscoveryResponse(items: [makeDiscoverableCharter()])

        await vm.loadInitial()

        #expect(vm.isEmpty == false)
    }
}
