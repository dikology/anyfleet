//
//  ChecklistExecutionViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for ChecklistExecutionViewModel using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("ChecklistExecutionViewModel Tests")
struct ChecklistExecutionViewModelTests {
    
    // Helper to create a test checklist
    private func makeTestChecklist(id: UUID = UUID()) -> Checklist {
        Checklist(
            id: id,
            title: "Test Checklist",
            description: "Test Description",
            sections: [
                ChecklistSection(
                    id: UUID(),
                    title: "Section 1",
                    items: [
                        ChecklistItem(id: UUID(), title: "Item 1"),
                        ChecklistItem(id: UUID(), title: "Item 2")
                    ]
                ),
                ChecklistSection(
                    id: UUID(),
                    title: "Section 2",
                    items: [
                        ChecklistItem(id: UUID(), title: "Item 3")
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
    
    // Helper to create a mock execution repository
    private func makeMockRepository() -> MockExecutionRepository {
        MockExecutionRepository()
    }
    
    // Helper to create a library store with a checklist pre-loaded
    @MainActor
    private func makeLibraryStore(with checklist: Checklist) async throws -> LibraryStore {
        let database = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: database)
        
        // Pre-load the checklist into the repository
        try await repository.createChecklist(checklist)
        
        let store = LibraryStore(repository: repository)
        return store
    }
    
    @Test("Load checklist - loads template and restores saved progress")
    @MainActor
    func testLoad_RestoresSavedProgress() async throws {
        // Arrange
        let checklist = makeTestChecklist()
        let item1ID = checklist.sections[0].items[0].id
        let item2ID = checklist.sections[0].items[1].id
        
        let libraryStore = try await makeLibraryStore(with: checklist)
        
        let mockRepository = makeMockRepository()
        let savedState = ChecklistExecutionState(
            checklistID: checklist.id,
            charterID: UUID(),
            itemStates: [
                item1ID: ChecklistItemState(itemID: item1ID, isChecked: true),
                item2ID: ChecklistItemState(itemID: item2ID, isChecked: false)
            ]
        )
        mockRepository.savedState = savedState
        
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: mockRepository,
            charterID: savedState.charterID,
            checklistID: checklist.id
        )
        
        // Act
        await viewModel.load()
        
        // Assert
        #expect(viewModel.checklist != nil)
        #expect(viewModel.checklist?.id == checklist.id)
        #expect(viewModel.checkedItems.contains(item1ID))
        #expect(!viewModel.checkedItems.contains(item2ID))
        #expect(viewModel.checkedCount == 1)
    }
    
    @Test("Load checklist - handles first-time execution with no saved state")
    @MainActor
    func testLoad_FirstTimeExecution() async throws {
        // Arrange
        let checklist = makeTestChecklist()
        let libraryStore = try await makeLibraryStore(with: checklist)
        
        let mockRepository = makeMockRepository()
        mockRepository.savedState = nil // No saved state
        
        let charterID = UUID()
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: mockRepository,
            charterID: charterID,
            checklistID: checklist.id
        )
        
        // Act
        await viewModel.load()
        
        // Assert
        #expect(viewModel.checklist != nil)
        #expect(viewModel.checkedItems.isEmpty)
        #expect(viewModel.checkedCount == 0)
    }
    
    @Test("Toggle item - saves to repository")
    @MainActor
    func testToggleItem_SavesToRepository() async throws {
        // Arrange
        let checklist = makeTestChecklist()
        let itemID = checklist.sections[0].items[0].id
        
        let libraryStore = try await makeLibraryStore(with: checklist)
        
        let mockRepository = makeMockRepository()
        let charterID = UUID()
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: mockRepository,
            charterID: charterID,
            checklistID: checklist.id
        )
        
        await viewModel.load()
        
        // Act
        viewModel.toggleItem(itemID)
        
        // Wait a bit for async save to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Assert
        #expect(viewModel.checkedItems.contains(itemID))
        #expect(mockRepository.saveItemStateCallCount == 1)
        #expect(mockRepository.lastSavedItemID == itemID)
        #expect(mockRepository.lastSavedIsChecked == true)
    }
    
    @Test("Toggle item - updates checked count")
    @MainActor
    func testToggleItem_UpdatesCheckedCount() async throws {
        // Arrange
        let checklist = makeTestChecklist()
        let item1ID = checklist.sections[0].items[0].id
        let item2ID = checklist.sections[0].items[1].id
        
        let libraryStore = try await makeLibraryStore(with: checklist)
        
        let mockRepository = makeMockRepository()
        let charterID = UUID()
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: mockRepository,
            charterID: charterID,
            checklistID: checklist.id
        )
        
        await viewModel.load()
        
        // Act - Toggle first item
        viewModel.toggleItem(item1ID)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert
        #expect(viewModel.checkedCount == 1)
        #expect(viewModel.progressPercentage == 1.0 / 3.0)
        
        // Act - Toggle second item
        viewModel.toggleItem(item2ID)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert
        #expect(viewModel.checkedCount == 2)
        #expect(viewModel.progressPercentage == 2.0 / 3.0)
        
        // Act - Toggle first item again (uncheck)
        viewModel.toggleItem(item1ID)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert
        #expect(viewModel.checkedCount == 1)
        #expect(viewModel.progressPercentage == 1.0 / 3.0)
    }
    
