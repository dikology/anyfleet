import Foundation
import CoreLocation

@MainActor
@Observable
final class CharterDiscoveryViewModel: ErrorHandling {

    // MARK: - State

    private(set) var charters: [DiscoverableCharter] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = true
    var filters = CharterDiscoveryFilters()
    var showFilters = false
    var showMapView = false
    var selectedCharter: DiscoverableCharter?

    var currentError: AppError?
    var showErrorBanner = false

    var isEmpty: Bool { charters.isEmpty && !isLoading }

    // MARK: - Pagination

    private let pageSize = 20
    private var currentOffset = 0

    // MARK: - Location

    private var userLocation: CLLocationCoordinate2D?

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let locationManager: CLLocationManager

    // MARK: - Initialization

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
        self.locationManager = CLLocationManager()
    }

    // MARK: - Actions

    func loadInitial() async {
        guard !isLoading else { return }
        currentOffset = 0
        hasMore = true
        charters = []
        await load()
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await load(appending: true)
    }

    func refresh() async {
        await loadInitial()
    }

    func applyFilters() async {
        await loadInitial()
    }

    func resetFilters() {
        filters = .default
        Task { await loadInitial() }
    }

    func requestLocationIfNeeded() {
        if filters.useNearMe {
            locationManager.requestWhenInUseAuthorization()
            if let location = locationManager.location {
                userLocation = location.coordinate
            }
        }
    }

    // MARK: - Private

    private func load(appending: Bool = false) async {
        if !appending {
            isLoading = true
            defer { isLoading = false }
        }

        do {
            let lat = filters.useNearMe ? userLocation?.latitude : nil
            let lon = filters.useNearMe ? userLocation?.longitude : nil
            // Backend caps radius_km at 10 000; use max for global (no location) search.
            let radius = filters.useNearMe ? filters.radiusKm : 10_000.0

            let response = try await apiClient.discoverCharters(
                dateFrom: filters.effectiveDateFrom,
                dateTo: filters.effectiveDateTo,
                nearLat: lat,
                nearLon: lon,
                radiusKm: radius,
                limit: pageSize,
                offset: currentOffset
            )

            let newItems = response.items.map { $0.toDiscoverableCharter() }
            let sorted = sort(newItems)

            if appending {
                charters.append(contentsOf: sorted)
            } else {
                charters = sorted
            }

            currentOffset += newItems.count
            hasMore = newItems.count == pageSize

            AppLogger.view.info("Loaded \(newItems.count) discoverable charters (total: \(charters.count))")
        } catch {
            handleError(error)
        }
    }

    private func sort(_ items: [DiscoverableCharter]) -> [DiscoverableCharter] {
        switch filters.sortOrder {
        case .dateAscending:
            return items.sorted { $0.startDate < $1.startDate }
        case .distanceAscending:
            return items.sorted { ($0.distanceKm ?? .infinity) < ($1.distanceKm ?? .infinity) }
        case .recentlyPosted:
            return items
        }
    }
}
