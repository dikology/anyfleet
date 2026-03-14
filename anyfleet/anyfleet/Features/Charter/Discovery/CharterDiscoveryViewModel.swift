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

    // MARK: - Cache

    private var cache: [String: DiscoveryCacheEntry] = [:]

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
        cache.removeValue(forKey: cacheKey)
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

    private var cacheKey: String {
        "\(filters.datePreset.rawValue)|\(filters.useNearMe)|\(Int(filters.radiusKm))|\(filters.sortOrder.rawValue)"
    }

    private func load(appending: Bool = false) async {
        if !appending, let cached = cache[cacheKey], !cached.isStale {
            charters = cached.charters
            // currentOffset tracks where loadMore should continue from.
            // The background stale-refresh always restarts from offset 0 (see fetchAndCache),
            // so it is safe to set this here for an immediate loadMore call.
            currentOffset = cached.charters.count
            hasMore = cached.charters.count == pageSize
            Task { await fetchAndCache(appending: false, silent: true) }
            return
        }
        await fetchAndCache(appending: appending, silent: false)
    }

    private func fetchAndCache(appending: Bool, silent: Bool) async {
        if !silent && !appending {
            isLoading = true
            defer { isLoading = false }
        }

        do {
            let lat = filters.useNearMe ? userLocation?.latitude : nil
            let lon = filters.useNearMe ? userLocation?.longitude : nil
            // Backend caps radius_km at 10 000; use max for global (no location) search.
            let radius = filters.useNearMe ? filters.radiusKm : 10_000.0

            // Fresh (non-appending) loads always start from offset 0.
            // Using currentOffset here was the source of a bug: a cache-hit sets
            // currentOffset = cached.count before firing the background refresh, which
            // then fetched only the delta and *replaced* the full list with it.
            let fetchOffset = appending ? currentOffset : 0

            let response = try await apiClient.discoverCharters(
                dateFrom: filters.effectiveDateFrom,
                dateTo: filters.effectiveDateTo,
                nearLat: lat,
                nearLon: lon,
                radiusKm: radius,
                sortBy: filters.sortOrder.backendValue,
                limit: pageSize,
                offset: fetchOffset
            )

            let newItems = response.items.map { $0.toDiscoverableCharter() }

            if appending {
                charters.append(contentsOf: newItems)
                currentOffset += newItems.count
            } else {
                charters = newItems
                currentOffset = newItems.count
                cache[cacheKey] = DiscoveryCacheEntry(charters: newItems, fetchedAt: Date(), cacheKey: cacheKey)
            }

            hasMore = newItems.count == pageSize

            AppLogger.view.info("Loaded \(newItems.count) discoverable charters (total: \(charters.count))")
        } catch {
            if !silent { handleError(error) }
        }
    }
}

// MARK: - Discovery Cache

struct DiscoveryCacheEntry {
    let charters: [DiscoverableCharter]
    let fetchedAt: Date
    let cacheKey: String

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 120
    }
}

// MARK: - SortOrder backend mapping

private extension CharterDiscoveryFilters.SortOrder {
    var backendValue: String {
        switch self {
        case .dateAscending: return "date_asc"
        case .distanceAscending: return "distance_asc"
        case .recentlyPosted: return "date_desc"
        }
    }
}
