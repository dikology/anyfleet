//
//  DiagnosticPayloadLogger.swift
//  anyfleet
//
//  Persists MetricKit crash and hang diagnostics to the app's documents directory
//  so they survive restarts and can be attached to support requests.
//

import Foundation
import MetricKit

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
            logger.warning("Hang diagnostic received: \(hang.hangDuration.formatted())")
        }

        pruneOldFiles(in: dir)
    }

    static func persistMetrics(_ payloads: [MXMetricPayload]) {
        let dir = diagnosticsDirectory()

        for payload in payloads {
            let filename = "metrics_\(timestampString()).json"
            let data = payload.jsonRepresentation()
            if let json = String(data: data, encoding: .utf8) {
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
        if let json = String(data: crash.callStackTree.jsonRepresentation(), encoding: .utf8) {
            lines.append(json)
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
        lines.append("Duration: \(hang.hangDuration.formatted())")
        lines.append("")
        lines.append("--- Call Stack ---")
        if let json = String(data: hang.callStackTree.jsonRepresentation(), encoding: .utf8) {
            lines.append(json)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
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
