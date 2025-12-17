import Foundation
import SwiftUI

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
@Observable
final class CharterStore {
    // MARK: - Properties
    
    private(set) var charters: [CharterModel] = []
    
    /// Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    nonisolated private let repository: any CharterRepository
    
    // MARK: - Initialization
    
    /// Creates a new CharterStore with the specified repository.
    ///
    /// - Parameter repository: The charter repository to use for data operations
    ///
    /// - Important: The repository must be injected; there is no default implementation
    ///              to ensure proper dependency injection throughout the app.
    nonisolated init(repository: any CharterRepository) {
        self.repository = repository
    }
    
    // MARK: - Charter Operations

    @MainActor
    func createCharter(
        name: String,
        boatName: String?,
        location: String?,
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
            checkInChecklistID: checkInChecklistID
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
    
    @MainActor
    func loadCharters() async {
        AppLogger.store.startOperation("Load Charters")
        do {
            charters = try await repository.fetchAllCharters()
            AppLogger.store.info("Loaded \(charters.count) charters from repository")
            AppLogger.store.completeOperation("Load Charters")
        } catch {
            AppLogger.store.failOperation("Load Charters", error: error)
        }
    }
    
    /// Save/update an existing charter (or append if not already cached)
    @MainActor
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
    
    @MainActor
    func deleteCharter(_ charterID: UUID) async throws {
        AppLogger.store.startOperation("Delete Charter")
        AppLogger.store.info("Deleting charter with ID: \(charterID.uuidString)")
        
        do {
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