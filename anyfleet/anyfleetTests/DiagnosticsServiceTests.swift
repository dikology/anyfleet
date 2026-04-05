//
//  DiagnosticsServiceTests.swift
//  anyfleetTests
//
//  Unit tests for DiagnosticsService breadcrumb recording API.
//  MetricKit payload delivery is not testable without a TestFlight/physical device,
//  so these tests focus on the breadcrumb API surface.
//

import Foundation
import Testing
@testable import anyfleet

@Suite("DiagnosticsService")
struct DiagnosticsServiceTests {

    @Test @MainActor
    func recordNavigationAddsBreadcrumb() async throws {
        let service = DiagnosticsService()
        service.recordNavigation("Tab: home")

        try await Task.sleep(for: .milliseconds(50))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].level == .navigation)
        #expect(snapshot[0].category == "Navigation")
        #expect(snapshot[0].message == "Tab: home")
    }

    @Test @MainActor
    func recordErrorAddsBreadcrumbWithErrorLevel() async throws {
        let service = DiagnosticsService()
        service.recordError("Sync failed", category: "Sync")

        try await Task.sleep(for: .milliseconds(50))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].level == .error)
        #expect(snapshot[0].category == "Sync")
        #expect(snapshot[0].message == "Sync failed")
    }

    @Test @MainActor
    func recordActionAddsBreadcrumbWithInfoLevel() async throws {
        let service = DiagnosticsService()
        service.recordAction("Create charter: My Voyage")

        try await Task.sleep(for: .milliseconds(50))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].level == .info)
        #expect(snapshot[0].category == "Action")
    }

    @Test @MainActor
    func recordWarningAddsBreadcrumbWithWarningLevel() async throws {
        let service = DiagnosticsService()
        service.recordWarning("Image upload slow", category: "Upload")

        try await Task.sleep(for: .milliseconds(50))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].level == .warning)
        #expect(snapshot[0].category == "Upload")
    }

    @Test @MainActor
    func multipleRecordsAccumulate() async throws {
        let service = DiagnosticsService()
        service.recordNavigation("Tab: library")
        service.recordAction("Create checklist")
        service.recordError("Save failed", category: "Store")

        try await Task.sleep(for: .milliseconds(100))

        let snapshot = await service.breadcrumbs.snapshot()
        #expect(snapshot.count == 3)
    }
}
