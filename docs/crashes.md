# Crash Reporting & Diagnostics — Implementation Plan

## 1. Problem

The app has zero post-launch visibility into crashes, hangs, or performance regressions. The only feedback channel is TestFlight's limited crash organizer and manual user reports. Day-1 crashes with no telemetry lead to bad ratings and an inability to prioritize fixes.

The codebase already has a solid `AppLogger` infrastructure (9 categories, `os.Logger`-based, file/line/function context) and a structured error taxonomy (`AppError`, `NetworkError`, `AuthError`, `LibraryError`). The crash reporting strategy should build on these foundations rather than replace them.

## 2. Technology Decision

### Why MetricKit (not Sentry/Crashlytics)

| Factor | MetricKit | Sentry / Crashlytics |
|--------|-----------|----------------------|
| **Dependencies** | Zero — Apple framework, ships with iOS | Adds SPM package, 2-5 MB binary size |
| **Current dep count** | 1 (GRDB only) | Would become 2+ |
| **Privacy** | No data leaves device beyond Apple's pipeline; no App Privacy declaration changes | Requires declaring crash data collection in App Store Connect nutrition label |
| **iOS 18.0 target** | Full API surface available (MXMetricManager since iOS 13, MXCrashDiagnostic since iOS 14, MXAppLaunchDiagnostic since iOS 16) | Full support |
| **Symbolication** | Automatic via Xcode Organizer when dSYMs are uploaded | Requires SDK-side upload or manual config |
| **Setup effort** | ~2 hours | ~4 hours (account setup, SDK init, dSYM upload config) |
| **Real-time alerts** | No — 24h batched delivery | Yes — near real-time |
| **Breadcrumbs** | Not built-in (we add lightweight local breadcrumbs) | Built-in |
| **Cost** | Free | Free tier sufficient, but vendor lock-in |

**Recommendation:** Start with **MetricKit + local breadcrumb ring buffer + OSLogStore integration**. This gives crash diagnostics, hang detection, and performance metrics with zero external dependencies. If real-time alerting or server-side aggregation becomes necessary post-launch, Sentry can be added as a layer on top without architectural changes.

## 3. Architecture Overview

```
┌──────────────────────────────────────────────────────┐
│                    anyfleetApp                        │
│                        │                             │
│                        ▼                             │
│            ┌─ DiagnosticsService ─┐                  │
│            │  (MXMetricManager    │                  │
│            │   subscriber)        │                  │
│            └───────┬──────────────┘                  │
│                    │                                 │
│        ┌───────────┼───────────┐                     │
│        ▼           ▼           ▼                     │
│  MXCrash     MXHang      MXMetric                   │
│  Diagnostic  Diagnostic  Payload                     │
│        │           │           │                     │
│        └───────────┼───────────┘                     │
│                    ▼                                 │
│           BreadcrumbStore                            │
│        (ring buffer, 50 entries)                     │
│                    │                                 │
│                    ▼                                 │
│         AppLogger (existing)                         │
│         + .diagnostics category                      │
│                    │                                 │
│                    ▼                                 │
│       On-device log file (crashes/)                  │
│       + Xcode Organizer (via Apple)                  │
└──────────────────────────────────────────────────────┘
```

## 4. New Files

```
anyfleet/
├── Core/
│   ├── Diagnostics/
│   │   ├── DiagnosticsService.swift      # MXMetricManagerSubscriber + orchestration
│   │   ├── BreadcrumbStore.swift         # Thread-safe ring buffer for recent events
│   │   └── DiagnosticPayloadLogger.swift # Formats MX payloads for on-device persistence
│   └── Utilities/
│       └── Logger.swift                  # Add AppLogger.diagnostics category
```

## 5. Modified Files

| File | Change |
|------|--------|
| `Core/Utilities/Logger.swift` | Add `static let diagnostics` logger category |
| `App/AppDependencies.swift` | Create and hold `DiagnosticsService`; expose for injection |
| `anyfleetApp.swift` | Start diagnostics service early in launch sequence |
| `Core/Errors/AppError.swift` | Add breadcrumb recording in `toAppError()` for non-fatal tracking |