    @Test("Progress percentage - calculates correctly")
    @MainActor
    func testProgressPercentage() async throws {
        // Arrange
        let checklist = makeTestChecklist()
        let item1ID = checklist.sections[0].items[0].id
        
        let libraryStore = try await makeLibraryStore(with: checklist)
        
        let mockRepository = makeMockRepository()
        let charterID = UUID()
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: mockRepository,
            charterID: charterID,
            checklistID: checklist.id
        )
        
        await viewModel.load()
        
        // Assert - Initial state
        #expect(viewModel.totalItems == 3)
        #expect(viewModel.checkedCount == 0)
        #expect(viewModel.progressPercentage == 0.0)
        #expect(viewModel.isComplete == false)
        
        // Act - Check one item
        viewModel.toggleItem(item1ID)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert
        #expect(viewModel.progressPercentage == 1.0 / 3.0)
        #expect(viewModel.isComplete == false)
    }
    
    @Test("Load checklist - expands sections marked as expanded by default")
    @MainActor
    func testLoad_ExpandsSectionsByDefault() async throws {
        // Arrange
        var section1 = ChecklistSection(
            id: UUID(),
            title: "Section 1",
            items: [ChecklistItem(id: UUID(), title: "Item 1")]
        )
        section1.isExpandedByDefault = true
        
        var section2 = ChecklistSection(
            id: UUID(),
            title: "Section 2",
            items: [ChecklistItem(id: UUID(), title: "Item 2")]
        )
        section2.isExpandedByDefault = false
        
        let checklist = Checklist(
            id: UUID(),
            title: "Test",
            sections: [section1, section2],
            checklistType: .general
        )
        
        let libraryStore = try await makeLibraryStore(with: checklist)
        
        let mockRepository = makeMockRepository()
        let charterID = UUID()
        let viewModel = ChecklistExecutionViewModel(
            libraryStore: libraryStore,
            executionRepository: mockRepository,
            charterID: charterID,
            checklistID: checklist.id
        )
        
        // Act
        await viewModel.load()
        
        // Assert
        #expect(viewModel.expandedSections.contains(section1.id))
        #expect(!viewModel.expandedSections.contains(section2.id))
    }
}

// MARK: - Mock Implementations

/// Mock execution repository for testing
final class MockExecutionRepository: ChecklistExecutionRepository, @unchecked Sendable {
    var savedState: ChecklistExecutionState?
    var saveItemStateCallCount = 0
    var lastSavedItemID: UUID?
    var lastSavedIsChecked: Bool?
    var loadExecutionStateCallCount = 0
    var clearExecutionStateCallCount = 0
    
    func saveItemState(
        checklistID: UUID,
        charterID: UUID,
        itemID: UUID,
        isChecked: Bool
    ) async throws {
        saveItemStateCallCount += 1
        lastSavedItemID = itemID
        lastSavedIsChecked = isChecked
        
        // Update or create saved state
        if var state = savedState, state.checklistID == checklistID, state.charterID == charterID {
            state.itemStates[itemID] = ChecklistItemState(
                itemID: itemID,
                isChecked: isChecked,
                checkedAt: isChecked ? Date() : nil
            )
            state.lastUpdated = Date()
            savedState = state
        } else {
            savedState = ChecklistExecutionState(
                checklistID: checklistID,
                charterID: charterID,
                itemStates: [
                    itemID: ChecklistItemState(
                        itemID: itemID,
                        isChecked: isChecked,
                        checkedAt: isChecked ? Date() : nil
                    )
                ]
            )
        }
    }
    
    func loadExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws -> ChecklistExecutionState? {
        loadExecutionStateCallCount += 1
        
        if let state = savedState,
           state.checklistID == checklistID,
           state.charterID == charterID {
            return state
        }
        return nil
    }
    
    func loadAllStatesForCharter(_ charterID: UUID) async throws -> [ChecklistExecutionState] {
        if let state = savedState, state.charterID == charterID {
            return [state]
        }
        return []
    }
    
    func clearExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws {
        clearExecutionStateCallCount += 1
        if let state = savedState,
           state.checklistID == checklistID,
           state.charterID == charterID {
            savedState = nil
        }
    }
}

