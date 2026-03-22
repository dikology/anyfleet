import Foundation
import SwiftUI

/// Removes a charter from discovery on the server when the local copy is deleted.
///
/// Implemented by `CharterStore`'s sync layer. The store holds this reference **weakly**
/// so `CharterSyncService` → `CharterStore` does not create a retain cycle.
@MainActor
protocol CharterDiscoveryUnpublishing: AnyObject {
    func unpublishCharter(serverID: UUID) async throws
}

/// Store managing charter state and operations across the application.
///
/// `CharterStore` serves as the single source of truth for charter data in the app.
/// It maintains an in-memory cache synchronized with the local database through
/// the repository layer.
///
/// This class uses Swift's modern `@Observable` macro for state observation,
/// providing automatic change tracking without the need for `@Published` properties.
///
/// ## Usage
///
/// Access the shared instance through the environment:
///
/// ```swift
/// struct MyView: View {
///     @Environment(\.appDependencies) private var dependencies
///
///     var body: some View {
///         List(dependencies.charterStore.charters) { charter in
///             Text(charter.name)
///         }
///     }
/// }
/// ```
///
/// - Important: This class must be accessed from the main actor.
/// - Note: All operations are automatically logged using `AppLogger`.
@MainActor
@Observable
final class CharterStore {
    // MARK: - Properties
    
    private(set) var charters: [CharterModel] = []
    
    /// Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    private let repository: any CharterRepository

    /// Optional hook used before deleting a non-private synced charter so discovery stays consistent.
    private weak var discoveryUnpublisher: (any CharterDiscoveryUnpublishing)?
    
    // MARK: - Initialization
    
    /// Creates a new CharterStore with the specified repository.
    ///
    /// - Parameter repository: The charter repository to use for data operations
    ///
    /// - Important: The repository must be injected; there is no default implementation
    ///              to ensure proper dependency injection throughout the app.
    init(repository: any CharterRepository) {
        self.repository = repository
    }

    /// Wire the sync service (or a test double) after both objects exist. Uses a weak reference.
    func setDiscoveryUnpublisher(_ unpublisher: (any CharterDiscoveryUnpublishing)?) {
        discoveryUnpublisher = unpublisher
    }
    
    // MARK: - Charter Operations

    func createCharter(
        name: String,
        boatName: String?,
        location: String?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationPlaceID: String? = nil,
        startDate: Date,
        endDate: Date,
        checkInChecklistID: UUID? = nil
    ) async throws -> CharterModel {
        AppLogger.store.startOperation("Create Charter")
        AppLogger.store.debug("Creating charter - name: '\(name)', boatName: \(boatName ?? "nil"), location: \(location ?? "nil")")
        
        let charter = CharterModel(
            id: UUID(),
            name: name,
            boatName: boatName,
            location: location,
            startDate: startDate,
            endDate: endDate,
            createdAt: Date(),
            checkInChecklistID: checkInChecklistID,
            latitude: latitude,
            longitude: longitude,
            locationPlaceID: locationPlaceID
        )
        
        AppLogger.store.debug("CharterModel created with ID: \(charter.id.uuidString)")
        
        do {
        try await repository.createCharter(charter)
            AppLogger.store.debug("Charter saved to repository successfully")
            
            charters.append(charter)
            AppLogger.store.info("Charter added to store, total charters: \(charters.count)")
            AppLogger.store.completeOperation("Create Charter")
            
        return charter
        } catch {
            AppLogger.store.failOperation("Create Charter", error: error)
            throw error
        }
    }

    func loadCharters() async throws {
        AppLogger.store.startOperation("Load Charters")
        do {
            charters = try await repository.fetchAllCharters()
            AppLogger.store.info("Loaded \(charters.count) charters from repository")
            AppLogger.store.completeOperation("Load Charters")
        } catch {
            AppLogger.store.failOperation("Load Charters", error: error)
            throw error
        }
    }

    func fetchCharter(_ charterID: UUID) async throws -> CharterModel {
        AppLogger.store.startOperation("Fetch Charter")
        AppLogger.store.info("Fetching charter with ID: \(charterID.uuidString)")
        
        do {
            guard let charter = try await repository.fetchCharter(id: charterID) else {
                throw AppError.notFound(entity: "Charter", id: charterID)
            }
            
            AppLogger.store.info("Charter fetched successfully with ID: \(charter.id.uuidString)")
            AppLogger.store.completeOperation("Fetch Charter")
            
            return charter
        } catch {
            AppLogger.store.failOperation("Fetch Charter", error: error)
            throw error
        }
    }
    