## 6. Implementation

### 6.1 — AppLogger Extension

```swift
// Core/Utilities/Logger.swift — add to AppLogger enum

static let diagnostics = Logger(subsystem: "com.anyfleet.app", category: "Diagnostics")
```

### 6.2 — BreadcrumbStore

A lightweight, thread-safe ring buffer that captures the last N significant events. When a crash diagnostic arrives, the breadcrumb trail provides context about what the user was doing.

```swift
// Core/Diagnostics/BreadcrumbStore.swift

import Foundation
import OSLog

actor BreadcrumbStore {
    struct Breadcrumb: Sendable {
        let timestamp: Date
        let category: String
        let message: String
        let level: Level

        enum Level: String, Sendable {
            case info, warning, error, navigation
        }
    }

    private var buffer: [Breadcrumb] = []
    private let capacity: Int

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    func add(_ message: String, category: String, level: Breadcrumb.Level = .info) {
        let crumb = Breadcrumb(
            timestamp: Date(),
            category: category,
            message: message,
            level: level
        )
        buffer.append(crumb)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
    }

    func snapshot() -> [Breadcrumb] {
        buffer
    }

    func formatted() -> String {
        buffer.map { crumb in
            let ts = ISO8601DateFormatter().string(from: crumb.timestamp)
            return "[\(ts)] [\(crumb.level.rawValue.uppercased())] [\(crumb.category)] \(crumb.message)"
        }.joined(separator: "\n")
    }

    func clear() {
        buffer.removeAll()
    }
}
```

### 6.3 — DiagnosticPayloadLogger

Persists crash/hang diagnostics to the app's documents directory so they survive app restarts and can be attached to support requests.

```swift
// Core/Diagnostics/DiagnosticPayloadLogger.swift

import Foundation
import MetricKit
import OSLog

enum DiagnosticPayloadLogger {
    private static let logger = AppLogger.diagnostics
    private static let directoryName = "diagnostics"
    private static let maxFiles = 20

    static func persist(
        crashes: [MXCrashDiagnostic],
        hangs: [MXHangDiagnostic],
        breadcrumbs: String
    ) {
        let dir = diagnosticsDirectory()

        for (index, crash) in crashes.enumerated() {
            let filename = "crash_\(timestampString())_\(index).txt"
            let content = formatCrash(crash, breadcrumbs: breadcrumbs)
            write(content, to: dir.appendingPathComponent(filename))
            logger.error("Crash diagnostic received: \(crash.terminationReason ?? "unknown")")
        }

        for (index, hang) in hangs.enumerated() {
            let filename = "hang_\(timestampString())_\(index).txt"
            let content = formatHang(hang, breadcrumbs: breadcrumbs)
            write(content, to: dir.appendingPathComponent(filename))
            logger.warning("Hang diagnostic received: \(hang.hangDuration.formatted())s")
        }

        pruneOldFiles(in: dir)
    }

    static func persistMetrics(_ payloads: [MXMetricPayload]) {
        let dir = diagnosticsDirectory()

        for payload in payloads {
            let filename = "metrics_\(timestampString()).json"
            if let data = payload.jsonRepresentation(),
               let json = String(data: data, encoding: .utf8) {
                write(json, to: dir.appendingPathComponent(filename))
                logger.info("Metric payload persisted")
            }
        }

        pruneOldFiles(in: dir)
    }

    // MARK: - Formatting

    private static func formatCrash(
        _ crash: MXCrashDiagnostic,
        breadcrumbs: String
    ) -> String {
        var lines: [String] = []
        lines.append("=== CRASH DIAGNOSTIC ===")
        lines.append("Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Termination Reason: \(crash.terminationReason ?? "unknown")")
        lines.append("Signal: \(crash.signal?.description ?? "unknown")")
        lines.append("Exception Type: \(crash.exceptionType?.description ?? "unknown")")
        lines.append("Exception Code: \(crash.exceptionCode?.description ?? "unknown")")
        lines.append("Virtual Memory Region Info: \(crash.virtualMemoryRegionInfo ?? "N/A")")
        lines.append("")
        lines.append("--- Call Stack ---")
        if let tree = crash.callStackTree {
            if let data = tree.jsonRepresentation(),
               let json = String(data: data, encoding: .utf8) {
                lines.append(json)
            }
        }
        lines.append("")
        lines.append("--- Breadcrumbs (last 50 events) ---")
        lines.append(breadcrumbs.isEmpty ? "(none)" : breadcrumbs)
        return lines.joined(separator: "\n")
    }

    private static func formatHang(
        _ hang: MXHangDiagnostic,
        breadcrumbs: String
    ) -> String {
        var lines: [String] = []
        lines.append("=== HANG DIAGNOSTIC ===")
        lines.append("Date: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("Duration: \(hang.hangDuration.formatted())s")
        lines.append("")
        lines.append("--- Call Stack ---")
        if let tree = hang.callStackTree {
            if let data = tree.jsonRepresentation(),
               let json = String(data: data, encoding: .utf8) {
                lines.append(json)
            }
        }
        lines.append("")
        lines.append("--- Breadcrumbs ---")
        lines.append(breadcrumbs.isEmpty ? "(none)" : breadcrumbs)
        return lines.joined(separator: "\n")
    }

    // MARK: - File Management

    private static func diagnosticsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(directoryName)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func write(_ content: String, to url: URL) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to write diagnostic file", error: error)
        }
    }

    private static func timestampString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }

    private static func pruneOldFiles(in directory: URL) {
        guard let files = try? FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            .sorted(by: {
                let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 < d2
            })
        else { return }

        if files.count > maxFiles {
            for file in files.prefix(files.count - maxFiles) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
```

