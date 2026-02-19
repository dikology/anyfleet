//
//  DiscoverableCharterTests.swift
//  anyfleetTests
//
//  Unit tests for DiscoverableCharter model, urgency levels,
//  and API response → domain model conversions.
//

import Foundation
import Testing
import CoreLocation
@testable import anyfleet

@Suite("DiscoverableCharter Tests")
struct DiscoverableCharterTests {

    // MARK: - Helpers

    private func makeCharter(
        startDate: Date = Date().addingTimeInterval(86400 * 5),
        endDate: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        distanceKm: Double? = nil
    ) -> DiscoverableCharter {
        let end = endDate ?? startDate.addingTimeInterval(86400 * 7)
        return DiscoverableCharter(
            id: UUID(),
            name: "Test Charter",
            boatName: "Sea Breeze",
            destination: latitude != nil ? "Mallorca" : nil,
            startDate: startDate,
            endDate: end,
            latitude: latitude,
            longitude: longitude,
            distanceKm: distanceKm,
            captain: CaptainBasicInfo(id: UUID(), username: "captain_jack", profileImageThumbnailURL: nil)
        )
    }

    // MARK: - hasLocation

    @Test("hasLocation - true when both lat and lon present")
    func testHasLocation_BothPresent() {
        let charter = makeCharter(latitude: 39.5, longitude: 2.65)
        #expect(charter.hasLocation == true)
    }

    @Test("hasLocation - false when latitude is nil")
    func testHasLocation_LatNil() {
        let charter = makeCharter(latitude: nil, longitude: 2.65)
        #expect(charter.hasLocation == false)
    }

    @Test("hasLocation - false when longitude is nil")
    func testHasLocation_LonNil() {
        let charter = makeCharter(latitude: 39.5, longitude: nil)
        #expect(charter.hasLocation == false)
    }

    @Test("hasLocation - false when both nil")
    func testHasLocation_BothNil() {
        let charter = makeCharter(latitude: nil, longitude: nil)
        #expect(charter.hasLocation == false)
    }

    // MARK: - coordinate

    @Test("coordinate - returns CLLocationCoordinate2D when lat/lon present")
    func testCoordinate_Present() {
        let lat = 39.5, lon = 2.65
        let charter = makeCharter(latitude: lat, longitude: lon)
        let coord = charter.coordinate
        #expect(coord != nil)
        #expect(abs((coord?.latitude ?? 0) - lat) < 0.0001)
        #expect(abs((coord?.longitude ?? 0) - lon) < 0.0001)
    }

    @Test("coordinate - returns nil when location missing")
    func testCoordinate_Missing() {
        let charter = makeCharter(latitude: nil, longitude: nil)
        #expect(charter.coordinate == nil)
    }

    // MARK: - durationDays

