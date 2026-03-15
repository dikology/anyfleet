import Foundation

// MARK: - Charter Discovery API Response

struct CharterDiscoveryAPIResponse: Codable {
    let items: [CharterWithUserAPIResponse]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Charter List API Response

struct CharterListAPIResponse: Codable {
    let items: [CharterAPIResponse]
    let total: Int
    let limit: Int
    let offset: Int
}