### 6.4 — DiagnosticsService

The central orchestrator. Subscribes to MetricKit, manages breadcrumbs, and coordinates payload persistence.

```swift
// Core/Diagnostics/DiagnosticsService.swift

import Foundation
import MetricKit
import OSLog

@MainActor
final class DiagnosticsService: NSObject {
    let breadcrumbs = BreadcrumbStore()
    private let logger = AppLogger.diagnostics

    override init() {
        super.init()
        MXMetricManager.shared.add(self)
        logger.info("DiagnosticsService initialized, MetricKit subscriber registered")
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - Breadcrumb API

    /// Record a navigation event (tab switch, screen push, sheet present).
    nonisolated func recordNavigation(_ destination: String) {
        Task { await breadcrumbs.add(destination, category: "Navigation", level: .navigation) }
    }

    /// Record a significant user action (create charter, publish content, etc.).
    nonisolated func recordAction(_ action: String) {
        Task { await breadcrumbs.add(action, category: "Action", level: .info) }
    }

    /// Record a non-fatal error for breadcrumb trail context.
    nonisolated func recordError(_ message: String, category: String = "Error") {
        Task { await breadcrumbs.add(message, category: category, level: .error) }
    }

    /// Record a warning-level event.
    nonisolated func recordWarning(_ message: String, category: String = "Warning") {
        Task { await breadcrumbs.add(message, category: category, level: .warning) }
    }
}

// MARK: - MXMetricManagerSubscriber

extension DiagnosticsService: MXMetricManagerSubscriber {
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        Task { @MainActor in
            logger.info("Received \(payloads.count) metric payload(s)")
            DiagnosticPayloadLogger.persistMetrics(payloads)
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        Task { @MainActor in
            logger.info("Received \(payloads.count) diagnostic payload(s)")

            let trail = await breadcrumbs.formatted()

            for payload in payloads {
                let crashes = payload.crashDiagnostics ?? []
                let hangs = payload.hangDiagnostics ?? []

                if !crashes.isEmpty || !hangs.isEmpty {
                    logger.error(
                        "Diagnostic payload: \(crashes.count) crash(es), \(hangs.count) hang(s)"
                    )
                    DiagnosticPayloadLogger.persist(
                        crashes: crashes,
                        hangs: hangs,
                        breadcrumbs: trail
                    )
                }

                if let cpuExceptions = payload.cpuExceptionDiagnostics, !cpuExceptions.isEmpty {
                    logger.warning("CPU exception diagnostics: \(cpuExceptions.count)")
                }

                if let diskWrites = payload.diskWriteExceptionDiagnostics, !diskWrites.isEmpty {
                    logger.warning("Disk write exception diagnostics: \(diskWrites.count)")
                }

                if let launches = payload.appLaunchDiagnostics, !launches.isEmpty {
                    logger.info("App launch diagnostics: \(launches.count)")
                }
            }
        }
    }
}
```

