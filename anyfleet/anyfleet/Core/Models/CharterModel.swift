//
//  CharterModel.swift
//
//  Domain model for Charter
//

import Foundation

// MARK: - Charter Model

nonisolated struct CharterModel: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var boatName: String?
    var location: String?
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    /// Check-in checklist ID
    var checkInChecklistID: UUID?

    // MARK: Sync Fields

    /// Backend server ID (UUID from the API). Nil until first sync.
    var serverID: UUID?
    /// Visibility level controlling discovery. Defaults to private.
    var visibility: CharterVisibility = .private
    /// Whether this charter has local changes not yet pushed to the server.
    var needsSync: Bool = false
    /// Timestamp of last successful sync with the server.
    var lastSyncedAt: Date?

    // MARK: Geolocation Fields

    var latitude: Double?
    var longitude: Double?
    var locationPlaceID: String?

    // MARK: - Computed Properties

    /// Days until charter starts (negative if already started)
    var daysUntilStart: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: startDate).day ?? 0
    }

    /// Charter duration in days
    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    /// Whether this charter is upcoming (starts in the future)
    var isUpcoming: Bool {
        startDate > Date()
    }

    /// Whether this charter can appear in the community discovery feed
    var isDiscoverable: Bool {
        visibility != .private && isUpcoming
    }

    /// Urgency level based on days until start
    var urgencyLevel: CharterUrgencyLevel {
        switch daysUntilStart {
        case ..<0: return .past
        case 0...7: return .imminent
        case 8...30: return .soon
        default: return .future
        }
    }
}
