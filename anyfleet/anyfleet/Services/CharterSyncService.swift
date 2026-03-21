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
    /// True when there are charters pending sync but the user is not authenticated.
    /// Observe this in the UI to prompt the user to sign in.
    private(set) var needsAuthForSync = false

    private let repository: any CharterRepository
    private let apiClient: APIClientProtocol
    private let charterStore: CharterStore
    private let authService: AuthServiceProtocol

    // MARK: - Initialization

    init(
        repository: any CharterRepository,
        apiClient: APIClientProtocol,
        charterStore: CharterStore,
        authService: AuthServiceProtocol
    ) {
        self.repository = repository
        self.apiClient = apiClient
        self.charterStore = charterStore
        self.authService = authService
    }

    // MARK: - Public API

    /// Push all local charters with `needsSync == true` to the backend.
    /// Only charters with visibility != private are pushed.
    /// Skips silently when the user is not authenticated and sets `needsAuthForSync`.
    func pushPendingCharters() async {
        guard !isSyncing else { return }

        guard authService.isAuthenticated else {
            do {
                let pending = try await repository.fetchPendingSyncCharters()
                let blocked = pending.filter { $0.visibility != .private }
                if !blocked.isEmpty {
                    needsAuthForSync = true
                    AppLogger.sync.warning(
                        "Charter sync blocked: \(blocked.count) charter(s) pending sync, user not authenticated"
                    )
                }
            } catch {
                AppLogger.sync.error("Failed to check pending charters for auth guard", error: error)
            }
            return
        }

        needsAuthForSync = false

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
    ///
    /// Uses last-write-wins conflict resolution: a remote record only overwrites the local
    /// copy when `remote.updatedAt > local.updatedAt` AND the local record has no pending
    /// changes (`!local.needsSync`). This preserves offline edits that are waiting to be
    /// pushed, preventing a stale pull from silently discarding the user's unsaved work.
    func pullMyCharters() async {
        AppLogger.sync.info("Pulling user charters from server")
        do {
            let response = try await apiClient.fetchMyCharters()
            var saved = 0
            var skipped = 0

            for remoteCharter in response.items {
                let remote = remoteCharter.toCharterModel()

                if let local = try? await repository.fetchCharter(id: remote.id) {
                    // Only overwrite if the remote version is genuinely newer AND the local
                    // record has no unsent changes. A local record with needsSync = true is
                    // the source of truth until its push has been acknowledged.
                    if remote.updatedAt > local.updatedAt && !local.needsSync {
                        try await repository.saveCharter(remote)
                        saved += 1
                    } else {
                        skipped += 1
                    }
                } else {
                    // New charter from the server — always save.
                    try await repository.saveCharter(remote)
                    saved += 1
                }
            }

            // Reload the charter store so UI reflects the latest state
            try await charterStore.loadCharters()
            lastSyncDate = Date()
            AppLogger.sync.info(
                "Pulled \(response.items.count) charter(s): \(saved) saved, \(skipped) skipped (local newer or pending sync)"
            )
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

    /// Remove a charter from the discovery feed by calling the backend delete endpoint.
    ///
    /// Called fire-and-forget when the user deletes a charter that was previously synced
    /// as non-private. Local deletion always proceeds regardless of whether this call succeeds.
    func unpublishCharter(serverID: UUID) async throws {
        guard authService.isAuthenticated else { return }
        try await apiClient.deleteCharter(id: serverID)
        AppLogger.sync.info("Charter \(serverID.uuidString) unpublished from discovery")
    }

    // MARK: - Private Helpers

    private func push(_ charter: CharterModel) async {
        do {
            if let serverID = charter.serverID {
                // Update existing server record
                let shouldEncodeOnBehalf = charter.visibility != .private
                let request = CharterUpdateRequest(
                    name: charter.name,
                    boatName: charter.boatName,
                    locationText: charter.location,
                    startDate: charter.startDate,
                    endDate: charter.endDate,
                    visibility: charter.visibility.rawValue,
                    latitude: charter.latitude,
                    longitude: charter.longitude,
                    locationPlaceId: charter.locationPlaceID,
                    onBehalfOfVirtualCaptainId: charter.onBehalfOfVirtualCaptainID,
                    shouldEncodeOnBehalfOfVirtualCaptainId: shouldEncodeOnBehalf
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
                    locationPlaceId: charter.locationPlaceID,
                    onBehalfOfVirtualCaptainId: charter.visibility != .private ? charter.onBehalfOfVirtualCaptainID : nil
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
