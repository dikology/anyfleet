//
//  DiagnosticsService.swift
//  anyfleet
//
//  Central orchestrator for crash reporting and performance diagnostics.
//  Subscribes to MetricKit to receive crash, hang, CPU, and metric payloads,
//  and maintains a breadcrumb ring buffer for post-crash context.
//

import Foundation
import MetricKit

@MainActor
final class DiagnosticsService: NSObject {
    let breadcrumbs = BreadcrumbStore()
    private let logger = AppLogger.diagnostics

    override init() {
        super.init()
        // MetricKit delivers no payloads in the simulator and can crash when
        // multiple subscribers are registered across tests. Skip registration
        // entirely; the breadcrumb API remains fully functional in all environments.
        #if !targetEnvironment(simulator)
        MXMetricManager.shared.add(self)
        logger.info("DiagnosticsService initialized, MetricKit subscriber registered")
        #else
        logger.info("DiagnosticsService initialized (MetricKit skipped in simulator)")
        #endif
    }

    deinit {
        #if !targetEnvironment(simulator)
        MXMetricManager.shared.remove(self)
        #endif
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
