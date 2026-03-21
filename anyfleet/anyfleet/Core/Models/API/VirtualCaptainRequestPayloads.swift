import Foundation

struct CreateVirtualCaptainRequest: Encodable {
    let displayName: String
    let socialLinks: [SocialLink]

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case socialLinks = "social_links"
    }
}

struct UpdateVirtualCaptainRequest: Encodable {
    let displayName: String?
    let socialLinks: [SocialLink]?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case socialLinks = "social_links"
    }
}
