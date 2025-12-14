//
//  CharterRecordTests.swift
//  anyfleetTests
//
//  Database tests for CharterRecord using Swift Testing
//

import Foundation
import Testing
import GRDB
@testable import anyfleet

@Suite("CharterRecord Tests")
struct CharterRecordTests {
    
    var database: AppDatabase!
    
    init() async throws {
        database = try AppDatabase.makeEmpty()
    }
    
    @Test("Charter record conversion - domain model to record")
    func testCharterRecordConversion_ToRecord() throws {
        // Arrange
        let charter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: UUID()
        )
        
        // Act
        let record = CharterRecord(from: charter)
        
        // Assert
        #expect(record.id == charter.id.uuidString)
        #expect(record.name == charter.name)
        #expect(record.boatName == charter.boatName)
        #expect(record.location == charter.location)
        #expect(record.startDate == charter.startDate)
        #expect(record.endDate == charter.endDate)
        #expect(record.checkInChecklistID == charter.checkInChecklistID?.uuidString)
        #expect(record.createdAt == charter.createdAt)
        #expect(record.syncStatus == "pending")
    }
    
    @Test("Charter record conversion - record to domain model")
    func testCharterRecordConversion_ToDomainModel() throws {
        // Arrange
        let record = CharterRecord(
            id: UUID().uuidString,
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Date(),
            checkInChecklistID: UUID().uuidString,
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: "pending"
        )
        
        // Act
        let charter = record.toDomainModel()
        
        // Assert
        #expect(charter.id.uuidString == record.id)
        #expect(charter.name == record.name)
        #expect(charter.boatName == record.boatName)
        #expect(charter.location == record.location)
        #expect(charter.startDate == record.startDate)
        #expect(charter.endDate == record.endDate)
        #expect(charter.checkInChecklistID?.uuidString == record.checkInChecklistID)
        #expect(charter.createdAt == record.createdAt)
    }
    
    @Test("Save charter - preserves createdAt on update")
    func testSaveCharter_PreservesMetadata() throws {
        // Arrange
        let originalCreatedAt = Date().addingTimeInterval(-86400) // Yesterday
        let charter = CharterModel(
            id: UUID(),
            name: "Original Name",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: originalCreatedAt,
            checkInChecklistID: nil
        )
        
        // Act - Create initial record
        var savedCreatedAt: Date?
        try database.dbWriter.write { db in
            let record = try CharterRecord.saveCharter(charter, db: db)
            savedCreatedAt = record.createdAt
        }
        
        // Update the charter
        var updated = charter
        updated.name = "Updated Name"
        
        let savedRecord: CharterRecord = try database.dbWriter.write { db in
            try CharterRecord.saveCharter(updated, db: db)
        }
        
        // Assert - Verify createdAt is preserved (within 1 second tolerance for database precision)
        let timeDifference = abs(savedRecord.createdAt.timeIntervalSince(originalCreatedAt))
        #expect(timeDifference < 1.0, "createdAt should be preserved, difference: \(timeDifference) seconds")
        #expect(savedRecord.name == "Updated Name")
        #expect(savedRecord.id == charter.id.uuidString)
        // Also verify it matches what was saved initially
        if let savedCreatedAt = savedCreatedAt {
            let savedDifference = abs(savedRecord.createdAt.timeIntervalSince(savedCreatedAt))
            #expect(savedDifference < 1.0, "createdAt should match initial save, difference: \(savedDifference) seconds")
        }
    }
    
    @Test("Save charter - new record sets createdAt")
    func testSaveCharter_NewRecordSetsCreatedAt() throws {
        // Arrange
        let charter = CharterModel(
            id: UUID(),
            name: "New Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act
        let savedRecord: CharterRecord = try database.dbWriter.write { db in
            try CharterRecord.saveCharter(charter, db: db)
        }
        
        // Assert
        #expect(savedRecord.createdAt == charter.createdAt)
        #expect(savedRecord.name == charter.name)
    }
    
    @Test("Fetch active charters - date range logic")
    func testFetchActiveCharters() throws {
        // Arrange
        let now = Date()
        let activeStart = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let activeEnd = Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now
        
        let activeCharter = CharterModel(
            id: UUID(),
            name: "Active",
            boatName: nil,
            location: nil,
            startDate: activeStart,
            endDate: activeEnd,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        let upcomingCharter = CharterModel(
            id: UUID(),
            name: "Upcoming",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: 17, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        // Act
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(activeCharter, db: db)
            _ = try CharterRecord.saveCharter(upcomingCharter, db: db)
        }
        
        let active: [CharterRecord] = try database.dbWriter.read { db in
            try CharterRecord.fetchActive(db: db)
        }
        
        // Assert
        #expect(active.count == 1)
        #expect(active.first?.id == activeCharter.id.uuidString)
        #expect(active.first?.name == "Active")
    }
    
    @Test("Fetch upcoming charters - date logic")
    func testFetchUpcomingCharters() throws {
        // Arrange
        let now = Date()
        let upcomingCharter = CharterModel(
            id: UUID(),
            name: "Upcoming",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: 10, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: 17, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        // Act
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(upcomingCharter, db: db)
        }
        
        let upcoming: [CharterRecord] = try database.dbWriter.read { db in
            try CharterRecord.fetchUpcoming(db: db)
        }
        
        // Assert
        #expect(upcoming.count >= 1)
        #expect(upcoming.contains { $0.id == upcomingCharter.id.uuidString })
    }
    
    @Test("Fetch past charters - date logic")
    func testFetchPastCharters() throws {
        // Arrange
        let now = Date()
        let pastCharter = CharterModel(
            id: UUID(),
            name: "Past",
            boatName: nil,
            location: nil,
            startDate: Calendar.current.date(byAdding: .day, value: -20, to: now) ?? now,
            endDate: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now,
            createdAt: now,
            checkInChecklistID: nil
        )
        
        // Act
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(pastCharter, db: db)
        }
        
        let past: [CharterRecord] = try database.dbWriter.read { db in
            try CharterRecord.fetchPast(db: db)
        }
        
        // Assert
        #expect(past.count >= 1)
        #expect(past.contains { $0.id == pastCharter.id.uuidString })
    }
    
    @Test("Save charter - sync status handling")
    func testSaveCharter_SyncStatusHandling() throws {
        // Arrange
        let charter = CharterModel(
            id: UUID(),
            name: "Sync Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        // Act - Create and mark as synced
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(charter, db: db)
            try CharterRecord.markSynced(charter.id, db: db)
        }
        
        // Update the charter
        var updated = charter
        updated.name = "Updated"
        
        let savedRecord: CharterRecord = try database.dbWriter.write { db in
            try CharterRecord.saveCharter(updated, db: db)
        }
        
        // Assert - Should be marked as pending_update since it was synced
        #expect(savedRecord.syncStatus == "pending_update")
        #expect(savedRecord.name == "Updated")
    }
    
    @Test("From domain model - preserves existing metadata")
    func testFromDomainModel_PreservesMetadata() {
        // Arrange
        let originalCreatedAt = Date().addingTimeInterval(-86400)
        let existingRecord = CharterRecord(
            id: UUID().uuidString,
            name: "Original",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            checkInChecklistID: nil,
            createdAt: originalCreatedAt,
            updatedAt: Date(),
            syncStatus: "synced"
        )
        
        let updatedCharter = CharterModel(
            id: UUID(uuidString: existingRecord.id) ?? UUID(),
            name: "Updated",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(), // New date, but should be preserved from existing
            checkInChecklistID: nil
        )
        
        // Act
        let result = CharterRecord.fromDomainModel(updatedCharter, existingRecord: existingRecord)
        
        // Assert
        #expect(result.createdAt == originalCreatedAt)
        #expect(result.name == "Updated")
        #expect(result.syncStatus == "pending_update") // synced -> pending_update
    }
}
