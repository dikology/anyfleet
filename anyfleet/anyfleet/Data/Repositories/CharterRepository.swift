//
//  CharterRepository.swift
//  anyfleet
//
//  Protocol for charter repository operations to enable testing
//

import Foundation

/// Protocol for repository operations to enable mocking and testing
protocol CharterRepository: Sendable {
    func fetchAllCharters() async throws -> [CharterModel]
    func fetchActiveCharters() async throws -> [CharterModel]
    func fetchUpcomingCharters() async throws -> [CharterModel]
    func fetchPastCharters() async throws -> [CharterModel]
    func fetchCharter(id: UUID) async throws -> CharterModel?
    func createCharter(_ charter: CharterModel) async throws
    func saveCharter(_ charter: CharterModel) async throws
    func updateCharter(_ charterID: UUID, name: String, boatName: String?, location: String?, startDate: Date, endDate: Date, checkInChecklistID: UUID?) async throws -> CharterModel
    func deleteCharter(_ charterID: UUID) async throws
    func markChartersSynced(_ ids: [UUID]) async throws
}

/// Make LocalRepository conform to the protocol
extension LocalRepository: CharterRepository {}
