//
//  CharterDiscoveryFiltersTests.swift
//  anyfleetTests
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterDiscoveryFilters Tests")
struct CharterDiscoveryFiltersTests {

    @Test("Default window matches twelve-month discovery track")
    func testDefaultWindow_IsDefaultDiscovery() {
        let f = CharterDiscoveryFilters()
        #expect(f.isDefaultDiscoveryWindow())
        #expect(f.activeFilterCount == 0)
    }

    @Test("Non-default end date increases active filter count")
    func testActiveFilterCount_DateChange() {
        var f = CharterDiscoveryFilters()
        f.windowEnd = f.windowStart.addingTimeInterval(86400 * 3)
        #expect(f.activeFilterCount >= 1)
        #expect(!f.isDefaultDiscoveryWindow())
    }

    @Test("RangeSlider.clamp enforces minimum span")
    func testRangeSliderClamp() {
        var l = 0.92
        var u = 0.93
        RangeSlider.clamp(lower: &l, upper: &u, minSpan: 0.05)
        #expect(u >= l + 0.05 - 0.0001)
        #expect(l >= 0 && u <= 1)
    }

    @Test("Normalized map range round-trips for a fixed reference date")
    func testNormalizedMapRoundTrip() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let ref = Date(timeIntervalSince1970: 1_720_000_000)

        var f = CharterDiscoveryFilters()
        f.setMapWindowFromNormalized(lower: 0.2, upper: 0.7, reference: ref, calendar: cal)
        let p = f.normalizedMapRange(reference: ref, calendar: cal)

        #expect(abs(p.lower - 0.2) < 0.03)
        #expect(abs(p.upper - 0.7) < 0.03)
    }

    @Test("applyMapDatePreset.thisWeek starts at track and stays within twelve-month window")
    func testApplyPresetThisWeek() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let ref = Date(timeIntervalSince1970: 1_720_000_000)

        var f = CharterDiscoveryFilters()
        f.applyMapDatePreset(.thisWeek, reference: ref, calendar: cal)

        let trackStart = cal.startOfDay(for: ref)
        let trackEnd = CharterDiscoveryFilters.defaultDiscoveryWindow(reference: ref, calendar: cal).1
        #expect(f.windowStart == trackStart)
        #expect(f.windowEnd <= trackEnd)
        #expect(f.windowEnd >= f.windowStart)
    }

    @Test("hasNonDefaultFilters mirrors activeFilterCount > 0")
    func testHasNonDefaultFilters() {
        var f = CharterDiscoveryFilters()
        #expect(f.hasNonDefaultFilters == false)
        f.sortOrder = .recentlyPosted
        #expect(f.hasNonDefaultFilters == true)
    }
}
