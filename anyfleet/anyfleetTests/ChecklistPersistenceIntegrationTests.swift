//
//  ChecklistPersistenceIntegrationTests.swift
//  anyfleetTests
//
//  Integration tests for checklist execution state persistence
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Checklist Persistence Integration Tests")
struct ChecklistPersistenceIntegrationTests {
    
    // Each test gets its own fresh in-memory database
    private func makeRepository() throws -> LocalRepository {
        let database = try AppDatabase.makeEmpty()
        return LocalRepository(database: database)
    }
    
    /// Helper to create a test charter so that foreign key constraints
    /// on `charterID` are satisfied for execution state records.
    @MainActor
    private func createTestCharter(
        id: UUID = UUID(),
        repository: LocalRepository
    ) async throws -> CharterModel {
        let now = Date()
        let charter = CharterModel(
            id: id,
            name: "Integration Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: now,
            endDate: now.addingTimeInterval(86400), // +1 day
            createdAt: now,
            checkInChecklistID: nil
        )
        try await repository.createCharter(charter)
        return charter
    }
    
    private func makeTestChecklist() -> Checklist {
        Checklist(
            id: UUID(),
            title: "Integration Test Checklist",
            description: "Test Description",
            sections: [
                ChecklistSection(
                    id: UUID(),
                    title: "Pre-Departure",
                    items: [
                        ChecklistItem(id: UUID(), title: "Check fuel level"),
                        ChecklistItem(id: UUID(), title: "Check water tanks"),
                        ChecklistItem(id: UUID(), title: "Check safety equipment")
                    ]
                ),
                ChecklistSection(
                    id: UUID(),
                    title: "Navigation",
                    items: [
                        ChecklistItem(id: UUID(), title: "Plot course"),
                        ChecklistItem(id: UUID(), title: "Check weather")
                    ]
                )
            ],
            checklistType: .general,
            tags: [],
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: .pending
        )
    }
    
    @Test("End-to-end: Create charter, open checklist, toggle items, dismiss, reopen - progress restored")
    @MainActor
    func testEndToEnd_ProgressRestored() async throws {
        // Arrange
        let repository = try makeRepository()
        let libraryStore = LibraryStore(repository: repository)
        let charter = try await createTestCharter(repository: repository)
        let charterID = charter.id
        let checklist = makeTestChecklist()
        let item1ID = checklist.sections[0].items[0].id
        let item2ID = checklist.sections[0].items[1].id
        
        // Step 1: Create checklist in library
        try await repository.createChecklist(checklist)
        
        // Step 2: Create view model and load checklist
        let viewModel1 = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charterID,
            checklistID: checklist.id
        )
        await viewModel1.load()
        
        // Verify initial state
        #expect(viewModel1.checklist != nil)
        #expect(viewModel1.checkedItems.isEmpty)
        
        // Step 3: Toggle some items
        viewModel1.toggleItem(item1ID)
        viewModel1.toggleItem(item2ID)
        
