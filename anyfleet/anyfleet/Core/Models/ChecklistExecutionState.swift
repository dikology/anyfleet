//
//  ChecklistExecutionState.swift
//  anyfleet
//
//  Domain models for checklist execution state persistence
//

import Foundation

// MARK: - Checklist Execution State

/// Represents the execution state of a checklist scoped to a specific charter.
///
/// This model tracks which items are checked and provides metadata about
/// the execution session (when started, last updated, completion time).
nonisolated struct ChecklistExecutionState: Identifiable, Sendable {
    let id: UUID
    let checklistID: UUID
    let charterID: UUID
    
    /// Mapping of item IDs to their checked state
    var itemStates: [UUID: ChecklistItemState]
    
    let createdAt: Date
    var lastUpdated: Date
    var completedAt: Date?
    
    var syncStatus: SyncStatus
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        checklistID: UUID,
        charterID: UUID,
        itemStates: [UUID: ChecklistItemState] = [:],
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        completedAt: Date? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.checklistID = checklistID
        self.charterID = charterID
        self.itemStates = itemStates
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.completedAt = completedAt
        self.syncStatus = syncStatus
    }
    
    // MARK: - Computed Properties
    
    /// Number of checked items
    var checkedCount: Int {
        itemStates.values.filter { $0.isChecked }.count
    }
    
    /// Progress percentage (requires total items count from checklist)
    /// - Parameter totalItems: Total number of items in the checklist
    /// - Returns: Progress as a value between 0.0 and 1.0
    func progressPercentage(totalItems: Int) -> Double {
        guard totalItems > 0 else { return 0 }
        return Double(checkedCount) / Double(totalItems)
    }
}

// MARK: - Checklist Item State

/// Represents the checked state of a single checklist item
nonisolated struct ChecklistItemState: Sendable {
    let itemID: UUID
    var isChecked: Bool
    var checkedAt: Date?
    
    init(
        itemID: UUID,
        isChecked: Bool = false,
        checkedAt: Date? = nil
    ) {
        self.itemID = itemID
        self.isChecked = isChecked
        self.checkedAt = checkedAt
    }
}

// MARK: - Sync Status

/// Sync status for cloud synchronization
enum SyncStatus: String, Codable, CaseIterable, Sendable {
    case pending    // Not yet synced to backend
    case synced     // Successfully synced
    case error      // Sync failed (retry pending)
}

