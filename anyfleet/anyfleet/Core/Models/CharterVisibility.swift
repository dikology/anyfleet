import Foundation

/// Visibility level for a charter, controlling who can discover it.
enum CharterVisibility: String, Codable, CaseIterable, Sendable {
    case `private` = "private"
    case community = "community"
    case `public` = "public"

    var displayName: String {
        switch self {
        case .private: return "Private"
        case .community: return "Community"
        case .public: return "Public"
        }
    }

    var description: String {
        switch self {
        case .private: return "Only visible to you"
        case .community: return "Visible to community members"
        case .public: return "Visible to all sailors"
        }
    }

    var systemImage: String {
        switch self {
        case .private: return "lock.fill"
        case .community: return "person.2.fill"
        case .public: return "globe"
        }
    }
}
