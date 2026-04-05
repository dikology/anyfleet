//
//  BreadcrumbStoreTests.swift
//  anyfleetTests
//
//  Unit tests for BreadcrumbStore ring buffer behaviour.
//

import Foundation
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
        #expect(snapshot[0].level == .info)
    }

    @Test func respectsCapacityLimit() async {
        let store = BreadcrumbStore(capacity: 3)
        for i in 0..<10 {
            await store.add("event \(i)", category: "Test")
        }

        let snapshot = await store.snapshot()
        #expect(snapshot.count == 3)
        #expect(snapshot[0].message == "event 7")
        #expect(snapshot[1].message == "event 8")
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

    @Test func formattedEmptyStoreReturnsEmptyString() async {
        let store = BreadcrumbStore(capacity: 10)
        let output = await store.formatted()
        #expect(output.isEmpty)
    }

    @Test func addSetsTimestamp() async {
        let before = Date()
        let store = BreadcrumbStore(capacity: 5)
        await store.add("timestamped", category: "Test")
        let after = Date()

        let snapshot = await store.snapshot()
        #expect(snapshot[0].timestamp >= before)
        #expect(snapshot[0].timestamp <= after)
    }

    @Test func multipleEntriesFormattedAsSeparateLines() async {
        let store = BreadcrumbStore(capacity: 10)
        await store.add("first", category: "A")
        await store.add("second", category: "B")

        let output = await store.formatted()
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].contains("first"))
        #expect(lines[1].contains("second"))
    }
}
