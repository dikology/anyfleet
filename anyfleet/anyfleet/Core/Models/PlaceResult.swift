import CoreLocation

/// A geocoded place returned from a location search.
/// Immutable, `Sendable`, and independent of MapKit types.
struct PlaceResult: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let countryCode: String?

    // CLLocationCoordinate2D is not Hashable — hash on id only
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PlaceResult, rhs: PlaceResult) -> Bool {
        lhs.id == rhs.id
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
