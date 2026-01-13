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
final class ChecklistExecutionViewModel: ErrorHandling {
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

    /// Dictionary of item notes keyed by item ID
    var itemNotes: [UUID: String] = [:]
    
    /// Set of expanded section IDs
    var expandedSections: Set<UUID> = []
    
    /// Whether the checklist is currently being loaded
    var isLoading = false

    var currentError: AppError?
    var showErrorBanner: Bool = false
    
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
        // Skip loading if checklist is already set (useful for previews)
        guard checklist == nil else { return }
        guard !isLoading else { return }

        AppLogger.view.startOperation("Load Checklist for Execution")
        isLoading = true
        defer { isLoading = false }

        do {
            // Step 1: Ensure library metadata is loaded (for on-demand fetching)
            if libraryStore.myChecklists.isEmpty {
                await libraryStore.loadLibrary()
            }

            // Step 2: Load checklist template
            checklist = try await libraryStore.fetchFullContent(checklistID)
            if checklist == nil {
                throw AppError.notFound(entity: "Checklist", id: checklistID)
            }

            // Step 3: Load saved execution state
            if let savedState = try await executionRepository
                .loadExecutionState(checklistID: checklistID, charterID: charterID) {
                checkedItems = Set(savedState.itemStates
                    .filter { $0.value.isChecked }
                    .map { $0.key }
                )
                itemNotes = savedState.itemStates
                    .compactMap { (itemID, state) -> (UUID, String)? in
                        guard let notes = state.notes, !notes.isEmpty else { return nil }
                        return (itemID, notes)
                    }
                    .reduce(into: [:]) { $0[$1.0] = $1.1 }

                AppLogger.view.debug("Restored \(checkedItems.count) checked items and \(itemNotes.count) items with notes from saved state")
            }

            // Step 4: Expand sections that are marked as expanded by default
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
            handleError(error)
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

    /// Save notes for a checklist item.
    ///
    /// - Parameters:
    ///   - itemID: The ID of the item to save notes for
    ///   - notes: The notes text (nil to clear notes)
    func saveNotes(for itemID: UUID, notes: String?) {
        // Update local state
        if let notes = notes, !notes.isEmpty {
            itemNotes[itemID] = notes
        } else {
            itemNotes.removeValue(forKey: itemID)
        }

        // Save to database
        Task {
            do {
                try await executionRepository.saveItemNotes(
                    checklistID: checklistID,
                    charterID: charterID,
                    itemID: itemID,
                    notes: notes
                )
                AppLogger.view.debug("Saved notes for item \(itemID.uuidString)")
            } catch {
                AppLogger.view.failOperation("Save Item Notes", error: error)
                // Silently fail but log - don't block UI
            }
        }
    }

    /// Returns the notes for a specific item.
    ///
    /// - Parameter itemID: The ID of the item to get notes for
    /// - Returns: The notes text, or nil if no notes exist
    func notes(for itemID: UUID) -> String? {
        itemNotes[itemID]
    }
}

