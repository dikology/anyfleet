import Foundation
import Network

/// Supplies the current network path state for sync and UI. Main-actor isolated for use with `@Observable` and `SyncQueueService`.
@MainActor
protocol NetworkReachabilityProviding: AnyObject {
    /// `true` when `NWPath` status is `.satisfied` (device has a viable route to the network).
    var isPathSatisfied: Bool { get }
}

/// Test / preview stand-in that never blocks sync on reachability.
@MainActor
final class AlwaysOnlineReachability: NetworkReachabilityProviding {
    static let shared = AlwaysOnlineReachability()

    var isPathSatisfied: Bool { true }

    private init() {}
}

/// Observes the system network path with `NWPathMonitor` and updates ``isPathSatisfied`` on the main actor.
@MainActor
@Observable
final class NWPathReachabilityMonitor: NetworkReachabilityProviding {
    private(set) var isPathSatisfied: Bool = false

    /// Called when the path transitions from unavailable to satisfied (not on the first evaluation).
    var onPathBecameSatisfied: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.anyfleet.network.path")
    private var lastKnownSatisfied: Bool?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func apply(_ path: NWPath) {
        let satisfied = path.status == .satisfied
        if let previous = lastKnownSatisfied, !previous, satisfied {
            onPathBecameSatisfied?()
        }
        lastKnownSatisfied = satisfied
        isPathSatisfied = satisfied
    }
}
