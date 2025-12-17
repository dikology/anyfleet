//
//  ChecklistExecutionRepositoryTests.swift
//  anyfleetTests
//
//  Unit tests for ChecklistExecutionRepository using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("ChecklistExecutionRepository Tests")
struct ChecklistExecutionRepositoryTests {
    
    // Each test gets its own fresh in-memory database
    private func makeRepository() throws -> ChecklistExecutionRepository {
        let database = try AppDatabase.makeEmpty()
        return LocalRepository(database: database)
    }
    
    @Test("Save new execution state - creates new state")
    func testSaveNewExecutionState() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charterID = UUID()
        let itemID = UUID()
        
        // Act
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        // Assert
        let loaded = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        #expect(loaded != nil)
        #expect(loaded?.checklistID == checklistID)
        #expect(loaded?.charterID == charterID)
        #expect(loaded?.itemStates[itemID]?.isChecked == true)
        #expect(loaded?.itemStates[itemID]?.checkedAt != nil)
    }
    
    @Test("Update existing state - toggles item")
    func testUpdateExistingState() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charterID = UUID()
        let itemID = UUID()
        
        // Act - Save as checked
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        // Act - Toggle to unchecked
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: false
        )
        
        // Assert
        let loaded = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        #expect(loaded != nil)
        #expect(loaded?.itemStates[itemID]?.isChecked == false)
    }
    
    @Test("Independent progress per charter - same checklist different charters")
    func testIndependentProgressPerCharter() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charter1ID = UUID()
        let charter2ID = UUID()
        let itemID = UUID()
        
        // Act - Charter 1: checked
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charter1ID,
            itemID: itemID,
            isChecked: true
        )
        
        // Act - Charter 2: unchecked
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charter2ID,
            itemID: itemID,
            isChecked: false
        )
        
        // Assert
        let state1 = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charter1ID
        )
        let state2 = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charter2ID
        )
        
        #expect(state1 != nil)
        #expect(state2 != nil)
        #expect(state1?.itemStates[itemID]?.isChecked == true)
        #expect(state2?.itemStates[itemID]?.isChecked == false)
        #expect(state1?.id != state2?.id) // Different execution states
    }
    
    @Test("Load execution state - returns nil when no state exists")
    func testLoadExecutionState_NoStateExists() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charterID = UUID()
        
        // Act
        let loaded = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        // Assert
        #expect(loaded == nil)
    }
    
    @Test("Save multiple items - updates state correctly")
    func testSaveMultipleItems() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charterID = UUID()
        let item1ID = UUID()
        let item2ID = UUID()
        let item3ID = UUID()
        
        // Act - Save multiple items
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: item1ID,
            isChecked: true
        )
        
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: item2ID,
            isChecked: true
        )
        
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: item3ID,
            isChecked: false
        )
        
        // Assert
        let loaded = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        #expect(loaded != nil)
        #expect(loaded?.itemStates.count == 3)
        #expect(loaded?.itemStates[item1ID]?.isChecked == true)
        #expect(loaded?.itemStates[item2ID]?.isChecked == true)
        #expect(loaded?.itemStates[item3ID]?.isChecked == false)
        #expect(loaded?.checkedCount == 2)
    }
    
    @Test("Load all states for charter - returns all execution states")
    func testLoadAllStatesForCharter() async throws {
        // Arrange
        let repository = try makeRepository()
        let charterID = UUID()
        let checklist1ID = UUID()
        let checklist2ID = UUID()
        let itemID = UUID()
        
        // Act - Create execution states for two different checklists in same charter
        try await repository.saveItemState(
            checklistID: checklist1ID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        try await repository.saveItemState(
            checklistID: checklist2ID,
            charterID: charterID,
            itemID: itemID,
            isChecked: false
        )
        
        // Act
        let allStates = try await repository.loadAllStatesForCharter(charterID)
        
        // Assert
        #expect(allStates.count == 2)
        #expect(allStates.contains { $0.checklistID == checklist1ID })
        #expect(allStates.contains { $0.checklistID == checklist2ID })
        #expect(allStates.allSatisfy { $0.charterID == charterID })
    }
    
    @Test("Load all states for charter - returns empty array when no states exist")
    func testLoadAllStatesForCharter_Empty() async throws {
        // Arrange
        let repository = try makeRepository()
        let charterID = UUID()
        
        // Act
        let allStates = try await repository.loadAllStatesForCharter(charterID)
        
        // Assert
        #expect(allStates.isEmpty)
    }
    
    @Test("Clear execution state - deletes state")
    func testClearExecutionState() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charterID = UUID()
        let itemID = UUID()
        
        // Act - Create state
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        // Verify it exists
        let beforeClear = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        #expect(beforeClear != nil)
        
        // Act - Clear state
        try await repository.clearExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        
        // Assert
        let afterClear = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        #expect(afterClear == nil)
    }
    
    @Test("Clear execution state - only clears specified checklist in charter")
    func testClearExecutionState_OnlyClearsSpecified() async throws {
        // Arrange
        let repository = try makeRepository()
        let charterID = UUID()
        let checklist1ID = UUID()
        let checklist2ID = UUID()
        let itemID = UUID()
        
        // Act - Create states for two checklists
        try await repository.saveItemState(
            checklistID: checklist1ID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        try await repository.saveItemState(
            checklistID: checklist2ID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        // Act - Clear only checklist1
        try await repository.clearExecutionState(
            checklistID: checklist1ID,
            charterID: charterID
        )
        
        // Assert
        let state1 = try await repository.loadExecutionState(
            checklistID: checklist1ID,
            charterID: charterID
        )
        let state2 = try await repository.loadExecutionState(
            checklistID: checklist2ID,
            charterID: charterID
        )
        
        #expect(state1 == nil) // Cleared
        #expect(state2 != nil) // Still exists
    }
    
    @Test("Save item state - updates lastUpdated timestamp")
    func testSaveItemState_UpdatesTimestamp() async throws {
        // Arrange
        let repository = try makeRepository()
        let checklistID = UUID()
        let charterID = UUID()
        let itemID = UUID()
        
        // Act - Create initial state
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: true
        )
        
        let firstState = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        let firstUpdated = firstState?.lastUpdated
        
        // Wait a small amount to ensure timestamp difference
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Act - Update state
        try await repository.saveItemState(
            checklistID: checklistID,
            charterID: charterID,
            itemID: itemID,
            isChecked: false
        )
        
        let secondState = try await repository.loadExecutionState(
            checklistID: checklistID,
            charterID: charterID
        )
        let secondUpdated = secondState?.lastUpdated
        
        // Assert
        #expect(firstUpdated != nil)
        #expect(secondUpdated != nil)
        #expect(secondUpdated! > firstUpdated!) // Timestamp should be updated
    }
}

