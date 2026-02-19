import UIKit
import Combine

/// Manages background sync operations independently of navigation.
///
/// Extracted from `AppCoordinator` to satisfy the Single Responsibility Principle.
/// This class owns the sync timer lifecycle, responds to app lifecycle events, and
/// implements adaptive interval behaviour (slows down when idle to save battery).
///
/// See `refactoring-jan.md` Section 1 for the full rationale.
@MainActor
@Observable
final class SyncCoordinator {

    // MARK: - Configuration

    /// Interval when there are pending operations.
    var activeInterval: TimeInterval = 60.0

    /// Interval after several consecutive empty syncs (battery optimisation).
    var idleInterval: TimeInterval = 300.0

    var isEnabled: Bool = true {
        didSet { isEnabled ? startIfNeeded() : stop() }
    }

    // MARK: - State

    private(set) var isSyncing = false

    // MARK: - Private

    private let contentSyncService: ContentSyncService
    private var charterSyncService: CharterSyncService?
    // nonisolated(unsafe) allows deinit (which is nonisolated) to invalidate the timer.
    private nonisolated(unsafe) var syncTimer: Timer?
    private var currentInterval: TimeInterval
    private var consecutiveEmptySyncs = 0
    private let maxEmptySyncsBeforeIdle = 3
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(contentSyncService: ContentSyncService, charterSyncService: CharterSyncService? = nil) {
        self.contentSyncService = contentSyncService
        self.charterSyncService = charterSyncService
        self.currentInterval = 60.0 // matches activeInterval default
        observeAppLifecycle()
        startIfNeeded()
    }

    // MARK: - Public

    /// Trigger an immediate sync outside the normal timer cadence.
    func triggerImmediateSync() {
        Task { await performSync() }
    }

    // MARK: - Timer Management

    private func startIfNeeded() {
        guard isEnabled, syncTimer == nil else { return }
        syncTimer = makeTimer(interval: currentInterval)
        AppLogger.sync.info("SyncCoordinator started (interval: \(currentInterval)s)")
    }

    private func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        AppLogger.sync.info("SyncCoordinator stopped")
    }

    private func restartWithInterval(_ interval: TimeInterval) {
        guard interval != currentInterval else { return }
        currentInterval = interval
        stop()
        startIfNeeded()
        AppLogger.sync.info("SyncCoordinator interval → \(interval)s")
    }

    private func makeTimer(interval: TimeInterval) -> Timer {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performSync()
            }
        }
    }

    // MARK: - Sync

    private func performSync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        AppLogger.sync.debug("SyncCoordinator: performing sync cycle")

        // Sync content queue
        let summary = await contentSyncService.syncPending()

        // Adaptive interval: slow down if nothing was synced recently
        if summary.succeeded == 0 && summary.failed == 0 {
            consecutiveEmptySyncs += 1
            if consecutiveEmptySyncs >= maxEmptySyncsBeforeIdle {
                restartWithInterval(idleInterval)
            }
        } else {
            if consecutiveEmptySyncs > 0 {
                consecutiveEmptySyncs = 0
                restartWithInterval(activeInterval)
            }
        }

        // Charter sync (push pending visibility-changed charters)
        await charterSyncService?.pushPendingCharters()
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.stop() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.performSync()
                }
                self?.startIfNeeded()
            }
            .store(in: &cancellables)
    }

    deinit {
        syncTimer?.invalidate()
    }
}