        // Wait for async saves to complete and verify they were saved
        // Poll the repository until the state is saved (with timeout)
        var savedState: ChecklistExecutionState?
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            savedState = try await repository.loadExecutionState(
                checklistID: checklist.id,
                charterID: charterID
            )
            if let state = savedState,
               state.itemStates[item1ID]?.isChecked == true,
               state.itemStates[item2ID]?.isChecked == true {
                break
            }
        }
        
        // Verify items are checked in view model
        #expect(viewModel1.checkedItems.contains(item1ID))
        #expect(viewModel1.checkedItems.contains(item2ID))
        #expect(viewModel1.checkedCount == 2)
        
        // Verify items were saved to repository
        #expect(savedState != nil, "Execution state should be saved to repository")
        #expect(savedState?.itemStates[item1ID]?.isChecked == true, "Item 1 should be checked in repository")
        #expect(savedState?.itemStates[item2ID]?.isChecked == true, "Item 2 should be checked in repository")
        
        // Step 4: "Dismiss" view (viewModel1 goes out of scope)
        // In real app, this would happen when view is dismissed
        
        // Step 5: Create new view model (simulating reopening)
        let viewModel2 = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charterID,
            checklistID: checklist.id
        )
        await viewModel2.load()
        
        // Step 6: Verify progress was restored
        #expect(viewModel2.checklist != nil)
        #expect(viewModel2.checkedItems.contains(item1ID))
        #expect(viewModel2.checkedItems.contains(item2ID))
        #expect(viewModel2.checkedCount == 2)
        #expect(viewModel2.progressPercentage == 2.0 / 5.0)
    }
    
    @Test("End-to-end: Multiple charters with same checklist - independent progress")
    @MainActor
    func testEndToEnd_IndependentProgressPerCharter() async throws {
        // Arrange
        let repository = try makeRepository()
        let libraryStore = LibraryStore(repository: repository)
        let charter1 = try await createTestCharter(repository: repository)
        let charter2 = try await createTestCharter(repository: repository)
        let charter1ID = charter1.id
        let charter2ID = charter2.id
        let checklist = makeTestChecklist()
        let itemID = checklist.sections[0].items[0].id
        
        // Step 1: Create checklist
        try await repository.createChecklist(checklist)
        
        // Step 2: Charter 1 - check item
        let viewModel1 = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charter1ID,
            checklistID: checklist.id
        )
        await viewModel1.load()
        viewModel1.toggleItem(itemID)
        
        // Wait for Charter 1 state to be saved
        var charter1State: ChecklistExecutionState?
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            charter1State = try await repository.loadExecutionState(
                checklistID: checklist.id,
                charterID: charter1ID
            )
            if let state = charter1State,
               state.itemStates[itemID]?.isChecked == true {
                break
            }
        }
        
        // Step 3: Charter 2 - same checklist, item not checked
        let viewModel2 = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charter2ID,
            checklistID: checklist.id
        )
        await viewModel2.load()
        
        // Assert - Charter 1 has item checked
        #expect(viewModel1.checkedItems.contains(itemID))
        
        // Assert - Charter 2 has item unchecked
        #expect(!viewModel2.checkedItems.contains(itemID))
        
        // Step 4: Check item in Charter 2
        viewModel2.toggleItem(itemID)
        
        // Wait for Charter 2 state to be saved
        var charter2State: ChecklistExecutionState?
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            charter2State = try await repository.loadExecutionState(
                checklistID: checklist.id,
                charterID: charter2ID
            )
            if let state = charter2State,
               state.itemStates[itemID]?.isChecked == true {
                break
            }
        }
        
        // Step 5: Reopen Charter 1
        let viewModel1Reopened = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charter1ID,
            checklistID: checklist.id
        )
        await viewModel1Reopened.load()
        
        // Assert - Both charters maintain independent state
        #expect(viewModel1Reopened.checkedItems.contains(itemID))
        
        // Reopen Charter 2
        let viewModel2Reopened = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charter2ID,
            checklistID: checklist.id
        )
        await viewModel2Reopened.load()
        
        #expect(viewModel2Reopened.checkedItems.contains(itemID))
    }
    
    @Test("End-to-end: Toggle multiple items rapidly - all saved correctly")
    @MainActor
    func testEndToEnd_RapidToggles() async throws {
        // Arrange
        let repository = try makeRepository()
        let libraryStore = LibraryStore(repository: repository)
        let charter = try await createTestCharter(repository: repository)
        let charterID = charter.id
        let checklist = makeTestChecklist()
        let allItemIDs = checklist.sections.flatMap { $0.items.map { $0.id } }
        
        // Step 1: Create checklist
        try await repository.createChecklist(checklist)
        
        // Step 2: Create view model
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charterID,
            checklistID: checklist.id
        )
        await viewModel.load()
        
        // Step 3: Rapidly toggle all items
        for itemID in allItemIDs {
            viewModel.toggleItem(itemID)
        }
        
        // Wait for all saves to complete by polling repository state
        var rapidState: ChecklistExecutionState?
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            rapidState = try await repository.loadExecutionState(
                checklistID: checklist.id,
                charterID: charterID
            )
            if let state = rapidState,
               allItemIDs.allSatisfy({ state.itemStates[$0]?.isChecked == true }) {
                break
            }
        }
        
        // Sanity check: repository should have all items checked
        #expect(rapidState != nil, "Execution state for rapid toggles should be saved")
        #expect(allItemIDs.allSatisfy { rapidState?.itemStates[$0]?.isChecked == true })
        
        // Step 4: Reopen view model
        let reopenedViewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charterID,
            checklistID: checklist.id
        )
        await reopenedViewModel.load()
        
        // Assert - All items should be checked
        #expect(reopenedViewModel.checkedCount == allItemIDs.count)
        #expect(reopenedViewModel.progressPercentage == 1.0)
        #expect(reopenedViewModel.isComplete == true)
        
        for itemID in allItemIDs {
            #expect(reopenedViewModel.checkedItems.contains(itemID))
        }
    }
    
    @Test("End-to-end: Clear execution state - resets progress")
    @MainActor
    func testEndToEnd_ClearExecutionState() async throws {
        // Arrange
        let repository = try makeRepository()
        let libraryStore = LibraryStore(repository: repository)
        let charter = try await createTestCharter(repository: repository)
        let charterID = charter.id
        let checklist = makeTestChecklist()
        let itemID = checklist.sections[0].items[0].id
        
        // Step 1: Create checklist and check item
        try await repository.createChecklist(checklist)
        
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charterID,
            checklistID: checklist.id
        )
        await viewModel.load()
        viewModel.toggleItem(itemID)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(viewModel.checkedCount == 1)
        
        // Step 2: Clear execution state
        try await repository.clearExecutionState(
            checklistID: checklist.id,
            charterID: charterID
        )
        
        // Step 3: Reopen view model
        let reopenedViewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: repository,
            charterID: charterID,
            checklistID: checklist.id
        )
        await reopenedViewModel.load()
        
        // Assert - Progress should be reset
        #expect(reopenedViewModel.checkedItems.isEmpty)
        #expect(reopenedViewModel.checkedCount == 0)
        #expect(reopenedViewModel.progressPercentage == 0.0)
    }
}

