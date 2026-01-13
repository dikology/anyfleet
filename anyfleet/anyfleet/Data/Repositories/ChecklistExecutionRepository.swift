//
//  ChecklistExecutionRepository.swift
//  anyfleet
//
//  Protocol for checklist execution state repository operations to enable testing
//

import Foundation

/// Repository protocol for checklist execution state persistence.
///
/// This protocol abstracts the persistence mechanism, allowing for
/// different implementations (local SQLite, cloud, mock for testing).
protocol ChecklistExecutionRepository: Sendable {
    
    /// Save or update the checked state of a single item.
    ///
    /// This is the primary method called on each toggle action.
    /// Implementation should update the execution state and persist immediately.
    ///
    /// - Parameters:
    ///   - checklistID: The checklist being executed
    ///   - charterID: The charter this execution is scoped to
    ///   - itemID: The specific item being toggled
    ///   - isChecked: The new checked state
    /// - Throws: Persistence errors
    func saveItemState(
        checklistID: UUID,
        charterID: UUID,
        itemID: UUID,
        isChecked: Bool
    ) async throws

    /// Save or update notes for a single item.
    ///
    /// This method updates the notes for an item during execution.
    /// Implementation should update the execution state and persist immediately.
    ///
    /// - Parameters:
    ///   - checklistID: The checklist being executed
    ///   - charterID: The charter this execution is scoped to
    ///   - itemID: The specific item being updated
    ///   - notes: The notes text (nil to clear notes)
    /// - Throws: Persistence errors
    func saveItemNotes(
        checklistID: UUID,
        charterID: UUID,
        itemID: UUID,
        notes: String?
    ) async throws
    
    /// Load the complete execution state for a checklist in a charter.
    ///
    /// Returns nil if no previous execution exists (first time opened).
    ///
    /// - Parameters:
    ///   - checklistID: The checklist to load state for
    ///   - charterID: The charter context
    /// - Returns: The execution state, or nil if never executed in this charter
    /// - Throws: Database errors
    func loadExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws -> ChecklistExecutionState?
    
    /// Load all execution states for a specific charter.
    ///
    /// Useful for charter detail view to show progress of all checklists.
    ///
    /// - Parameter charterID: The charter context
    /// - Returns: Array of execution states (empty if none)
    /// - Throws: Database errors
    func loadAllStatesForCharter(_ charterID: UUID) async throws -> [ChecklistExecutionState]
    
    /// Clear (delete) execution state for a checklist in a charter.
    ///
    /// Useful for "reset" functionality in charter detail view.
    ///
    /// - Parameters:
    ///   - checklistID: The checklist
    ///   - charterID: The charter context
    /// - Throws: Database errors
    func clearExecutionState(
        checklistID: UUID,
        charterID: UUID
    ) async throws
}

/// Make LocalRepository conform to the protocol
extension LocalRepository: ChecklistExecutionRepository {}

