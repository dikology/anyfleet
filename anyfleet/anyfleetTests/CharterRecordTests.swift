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
        let serverID = UUID()
        let syncDate = Date().addingTimeInterval(-60)
        let charter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: UUID(),
            serverID: serverID,
            visibility: .community,
            needsSync: true,
            lastSyncedAt: syncDate,
            latitude: 43.5,
            longitude: 16.4,
            locationPlaceID: "place_xyz"
        )
        
        // Act
        let record = CharterRecord(from: charter)
        
        // Assert - core fields
        #expect(record.id == charter.id.uuidString)
        #expect(record.name == charter.name)
        #expect(record.boatName == charter.boatName)
        #expect(record.location == charter.location)
        #expect(record.startDate == charter.startDate)
        #expect(record.endDate == charter.endDate)
        #expect(record.checkInChecklistID == charter.checkInChecklistID?.uuidString)
        #expect(record.createdAt == charter.createdAt)
        #expect(record.syncStatus == "pending")
        // Assert - new sync fields
        #expect(record.serverID == serverID.uuidString)
        #expect(record.visibility == "community")
        #expect(record.needsSync == true)
        #expect(record.lastSyncedAt == syncDate)
        // Assert - new geo fields
        #expect(record.latitude == 43.5)
        #expect(record.longitude == 16.4)
        #expect(record.locationPlaceID == "place_xyz")
    }
    
    @Test("Charter record conversion - record to domain model")
    func testCharterRecordConversion_ToDomainModel() throws {
        // Arrange
        let serverUUID = UUID()
        let syncDate = Date().addingTimeInterval(-120)
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
            syncStatus: "pending",
            serverID: serverUUID.uuidString,
            visibility: "public",
            needsSync: true,
            lastSyncedAt: syncDate,
            latitude: 39.5,
            longitude: 2.65,
            locationPlaceID: "place_mallorca"
        )
        
        // Act
        let charter = record.toDomainModel()
        
        // Assert - core fields
        #expect(charter.id.uuidString == record.id)
        #expect(charter.name == record.name)
        #expect(charter.boatName == record.boatName)
        #expect(charter.location == record.location)
        #expect(charter.startDate == record.startDate)
        #expect(charter.endDate == record.endDate)
        #expect(charter.checkInChecklistID?.uuidString == record.checkInChecklistID)
        #expect(charter.createdAt == record.createdAt)
        // Assert - new sync fields
        #expect(charter.serverID == serverUUID)
        #expect(charter.visibility == .public)
        #expect(charter.needsSync == true)
        #expect(charter.lastSyncedAt == syncDate)
        // Assert - new geo fields
        #expect(charter.latitude == 39.5)
        #expect(charter.longitude == 2.65)
        #expect(charter.locationPlaceID == "place_mallorca")
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
        let serverID = UUID()
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
        
        // Act - Create and mark as synced (now requires serverID)
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(charter, db: db)
            try CharterRecord.markSynced(charter.id, serverID: serverID, db: db)
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
    
    // MARK: - Sync & Geo Field Tests

    @Test("markSynced - updates serverID, syncStatus, needsSync, lastSyncedAt")
    func testMarkSynced_UpdatesAllFields() throws {
        // Arrange
        let charterID = UUID()
        let serverID = UUID()
        let charter = CharterModel(
            id: charterID,
            name: "Sync Fields Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )

        // Save the charter first
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(charter, db: db)
        }

        // Act - Mark as synced with a server ID
        try database.dbWriter.write { db in
            try CharterRecord.markSynced(charterID, serverID: serverID, db: db)
        }

        // Assert
        let fetched: CharterRecord? = try database.dbWriter.read { db in
            try CharterRecord.filter(CharterRecord.Columns.id == charterID.uuidString).fetchOne(db)
        }
        #expect(fetched != nil)
        #expect(fetched?.syncStatus == "synced")
        #expect(fetched?.serverID == serverID.uuidString)
        #expect(fetched?.needsSync == false)
        #expect(fetched?.lastSyncedAt != nil)
    }

    @Test("Charter record - stores and retrieves geo fields")
    func testCharterRecord_GeoFields() throws {
        // Arrange
        let charter = CharterModel(
            id: UUID(),
            name: "Geo Test Charter",
            boatName: nil,
            location: "Mallorca, Spain",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            createdAt: Date(),
            checkInChecklistID: nil,
            latitude: 39.5696,
            longitude: 2.6502,
            locationPlaceID: "ChIJabcdef123456"
        )

        // Act
        let saved: CharterRecord = try database.dbWriter.write { db in
            try CharterRecord.saveCharter(charter, db: db)
        }
        let fetched: CharterRecord? = try database.dbWriter.read { db in
            try CharterRecord.filter(CharterRecord.Columns.id == charter.id.uuidString).fetchOne(db)
        }

        // Assert
        #expect(saved.latitude == 39.5696)
        #expect(saved.longitude == 2.6502)
        #expect(saved.locationPlaceID == "ChIJabcdef123456")
        #expect(fetched?.latitude == 39.5696)
        #expect(fetched?.longitude == 2.6502)
        #expect(fetched?.locationPlaceID == "ChIJabcdef123456")
    }

    @Test("Charter record - visibility defaults to private")
    func testCharterRecord_DefaultVisibility() throws {
        let charter = CharterModel(
            id: UUID(),
            name: "Visibility Default Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )

        let record = CharterRecord(from: charter)
        #expect(record.visibility == "private")
        #expect(record.needsSync == false)
        #expect(record.serverID == nil)
        #expect(record.lastSyncedAt == nil)
    }

    @Test("Charter record - community visibility is persisted correctly")
    func testCharterRecord_CommunityVisibility() throws {
        var charter = CharterModel(
            id: UUID(),
            name: "Community Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        charter.visibility = .community
        charter.needsSync = true

        let fetched: CharterRecord? = try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(charter, db: db)
            return try CharterRecord.filter(CharterRecord.Columns.id == charter.id.uuidString).fetchOne(db)
        }

        #expect(fetched?.visibility == "community")
        #expect(fetched?.needsSync == true)
    }

    @Test("fetchPendingSync - returns only charters with needsSync true")
    func testFetchPendingSync() throws {
        // Arrange
        var syncNeeded = CharterModel(
            id: UUID(), name: "Needs Sync", boatName: nil, location: nil,
            startDate: Date(), endDate: Date().addingTimeInterval(86400),
            createdAt: Date(), checkInChecklistID: nil
        )
        syncNeeded.needsSync = true
        syncNeeded.visibility = .community

        let noSyncNeeded = CharterModel(
            id: UUID(), name: "Up To Date", boatName: nil, location: nil,
            startDate: Date(), endDate: Date().addingTimeInterval(86400),
            createdAt: Date(), checkInChecklistID: nil
        )

        // Act
        try database.dbWriter.write { db in
            _ = try CharterRecord.saveCharter(syncNeeded, db: db)
            _ = try CharterRecord.saveCharter(noSyncNeeded, db: db)
        }

        let pending: [CharterRecord] = try database.dbWriter.read { db in
            try CharterRecord.fetchPendingSync(db: db)
        }

        // Assert
        #expect(pending.count == 1)
        #expect(pending.first?.id == syncNeeded.id.uuidString)
        #expect(pending.first?.needsSync == true)
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