### 6.5 — AppDependencies Integration

```swift
// App/AppDependencies.swift — additions

@MainActor
@Observable
final class AppDependencies {
    // ... existing properties ...
    let diagnosticsService: DiagnosticsService

    init() {
        // Create early — before any service that might crash during init
        self.diagnosticsService = DiagnosticsService()

        // ... existing init sequence (database, repository, auth, etc.) ...
    }
}
```

### 6.6 — anyfleetApp Launch Wiring

```swift
// anyfleetApp.swift — no changes needed beyond AppDependencies

// DiagnosticsService is created inside AppDependencies.init(), which runs
// as part of `AppDependencies.shared`. The MXMetricManager subscriber is
// registered before any view renders.
//
// For breadcrumbs to flow, pass diagnosticsService to the coordinator or
// make it accessible via the environment (see section 7.2).
```

### 6.7 — Error Taxonomy Integration

Add breadcrumb recording to the existing `toAppError()` conversion so every error that reaches the UI layer also leaves a breadcrumb trail entry.

```swift
// Core/Errors/AppError.swift — extend the conversion helper

extension Error {
    func toAppError(
        diagnostics: DiagnosticsService? = nil
    ) -> AppError {
        let appError: AppError

        if let authError = self as? AuthError {
            appError = .authenticationError(authError)
        } else if let libraryError = self as? LibraryError {
            appError = .unknown(libraryError)
        } else {
            let nsError = self as NSError
            if nsError.domain == NSURLErrorDomain {
                let networkError: NetworkError
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                    networkError = .offline
                case NSURLErrorTimedOut:
                    networkError = .timedOut
                case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                    networkError = .connectionRefused
                case NSURLErrorDNSLookupFailed:
                    networkError = .unreachableHost
                default:
                    networkError = .unknown(self)
                }
                appError = .networkError(networkError)
            } else {
                appError = .unknown(self)
            }
        }

        diagnostics?.recordError(
            "\(type(of: self)): \(self.localizedDescription)",
            category: "AppError"
        )

        return appError
    }
}
```

## 7. Breadcrumb Integration Points

### 7.1 — Navigation Breadcrumbs

The coordinator is the single source of truth for all navigation. Add breadcrumb recording to tab switches and route pushes.

```swift
// App/AppModel.swift — inside AppCoordinator

// In the selectedTab didSet (or observation):
diagnosticsService.recordNavigation("Tab: \(newTab)")

// In push(_:tab:):
diagnosticsService.recordNavigation("Push: \(route)")
```

### 7.2 — User Action Breadcrumbs

Sprinkle breadcrumbs at high-value action points across ViewModels. These are not exhaustive — focus on actions that would provide context for a crash.

| Location | Breadcrumb |
|----------|------------|
| `CharterStore.createCharter()` | `"Create charter: \(name)"` |
| `CharterStore.deleteCharter()` | `"Delete charter: \(id)"` |
| `LibraryStore.createContent()` | `"Create library content: \(type)"` |
| `LibraryStore.triggerPublishUpdate()` | `"Publish update: \(contentID)"` |
| `SyncQueueService.processQueue()` | `"Sync queue: \(pendingCount) ops"` |
| `AuthService.signIn()` | `"Sign in attempt"` |
| `AuthService.signOut()` | `"Sign out"` |
| `ProfileViewModel.deleteAccount()` | `"Account deletion initiated"` |

