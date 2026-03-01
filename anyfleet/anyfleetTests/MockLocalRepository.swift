//
//  MockLocalRepository.swift
//  anyfleetTests
//
//  Mock repository for unit testing CharterStore and CharterSyncService
//

import Foundation
@testable import anyfleet

/// Mock repository that allows controlling test behavior
final class MockLocalRepository: CharterRepository, @unchecked Sendable {
    var fetchAllChartersResult: Result<[CharterModel], Error> = .success([])
    var fetchActiveChartersResult: Result<[CharterModel], Error> = .success([])
    var fetchUpcomingChartersResult: Result<[CharterModel], Error> = .success([])
    var fetchPastChartersResult: Result<[CharterModel], Error> = .success([])
    var fetchCharterResult: Result<CharterModel?, Error> = .success(nil)
    var createCharterResult: Result<Void, Error> = .success(())
    var saveCharterResult: Result<Void, Error> = .success(())
    var updateCharterResult: Result<CharterModel, Error> = .success(CharterModel(id: UUID(), name: "", boatName: nil, location: nil, startDate: Date(), endDate: Date(), createdAt: Date(), checkInChecklistID: nil))
    var deleteCharterResult: Result<Void, Error> = .success(())
    var markChartersSyncedResult: Result<Void, Error> = .success(())

    // MARK: Sync Support Results
    var fetchPendingSyncChartersResult: Result<[CharterModel], Error> = .success([])
    var markCharterSyncedResult: Result<Void, Error> = .success(())
    var updateCharterVisibilityResult: Result<Void, Error> = .success(())
    var updateCharterServerIDResult: Result<Void, Error> = .success(())

    // MARK: Call Counters
    var createCharterCallCount = 0
    var saveCharterCallCount = 0
    var deleteCharterCallCount = 0
    var fetchAllChartersCallCount = 0
    var fetchPendingSyncChartersCallCount = 0
    var markCharterSyncedCallCount = 0
    var updateCharterVisibilityCallCount = 0
    var updateCharterServerIDCallCount = 0

    // MARK: Last Call Arguments
    var lastCreatedCharter: CharterModel?
    var lastMarkedSyncedID: UUID?
    var lastMarkedSyncedServerID: UUID?
    var lastUpdatedVisibilityID: UUID?
    var lastUpdatedVisibility: CharterVisibility?
    
    func fetchAllCharters() async throws -> [CharterModel] {
        fetchAllChartersCallCount += 1
        return try fetchAllChartersResult.get()
    }
    
    func fetchActiveCharters() async throws -> [CharterModel] {
        return try fetchActiveChartersResult.get()
    }
    
    func fetchUpcomingCharters() async throws -> [CharterModel] {
        return try fetchUpcomingChartersResult.get()
    }
    
    func fetchPastCharters() async throws -> [CharterModel] {
        return try fetchPastChartersResult.get()
    }
    
    func fetchCharter(id: UUID) async throws -> CharterModel? {
        return try fetchCharterResult.get()
    }
    
    func createCharter(_ charter: CharterModel) async throws {
        createCharterCallCount += 1
        lastCreatedCharter = charter
        try createCharterResult.get()
    }
    
    func saveCharter(_ charter: CharterModel) async throws {
        saveCharterCallCount += 1
        try saveCharterResult.get()
    }
    
    func deleteCharter(_ charterID: UUID) async throws {
        deleteCharterCallCount += 1
        try deleteCharterResult.get()
    }
    
    func markChartersSynced(_ ids: [UUID]) async throws {
        try markChartersSyncedResult.get()
    }

    func updateCharter(_ charterID: UUID, name: String, boatName: String?, location: String?, latitude: Double?, longitude: Double?, locationPlaceID: String?, startDate: Date, endDate: Date, checkInChecklistID: UUID?) async throws -> CharterModel {
        return try updateCharterResult.get()
    }

    // MARK: Sync Support

    func fetchPendingSyncCharters() async throws -> [CharterModel] {
        fetchPendingSyncChartersCallCount += 1
        return try fetchPendingSyncChartersResult.get()
    }

    func markCharterSynced(_ id: UUID, serverID: UUID) async throws {
        markCharterSyncedCallCount += 1
        lastMarkedSyncedID = id
        lastMarkedSyncedServerID = serverID
        try markCharterSyncedResult.get()
    }

    func updateCharterVisibility(_ id: UUID, visibility: CharterVisibility) async throws {
        updateCharterVisibilityCallCount += 1
        lastUpdatedVisibilityID = id
        lastUpdatedVisibility = visibility
        try updateCharterVisibilityResult.get()
    }

    func updateCharterServerID(_ id: UUID, serverID: UUID) async throws {
        updateCharterServerIDCallCount += 1
        try updateCharterServerIDResult.get()
    }
}
