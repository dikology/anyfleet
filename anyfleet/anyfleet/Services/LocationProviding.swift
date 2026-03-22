import CoreLocation
import Foundation

// MARK: - LocationProviding

/// Supplies device location for “near me” discovery and similar features.
///
/// Production code uses ``SystemLocationProvider``. Unit tests inject a mock that avoids
/// `CLLocationManager` and Core Location side effects.
@MainActor
protocol LocationProviding: AnyObject {
    func requestWhenInUseAuthorization()
    /// Last known coordinate, if any (same idea as reading `CLLocationManager.location` once).
    var locationCoordinate: CLLocationCoordinate2D? { get }
}

// MARK: - System implementation

/// Default provider backed by `CLLocationManager`.
@MainActor
final class SystemLocationProvider: LocationProviding {
    private let manager = CLLocationManager()

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    var locationCoordinate: CLLocationCoordinate2D? {
        manager.location?.coordinate
    }
}