### 7.3 — Error Breadcrumbs

The existing `Logger.failOperation` and `Logger.error` calls already log to `os_log`. The breadcrumb store captures a parallel trail specifically for crash context. Add breadcrumb recording in catch blocks that currently only log:

```swift
// Pattern — in any catch block that logs an error:

catch {
    AppLogger.store.failOperation("Load library", error: error)
    diagnosticsService.recordError("Load library failed: \(error)", category: "Store")
    // ... existing error handling ...
}
```

This is **additive** — existing `os_log` calls remain unchanged. Breadcrumbs provide a compact, crash-scoped trail; `os_log` provides full system-wide logs.

## 8. What MetricKit Provides Out of the Box

Once `DiagnosticsService` is registered as an `MXMetricManagerSubscriber`, the system automatically delivers:

| Payload Type | Content | Delivery |
|-------------|---------|----------|
| `MXCrashDiagnostic` | Crash call stacks, termination reason, signal, exception type/code | Within 24h of crash |
| `MXHangDiagnostic` | Main-thread hang call stacks, duration | Within 24h |
| `MXCPUExceptionDiagnostic` | CPU spike call stacks, total CPU time | Within 24h |
| `MXDiskWriteExceptionDiagnostic` | Excessive disk write call stacks | Within 24h |
| `MXAppLaunchDiagnostic` | Slow launch call stacks (iOS 16+) | Within 24h |
| `MXMetricPayload` | Aggregated performance metrics: launch time, hang rate, memory, cellular/WiFi data, animation hitches, battery usage | ~24h batched |

**Symbolication:** Call stack trees from MetricKit are symbolicated automatically in Xcode Organizer when dSYMs are uploaded via Xcode's archive-and-upload flow (which happens automatically with App Store / TestFlight distribution).

## 9. Xcode Organizer Integration

MetricKit diagnostics also appear in **Xcode Organizer → Crashes** and **Hangs** tabs once the app is distributed via TestFlight or App Store. This provides:

- Aggregated crash counts by OS version and device
- Symbolicated stack traces
- Trend lines over app versions

No additional code is needed — this is Apple's backend processing the same data that MetricKit delivers to the subscriber.

## 10. Testing Plan

### 10.1 — Unit Tests

```swift
// anyfleetTests/BreadcrumbStoreTests.swift

import Testing
@testable import anyfleet

@Suite("BreadcrumbStore")
struct BreadcrumbStoreTests {
    @Test func addsAndRetrievesBreadcrumbs() async {
        let store = BreadcrumbStore(capacity: 5)
        await store.add("test event", category: "Test", level: .info)

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].message == "test event")
        #expect(snapshot[0].category == "Test")
    }

    @Test func respectsCapacityLimit() async {
        let store = BreadcrumbStore(capacity: 3)
        for i in 0..<10 {
            await store.add("event \(i)", category: "Test")
        }

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 3)
        #expect(snapshot[0].message == "event 7")
        #expect(snapshot[2].message == "event 9")
    }

    @Test func clearRemovesAllEntries() async {
        let store = BreadcrumbStore(capacity: 10)
        await store.add("event", category: "Test")
        await store.clear()

        let snapshot = await store.snapshot()
        #expect(snapshot.isEmpty)
    }

    @Test func formattedOutputIncludesAllFields() async {
        let store = BreadcrumbStore(capacity: 10)
        await store.add("navigation to Home", category: "Navigation", level: .navigation)

        let output = await store.formatted()
        #expect(output.contains("[NAVIGATION]"))
        #expect(output.contains("[Navigation]"))
        #expect(output.contains("navigation to Home"))
    }
}
```

### 10.2 — DiagnosticsService Tests

