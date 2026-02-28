import Foundation

/// Visibility level for a charter, controlling who can discover it.
enum CharterVisibility: String, Codable, CaseIterable, Sendable {
    case `private` = "private"
    case community = "community"
    case `public` = "public"

    var displayName: String {
        switch self {
        case .private: return L10n.Charter.Visibility.Private.name
        case .community: return L10n.Charter.Visibility.Community.name
        case .public: return L10n.Charter.Visibility.Public.name
        }
    }

    var description: String {
        switch self {
        case .private: return L10n.Charter.Visibility.Private.description
        case .community: return L10n.Charter.Visibility.Community.description
        case .public: return L10n.Charter.Visibility.Public.description
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
