//
//  ChecklistExecutionViewModel.swift
//  anyfleet
//
//  ViewModel for checklist execution flow, tracking progress per charter
//

import Foundation
import Observation

/// ViewModel managing checklist execution state and progress tracking.
///
/// Handles loading the checklist, tracking checked items, and calculating progress
/// for a checklist instance scoped to a specific charter.
@MainActor
@Observable
final class ChecklistExecutionViewModel {
    // MARK: - Dependencies
    
    private let libraryStore: LibraryStore
    private let executionRepository: ChecklistExecutionRepository
    private let charterID: UUID
    private let checklistID: UUID
    
    // MARK: - State
    
    /// The checklist being executed
    var checklist: Checklist?
    
    /// Set of checked item IDs
    var checkedItems: Set<UUID> = []
    
    /// Set of expanded section IDs
    var expandedSections: Set<UUID> = []
    
    /// Whether the checklist is currently being loaded
    var isLoading = false
    
    /// Error that occurred during loading, if any
    var loadError: Error?
    
    // MARK: - Computed Properties
    
    /// Total number of items in the checklist
    var totalItems: Int {
        checklist?.totalItems ?? 0
    }
    
    /// Number of checked items
    var checkedCount: Int {
        checkedItems.count
    }
    
    /// Progress percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(checkedCount) / Double(totalItems)
    }
    
    /// Whether the checklist is complete
    var isComplete: Bool {
        totalItems > 0 && checkedCount == totalItems
    }
    
    // MARK: - Initialization
    
    /// Creates a new ChecklistExecutionViewModel.
    ///
    /// - Parameters:
    ///   - libraryStore: The library store for fetching checklists
    ///   - executionRepository: The repository for persisting execution state
    ///   - charterID: The ID of the charter this checklist is scoped to
    ///   - checklistID: The ID of the checklist to execute
    init(
        libraryStore: LibraryStore,
        executionRepository: ChecklistExecutionRepository,
        charterID: UUID,
        checklistID: UUID
    ) {
        self.libraryStore = libraryStore
        self.executionRepository = executionRepository
        self.charterID = charterID
        self.checklistID = checklistID
    }
    
    // MARK: - Actions
    
    /// Loads the checklist from the library store and restores saved execution state.
    func load() async {
        guard !isLoading else { return }
        
        AppLogger.view.startOperation("Load Checklist for Execution")
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        
        do {
            // Step 1: Load checklist template
            checklist = try await libraryStore.fetchChecklist(checklistID)
            
            // Step 2: Load saved execution state
            if let savedState = try await executionRepository
                .loadExecutionState(checklistID: checklistID, charterID: charterID) {
                checkedItems = Set(savedState.itemStates
                    .filter { $0.value.isChecked }
                    .map { $0.key }
                )
                AppLogger.view.debug("Restored \(checkedItems.count) checked items from saved state")
            }
            
            // Step 3: Expand sections that are marked as expanded by default
            if let checklist = checklist {
                expandedSections = Set(
                    checklist.sections
                        .filter { $0.isExpandedByDefault }
                        .map { $0.id }
                )
            }
            
            AppLogger.view.info("Loaded checklist: \(checklist?.title ?? "unknown")")
            AppLogger.view.completeOperation("Load Checklist for Execution")
        } catch {
            AppLogger.view.failOperation("Load Checklist for Execution", error: error)
            loadError = error
        }
    }
    
    /// Toggles the checked state of an item and persists the change.
    ///
    /// - Parameter itemID: The ID of the item to toggle
    func toggleItem(_ itemID: UUID) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            if checkedItems.contains(itemID) {
                checkedItems.remove(itemID)
            } else {
                checkedItems.insert(itemID)
            }
        }
        
        // Save to database on every toggle
        let isChecked = checkedItems.contains(itemID)
        
        Task {
            do {
                try await executionRepository.saveItemState(
                    checklistID: checklistID,
                    charterID: charterID,
                    itemID: itemID,
                    isChecked: isChecked
                )
                AppLogger.view.debug("Saved item state for \(itemID.uuidString), progress: \(Int(progressPercentage * 100))%")
            } catch {
                AppLogger.view.failOperation("Save Item State", error: error)
                // Silently fail but log - don't block UI
            }
        }
    }
    
    /// Toggles the expanded state of a section.
    ///
    /// - Parameter sectionID: The ID of the section to toggle
    func toggleSection(_ sectionID: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedSections.contains(sectionID) {
                expandedSections.remove(sectionID)
            } else {
                expandedSections.insert(sectionID)
            }
        }
    }
    
    /// Returns the progress for a specific section.
    ///
    /// - Parameter section: The section to calculate progress for
    /// - Returns: A tuple of (checked count, total count)
    func sectionProgress(_ section: ChecklistSection) -> (checked: Int, total: Int) {
        let checked = section.items.filter { checkedItems.contains($0.id) }.count
        return (checked, section.items.count)
    }
    
    /// Returns whether an item is checked.
    ///
    /// - Parameter itemID: The ID of the item to check
    /// - Returns: True if the item is checked, false otherwise
    func isItemChecked(_ itemID: UUID) -> Bool {
        checkedItems.contains(itemID)
    }
    
    /// Returns whether a section is expanded.
    ///
    /// - Parameter sectionID: The ID of the section to check
    /// - Returns: True if the section is expanded, false otherwise
    func isSectionExpanded(_ sectionID: UUID) -> Bool {
        expandedSections.contains(sectionID)
    }
}

