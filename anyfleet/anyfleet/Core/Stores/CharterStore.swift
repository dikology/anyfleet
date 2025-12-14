import Foundation
import SwiftUI

@Observable
final class CharterStore {
    // MARK: - Properties
    
    private(set) var charters: [CharterModel] = []
    
    /// Local repository for database operations
    // Sendable conformance required for Observable in Swift 6
    nonisolated private let repository: any CharterRepository
    
    // MARK: - Initialization
    
    nonisolated init(repository: (any CharterRepository)? = nil) {
        self.repository = repository ?? LocalRepository()
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
}