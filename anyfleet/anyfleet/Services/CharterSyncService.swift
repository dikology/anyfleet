import Foundation

/// Synchronises local charters with the backend.
///
/// Responsibilities:
/// - Push newly created or modified local charters to the server (when visibility != private)
/// - Pull the user's remote charters on launch / foreground
/// - Handle conflict resolution (last-write-wins via server timestamp)
///
/// This service follows the same structural patterns as `ContentSyncService`.
@MainActor
@Observable
final class CharterSyncService {

    // MARK: - Properties

    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var lastSyncError: Error?

    private let repository: any CharterRepository
    private let apiClient: APIClientProtocol
    private let charterStore: CharterStore

    // MARK: - Initialization

    init(
        repository: any CharterRepository,
        apiClient: APIClientProtocol,
        charterStore: CharterStore
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.charterStore = charterStore
    }

    // MARK: - Public API

    /// Push all local charters with `needsSync == true` to the backend.
    /// Only charters with visibility != private are pushed.
    func pushPendingCharters() async {
        guard !isSyncing else { return }

        do {
            let pending = try await repository.fetchPendingSyncCharters()
            let toSync = pending.filter { $0.visibility != .private }
            guard !toSync.isEmpty else { return }

            AppLogger.sync.info("Pushing \(toSync.count) pending charter(s) to server")
            isSyncing = true
            defer { isSyncing = false }

            for charter in toSync {
                await push(charter)
            }
            lastSyncDate = Date()
        } catch {
            AppLogger.sync.error("Failed to fetch pending charters", error: error)
            lastSyncError = error
        }
    }

    /// Pull the current user's charters from the backend and merge into local store.
    func pullMyCharters() async {
        AppLogger.sync.info("Pulling user charters from server")
        do {
            let response = try await apiClient.fetchMyCharters()
            for remoteCharter in response.items {
                let localModel = remoteCharter.toCharterModel()
                // Upsert into local DB
                try await repository.saveCharter(localModel)
            }

            // Reload the charter store so UI reflects the latest state
            try await charterStore.loadCharters()
            lastSyncDate = Date()
            AppLogger.sync.info("Pulled \(response.items.count) charter(s) from server")
        } catch {
            AppLogger.sync.error("Failed to pull charters from server", error: error)
            lastSyncError = error
        }
    }

    /// Full sync: push pending then pull latest.
    func syncAll() async {
        await pushPendingCharters()
        await pullMyCharters()
    }

    // MARK: - Private Helpers

    private func push(_ charter: CharterModel) async {
        do {
            if let serverID = charter.serverID {
                // Update existing server record
                let request = CharterUpdateRequest(
                    name: charter.name,
                    boatName: charter.boatName,
                    locationText: charter.location,
                    startDate: charter.startDate,
                    endDate: charter.endDate,
                    visibility: charter.visibility.rawValue,
                    latitude: charter.latitude,
                    longitude: charter.longitude,
                    locationPlaceId: charter.locationPlaceID
                )
                let response = try await apiClient.updateCharter(id: serverID, request: request)
                try await repository.markCharterSynced(charter.id, serverID: response.id)
                AppLogger.sync.info("Updated charter on server: \(charter.id.uuidString)")
            } else {
                // Create new server record
                let request = CharterCreateRequest(
                    name: charter.name,
                    boatName: charter.boatName,
                    locationText: charter.location,
                    startDate: charter.startDate,
                    endDate: charter.endDate,
                    visibility: charter.visibility.rawValue,
                    latitude: charter.latitude,
                    longitude: charter.longitude,
                    locationPlaceId: charter.locationPlaceID
                )
                let response = try await apiClient.createCharter(request)
                try await repository.markCharterSynced(charter.id, serverID: response.id)
                AppLogger.sync.info("Created charter on server: \(charter.id.uuidString) → \(response.id.uuidString)")
            }
        } catch {
            AppLogger.sync.error("Failed to push charter \(charter.id.uuidString)", error: error)
            lastSyncError = error
        }
    }
}

// MARK: - Logger Extension

extension AppLogger {
    static let charterSync = AppLogger.sync
}
