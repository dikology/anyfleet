//
//  CharterModel.swift
//  
//
//  Domain model for Charter
//

import Foundation

// MARK: - Charter Model

struct CharterModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var boatName: String?
    var location: String?
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    /// Check-in checklist ID
    var checkInChecklistID: UUID?
    
    /// Days until charter starts (negative if already started)
    var daysUntilStart: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }
    
    /// Charter duration in days
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}
