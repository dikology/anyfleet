import Foundation

// MARK: - Charter Create Request

struct CharterCreateRequest: Encodable {
    let name: String
    let boatName: String?
    let locationText: String?
    let startDate: Date
    let endDate: Date
    let visibility: String
    let latitude: Double?
    let longitude: Double?
    let locationPlaceId: String?
    let onBehalfOfVirtualCaptainId: UUID?

    init(
        name: String,
        boatName: String?,
        locationText: String?,
        startDate: Date,
        endDate: Date,
        visibility: String,
        latitude: Double?,
        longitude: Double?,
        locationPlaceId: String?,
        onBehalfOfVirtualCaptainId: UUID? = nil
    ) {
        self.name = name
        self.boatName = boatName
        self.locationText = locationText
        self.startDate = startDate
        self.endDate = endDate
        self.visibility = visibility
        self.latitude = latitude
        self.longitude = longitude
        self.locationPlaceId = locationPlaceId
        self.onBehalfOfVirtualCaptainId = onBehalfOfVirtualCaptainId
    }

    enum CodingKeys: String, CodingKey {
        case name
        case boatName = "boat_name"
        case locationText = "location_text"
        case startDate = "start_date"
        case endDate = "end_date"
        case visibility
        case latitude
        case longitude
        case locationPlaceId = "location_place_id"
        case onBehalfOfVirtualCaptainId = "on_behalf_of_virtual_captain_id"
    }
}

// MARK: - Charter Update Request

struct CharterUpdateRequest: Encodable {
    let name: String?
    let boatName: String?
    let locationText: String?
    let startDate: Date?
    let endDate: Date?
    let visibility: String?
    let latitude: Double?
    let longitude: Double?
    let locationPlaceId: String?
    /// When `shouldEncodeOnBehalfOfVirtualCaptainId` is true, encoded as UUID or explicit JSON `null`.
    let onBehalfOfVirtualCaptainId: UUID?
    let shouldEncodeOnBehalfOfVirtualCaptainId: Bool

    init(
        name: String?,
        boatName: String?,
        locationText: String?,
        startDate: Date?,
        endDate: Date?,
        visibility: String?,
        latitude: Double?,
        longitude: Double?,
        locationPlaceId: String?,
        onBehalfOfVirtualCaptainId: UUID? = nil,
        shouldEncodeOnBehalfOfVirtualCaptainId: Bool = false
    ) {
        self.name = name
        self.boatName = boatName
        self.locationText = locationText
        self.startDate = startDate
        self.endDate = endDate
        self.visibility = visibility
        self.latitude = latitude
        self.longitude = longitude
        self.locationPlaceId = locationPlaceId
        self.onBehalfOfVirtualCaptainId = onBehalfOfVirtualCaptainId
        self.shouldEncodeOnBehalfOfVirtualCaptainId = shouldEncodeOnBehalfOfVirtualCaptainId
    }

    enum CodingKeys: String, CodingKey {
        case name
        case boatName = "boat_name"
        case locationText = "location_text"
        case startDate = "start_date"
        case endDate = "end_date"
        case visibility
        case latitude
        case longitude
        case locationPlaceId = "location_place_id"
        case onBehalfOfVirtualCaptainId = "on_behalf_of_virtual_captain_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(boatName, forKey: .boatName)
        try c.encodeIfPresent(locationText, forKey: .locationText)
        try c.encodeIfPresent(startDate, forKey: .startDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encodeIfPresent(visibility, forKey: .visibility)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encodeIfPresent(locationPlaceId, forKey: .locationPlaceId)
        if shouldEncodeOnBehalfOfVirtualCaptainId {
            if let id = onBehalfOfVirtualCaptainId {
                try c.encode(id, forKey: .onBehalfOfVirtualCaptainId)
            } else {
                try c.encodeNil(forKey: .onBehalfOfVirtualCaptainId)
            }
        }
    }
}
