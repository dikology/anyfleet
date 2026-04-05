//
//  BreadcrumbStore.swift
//  anyfleet
//
//  Thread-safe ring buffer capturing the last N significant app events.
//  Attached to crash/hang diagnostics to provide context about user actions
//  leading up to the incident.
//

import Foundation

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
        let formatter = ISO8601DateFormatter()
        return buffer.map { crumb in
            let ts = formatter.string(from: crumb.timestamp)
            return "[\(ts)] [\(crumb.level.rawValue.uppercased())] [\(crumb.category)] \(crumb.message)"
        }.joined(separator: "\n")
    }

    func clear() {
        buffer.removeAll()
    }
}
