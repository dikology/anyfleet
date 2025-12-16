//
//  Checklist.swift
//  anyfleet
//
//  Full Checklist domain model with sections and items
//

import Foundation

// MARK: - Checklist

/// A complete checklist for yacht operations with sections and items
nonisolated struct Checklist: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var sections: [ChecklistSection]
    var checklistType: ChecklistType
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var syncStatus: ContentSyncStatus
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        sections: [ChecklistSection] = [],
        checklistType: ChecklistType = .general,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: ContentSyncStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.sections = sections
        self.checklistType = checklistType
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    // MARK: - Computed Properties
    
    /// Total number of items across all sections
    var totalItems: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }
    
    /// All items for iteration
    var allItems: [ChecklistItem] {
        sections.flatMap { $0.items }
    }
    
    // MARK: - Mutating Methods
    
    /// Add a new section
    mutating func addSection(_ section: ChecklistSection) {
        sections.append(section)
        updatedAt = Date()
    }
    
    /// Remove a section
    mutating func removeSection(id: UUID) {
        sections.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    /// Create an empty checklist
    static func empty() -> Checklist {
        Checklist(title: "")
    }
}

// MARK: - Checklist Section

/// A grouping of checklist items
nonisolated struct ChecklistSection: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var icon: String?
    var description: String?
    var items: [ChecklistItem]
    var isExpandedByDefault: Bool
    var sortOrder: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        icon: String? = nil,
        description: String? = nil,
        items: [ChecklistItem] = [],
        isExpandedByDefault: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.description = description
        self.items = items
        self.isExpandedByDefault = isExpandedByDefault
        self.sortOrder = sortOrder
    }
}

// MARK: - Checklist Item

/// An individual checklist item
nonisolated struct ChecklistItem: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var title: String
    var itemDescription: String?
    var isOptional: Bool
    var isRequired: Bool
    var tags: [String]
    var estimatedMinutes: Int?
    var sortOrder: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        itemDescription: String? = nil,
        isOptional: Bool = false,
        isRequired: Bool = false,
        tags: [String] = [],
        estimatedMinutes: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.itemDescription = itemDescription
        self.isOptional = isOptional
        self.isRequired = isRequired
        self.tags = tags
        self.estimatedMinutes = estimatedMinutes
        self.sortOrder = sortOrder
    }
}

// MARK: - Checklist Type

/// Types of checklists for different use cases
enum ChecklistType: String, Codable, CaseIterable, Sendable {
    case preCharter = "pre_charter"
    case checkIn = "check_in"
    case daily = "daily"
    case postCharter = "post_charter"
    case emergency = "emergency"
    case general = "general"
    case maintenance = "maintenance"
    case safety = "safety"
    case provisioning = "provisioning"
    
    var displayName: String {
        switch self {
        case .preCharter: return "Pre-Charter"
        case .checkIn: return "Check-In"
        case .daily: return "Daily"
        case .postCharter: return "Post-Charter"
        case .emergency: return "Emergency"
        case .general: return "General"
        case .maintenance: return "Maintenance"
        case .safety: return "Safety"
        case .provisioning: return "Provisioning"
        }
    }
    
    var icon: String {
        switch self {
        case .preCharter: return "calendar.badge.clock"
        case .checkIn: return "arrow.down.to.line"
        case .daily: return "sun.max"
        case .postCharter: return "checkmark.circle"
        case .emergency: return "exclamationmark.triangle"
        case .general: return "checklist"
        case .maintenance: return "wrench.and.screwdriver"
        case .safety: return "shield.checkered"
        case .provisioning: return "cart"
        }
    }
}

