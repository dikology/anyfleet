import Foundation

/// Visibility level for a charter, controlling who can discover it.
enum CharterVisibility: String, Codable, CaseIterable, Sendable {
    case `private` = "private"
    case community = "community"
    case `public` = "public"
    case unknown = "unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = CharterVisibility(rawValue: raw) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .private: return L10n.Charter.Visibility.Private.name
        case .community: return L10n.Charter.Visibility.Community.name
        case .public: return L10n.Charter.Visibility.Public.name
        case .unknown: return "Unknown"
        }
    }

    var description: String {
        switch self {
        case .private: return L10n.Charter.Visibility.Private.description
        case .community: return L10n.Charter.Visibility.Community.description
        case .public: return L10n.Charter.Visibility.Public.description
        case .unknown: return "Visibility level not recognized"
        }
    }

    var systemImage: String {
        switch self {
        case .private: return "lock.fill"
        case .community: return "person.2.fill"
        case .public: return "globe"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Cases that can be selected in the charter editor (excludes unknown).
    static var selectableCases: [CharterVisibility] {
        allCases.filter { $0 != .unknown }
    }
}