    /// Save/update an existing charter (or append if not already cached)
    func saveCharter(_ charter: CharterModel) async throws {
        AppLogger.store.startOperation("Save Charter")
        AppLogger.store.info("Saving charter with ID: \(charter.id.uuidString)")
        
        do {
            try await repository.saveCharter(charter)
            
            if let index = charters.firstIndex(where: { $0.id == charter.id }) {
                charters[index] = charter
            } else {
                charters.append(charter)
            }
            
            AppLogger.store.info("Charter saved successfully, total charters: \(charters.count)")
            AppLogger.store.completeOperation("Save Charter")
        } catch {
            AppLogger.store.failOperation("Save Charter", error: error)
            throw error
        }
    }

    func updateCharter(_ charterID: UUID, name: String, boatName: String?, location: String?, latitude: Double? = nil, longitude: Double? = nil, locationPlaceID: String? = nil, startDate: Date, endDate: Date, checkInChecklistID: UUID?, onBehalfOfVirtualCaptainID: UUID? = nil) async throws -> CharterModel {
        AppLogger.store.startOperation("Update Charter")
        AppLogger.store.info("Updating charter with ID: \(charterID.uuidString)")
        
        do {
            let charter = try await repository.updateCharter(charterID, name: name, boatName: boatName, location: location, latitude: latitude, longitude: longitude, locationPlaceID: locationPlaceID, startDate: startDate, endDate: endDate, checkInChecklistID: checkInChecklistID, onBehalfOfVirtualCaptainID: onBehalfOfVirtualCaptainID)
            if let index = charters.firstIndex(where: { $0.id == charterID }) {
                charters[index] = charter
            }
            AppLogger.store.info("Charter updated successfully with ID: \(charter.id.uuidString)")
            AppLogger.store.completeOperation("Update Charter")
            return charter
        } catch {
            AppLogger.store.failOperation("Update Charter", error: error)
            throw error
        }
    }

    /// Update the visibility of a charter and flag it for sync.
    func updateVisibility(_ charterID: UUID, visibility: CharterVisibility) async throws {
        AppLogger.store.startOperation("Update Charter Visibility")
        do {
            try await repository.updateCharterVisibility(charterID, visibility: visibility)
            if let index = charters.firstIndex(where: { $0.id == charterID }) {
                charters[index].visibility = visibility
                charters[index].needsSync = true
            }
            AppLogger.store.completeOperation("Update Charter Visibility")
        } catch {
            AppLogger.store.failOperation("Update Charter Visibility", error: error)
            throw error
        }
    }

    /// Deletes a charter locally. When `unpublishFromDiscoveryIfNeeded` is `true`, also asks the
    /// server to remove the charter from discovery if it was synced with a `serverID` and non-private visibility.
    ///
    /// Unpublish failures are logged and ignored so local deletion still completes. Pass
    /// `unpublishFromDiscoveryIfNeeded: false` when the user explicitly chooses to drop only the local copy
    /// while leaving the server record (see `CharterDeleteModal`).
    func deleteCharter(_ charterID: UUID, unpublishFromDiscoveryIfNeeded: Bool = true) async throws {
        AppLogger.store.startOperation("Delete Charter")
        AppLogger.store.info("Deleting charter with ID: \(charterID.uuidString)")
        
        do {
            if unpublishFromDiscoveryIfNeeded {
                let charter = if let cached = charters.first(where: { $0.id == charterID }) {
                    cached
                } else {
                    try? await repository.fetchCharter(id: charterID)
                }
                if let charter, let serverID = charter.serverID, charter.visibility != .private,
                   let unpublisher = discoveryUnpublisher {
                    do {
                        try await unpublisher.unpublishCharter(serverID: serverID)
                    } catch {
                        AppLogger.store.warning(
                            "Unpublish before delete failed; continuing with local delete: \(error.localizedDescription)"
                        )
                    }
                }
            }

            try await repository.deleteCharter(charterID)
            
            // Remove from local array
            charters.removeAll { $0.id == charterID }
            
            AppLogger.store.info("Charter deleted successfully, remaining charters: \(charters.count)")
            AppLogger.store.completeOperation("Delete Charter")
        } catch {
            AppLogger.store.failOperation("Delete Charter", error: error)
            throw error
        }
    }
}