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
    }
}
