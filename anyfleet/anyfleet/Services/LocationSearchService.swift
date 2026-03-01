import MapKit

// MARK: - Protocol

protocol LocationSearchService: Sendable {
    /// Returns up to `limit` place suggestions for the given query string.
    func search(query: String, limit: Int) async throws -> [PlaceResult]
}

// MARK: - MapKit implementation

final class MKLocationSearchService: LocationSearchService {
    func search(query: String, limit: Int = 5) async throws -> [PlaceResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        // Bias toward nautical regions; not a hard filter so valid results are never dropped
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.0, longitude: 20.0),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.prefix(limit).map { item in
            let id = item.identifier?.rawValue
                ?? "\(item.placemark.coordinate.latitude),\(item.placemark.coordinate.longitude)"
            return PlaceResult(
                id: id,
                name: item.name ?? item.placemark.locality ?? "Unknown",
                subtitle: [
                    item.placemark.administrativeArea,
                    item.placemark.country
                ].compactMap { $0 }.joined(separator: ", "),
                coordinate: item.placemark.coordinate,
                countryCode: item.placemark.isoCountryCode
            )
        }
    }
}

// MARK: - Test double

/// Stub for unit tests — returns a fixed list without hitting MapKit.
final class MockLocationSearchService: LocationSearchService {
    var stubbedResults: [PlaceResult] = []
    var stubbedError: Error?

    func search(query: String, limit: Int) async throws -> [PlaceResult] {
        if let error = stubbedError { throw error }
        return Array(stubbedResults.prefix(limit))
    }
}