    @Test("durationDays - calculates correctly")
    func testDurationDays() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 10, to: start)!
        let charter = makeCharter(startDate: start, endDate: end)
        #expect(charter.durationDays == 10)
    }

    @Test("durationDays - zero for same day")
    func testDurationDays_ZeroForSameDay() {
        let now = Date()
        let charter = makeCharter(startDate: now, endDate: now)
        #expect(charter.durationDays == 0)
    }

    // MARK: - daysUntilStart

    @Test("daysUntilStart - positive for future charter")
    func testDaysUntilStart_Future() {
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let charter = makeCharter(startDate: future)
        #expect(charter.daysUntilStart > 0)
    }

    @Test("daysUntilStart - negative for past charter")
    func testDaysUntilStart_Past() {
        let past = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let charter = makeCharter(startDate: past)
        #expect(charter.daysUntilStart < 0)
    }

    // MARK: - urgencyLevel

    @Test("urgencyLevel - past for charters that already started")
    func testUrgencyLevel_Past() {
        let past = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let charter = makeCharter(startDate: past)
        #expect(charter.urgencyLevel == .past)
    }

    @Test("urgencyLevel - imminent for next 7 days")
    func testUrgencyLevel_Imminent() {
        let soon = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        let charter = makeCharter(startDate: soon)
        #expect(charter.urgencyLevel == .imminent)
    }

    @Test("urgencyLevel - soon for 8-30 days away")
    func testUrgencyLevel_Soon() {
        let upcoming = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
        let charter = makeCharter(startDate: upcoming)
        #expect(charter.urgencyLevel == .soon)
    }

    @Test("urgencyLevel - future for more than 30 days away")
    func testUrgencyLevel_Future() {
        let distant = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        let charter = makeCharter(startDate: distant)
        #expect(charter.urgencyLevel == .future)
    }

    // MARK: - dateRange

    @Test("dateRange - returns non-empty formatted string")
    func testDateRange_NonEmpty() {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        let charter = makeCharter(startDate: start, endDate: end)
        #expect(!charter.dateRange.isEmpty)
        #expect(charter.dateRange.contains("–"))
    }

    // MARK: - API Response Conversion: CharterWithUserAPIResponse → DiscoverableCharter

    @Test("CharterWithUserAPIResponse.toDiscoverableCharter - maps all fields")
    func testCharterWithUserAPIResponse_Conversion() {
        let userID = UUID()
        let charterID = UUID()
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!

        let response = CharterWithUserAPIResponse(
            id: charterID,
            name: "Croatia Charter",
            boatName: "Swift Wind",
            locationText: "Split, Croatia",
            startDate: start,
            endDate: end,
            latitude: 43.5,
            longitude: 16.4,
            visibility: "community",
            user: UserBasicAPIResponse(
                id: userID,
                username: "sailor_joe",
                profileImageThumbnailUrl: "https://example.com/thumb.jpg"
            ),
            distanceKm: 42.0
        )

        let charter = response.toDiscoverableCharter()

        #expect(charter.id == charterID)
        #expect(charter.name == "Croatia Charter")
        #expect(charter.boatName == "Swift Wind")
        #expect(charter.destination == "Split, Croatia")
        #expect(charter.startDate == start)
        #expect(charter.endDate == end)
        #expect(charter.latitude == 43.5)
        #expect(charter.longitude == 16.4)
        #expect(charter.distanceKm == 42.0)
        #expect(charter.captain.id == userID)
        #expect(charter.captain.username == "sailor_joe")
        #expect(charter.captain.profileImageThumbnailURL?.absoluteString == "https://example.com/thumb.jpg")
    }

    @Test("CharterWithUserAPIResponse.toDiscoverableCharter - handles nil optional fields")
    func testCharterWithUserAPIResponse_NilFields() {
        let response = CharterWithUserAPIResponse(
            id: UUID(),
            name: "Minimal Charter",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            latitude: nil,
            longitude: nil,
            visibility: "public",
            user: UserBasicAPIResponse(id: UUID(), username: nil, profileImageThumbnailUrl: nil),
            distanceKm: nil
        )

        let charter = response.toDiscoverableCharter()

        #expect(charter.boatName == nil)
        #expect(charter.destination == nil)
        #expect(charter.latitude == nil)
        #expect(charter.longitude == nil)
        #expect(charter.distanceKm == nil)
        #expect(charter.captain.username == nil)
        #expect(charter.captain.profileImageThumbnailURL == nil)
        #expect(charter.hasLocation == false)
    }

    // MARK: - API Response Conversion: CharterAPIResponse → CharterModel

    @Test("CharterAPIResponse.toCharterModel - maps all fields including sync state")
    func testCharterAPIResponse_ToCharterModel() {
        let serverID = UUID()
        let now = Date()
        let response = CharterAPIResponse(
            id: serverID,
            userId: UUID(),
            name: "API Charter",
            boatName: "Blue Moon",
            locationText: "Corsica",
            startDate: now,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: now)!,
            latitude: 42.0,
            longitude: 9.0,
            locationPlaceId: "place_abc123",
            visibility: "community",
            createdAt: now,
            updatedAt: now
        )

        let model = response.toCharterModel()

        #expect(model.id == serverID)
        #expect(model.name == "API Charter")
        #expect(model.boatName == "Blue Moon")
        #expect(model.location == "Corsica")
        #expect(model.latitude == 42.0)
        #expect(model.longitude == 9.0)
        #expect(model.locationPlaceID == "place_abc123")
        #expect(model.visibility == .community)
        #expect(model.serverID == serverID)
        #expect(model.needsSync == false)
        #expect(model.checkInChecklistID == nil)
    }

    @Test("CharterAPIResponse.toCharterModel - unknown visibility defaults to private")
    func testCharterAPIResponse_UnknownVisibilityDefaultsToPrivate() {
        let response = CharterAPIResponse(
            id: UUID(),
            userId: UUID(),
            name: "Charter",
            boatName: nil,
            locationText: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            latitude: nil,
            longitude: nil,
            locationPlaceId: nil,
            visibility: "unknown_value",
            createdAt: Date(),
            updatedAt: Date()
        )

        let model = response.toCharterModel()
        #expect(model.visibility == .private)
    }

    // MARK: - UserBasicAPIResponse → CaptainBasicInfo

    @Test("UserBasicAPIResponse.toCaptainBasicInfo - valid thumbnail URL")
    func testUserBasicAPIResponse_ValidURL() {
        let response = UserBasicAPIResponse(
            id: UUID(),
            username: "captain",
            profileImageThumbnailUrl: "https://cdn.example.com/thumb.png"
        )
        let info = response.toCaptainBasicInfo()
        #expect(info.profileImageThumbnailURL?.absoluteString == "https://cdn.example.com/thumb.png")
    }

    @Test("UserBasicAPIResponse.toCaptainBasicInfo - invalid URL becomes nil")
    func testUserBasicAPIResponse_InvalidURL() {
        let response = UserBasicAPIResponse(
            id: UUID(),
            username: "captain",
            profileImageThumbnailUrl: "not a valid url $$"
        )
        let info = response.toCaptainBasicInfo()
        #expect(info.profileImageThumbnailURL == nil)
    }
}