```swift
// anyfleetTests/DiagnosticsServiceTests.swift

import Testing
@testable import anyfleet

@Suite("DiagnosticsService")
struct DiagnosticsServiceTests {
    @Test @MainActor
    func recordNavigationAddsBreadcrumb() async {
        let service = DiagnosticsService()
        service.recordNavigation("Tab: home")

        // Allow async Task to complete
        try? await Task.sleep(for: .milliseconds(50))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].level == .navigation)
    }

    @Test @MainActor
    func recordErrorAddsBreadcrumbWithErrorLevel() async {
        let service = DiagnosticsService()
        service.recordError("Sync failed", category: "Sync")

        try? await Task.sleep(for: .milliseconds(50))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].level == .error)
        #expect(snapshot[0].category == "Sync")
    }
}
```

### 10.3 — Manual Verification

MetricKit does not deliver payloads in the simulator or on-demand. Manual testing requires:

1. **TestFlight build** — install on a physical device.
2. **Trigger a deliberate crash** (debug-only `fatalError` behind a hidden gesture) or wait for organic crashes.
3. **Wait 24 hours** — check that diagnostic files appear in the app's `Documents/diagnostics/` directory.
4. **Xcode Organizer** — verify crash appears in the Crashes tab after TestFlight processes it.

For development, add a `#if DEBUG` diagnostic viewer (see section 12).

## 11. Effort Estimate

| Task | Effort |
|------|--------|
| `BreadcrumbStore.swift` | 30 min |
| `DiagnosticPayloadLogger.swift` | 45 min |
| `DiagnosticsService.swift` | 30 min |
| `AppLogger.diagnostics` category | 5 min |
| `AppDependencies` integration | 15 min |
| Breadcrumb integration (coordinator + key ViewModels) | 45 min |
| `toAppError()` breadcrumb extension | 15 min |
| Unit tests | 30 min |
| Manual TestFlight verification | 1 hour (+ 24h wait) |
| **Total** | **~4 hours** (code) + 24h verification wait |

## 12. Future Enhancements

| Enhancement | When | Description |
|-------------|------|-------------|
| **Debug diagnostic viewer** | v1.0 (dev only) | `#if DEBUG` screen in Profile → "Diagnostics" that lists files from `Documents/diagnostics/`, shows breadcrumb trail, and allows sharing via `ShareLink`. |
| **Sentry integration** | Post-launch if needed | If 24h delivery lag is unacceptable, add Sentry as a thin transport layer. `DiagnosticsService` becomes the single entry point — Sentry receives the same breadcrumbs and crash context. No architecture changes needed. |
| **Non-fatal error tracking** | v1.1 | Extend `DiagnosticsService` with a `recordNonFatal(_ error: Error, context: [String: String])` method that persists structured error reports (not just breadcrumbs). Useful for tracking silent `try?` failures (B5 in refactoring doc). |
| **App launch performance** | v1.1 | Parse `MXAppLaunchDiagnostic` and `MXMetricPayload.applicationLaunchMetrics` to track cold/warm launch regression across versions. |
| **Hang threshold tuning** | v1.2 | MetricKit reports hangs > 1s by default. Monitor hang diagnostic volume and adjust breadcrumb density around known hot paths (map clustering, library load). |
| **Server-side aggregation** | v2.0 | If the app grows to thousands of users, build a lightweight endpoint that accepts diagnostic payloads (opt-in) for aggregated dashboards. Until then, Xcode Organizer is sufficient. |

## 13. Privacy Considerations

- **MetricKit data** stays within Apple's ecosystem. Crash diagnostics are delivered on-device to the subscriber and to Xcode Organizer via Apple's servers. No third-party data sharing.
- **Breadcrumbs** are stored on-device only in `Documents/diagnostics/`. They contain navigation paths and action descriptions — no PII (user names, emails, tokens). Error messages may contain UUIDs (charter/content IDs) which are not PII.
- **App Privacy declaration** (S8 in refactoring doc): MetricKit does not require declaring additional data collection categories. If the debug diagnostic viewer adds a "Share" feature, disclose "Diagnostics" under "App Functionality" → "Other Diagnostic Data" as data not linked to the user.
- **No opt-out needed** — MetricKit diagnostics are governed by the user's existing "Share Analytics" iOS setting. The app does not need its own toggle.
