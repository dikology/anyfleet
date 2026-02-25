//
//  CharterVisibilityTests.swift
//  anyfleetTests
//
//  Unit tests for CharterVisibility enum using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterVisibility Tests")
struct CharterVisibilityTests {

    // MARK: - Raw Values

    @Test("Raw values match expected strings")
    func testRawValues() {
        #expect(CharterVisibility.private.rawValue == "private")
        #expect(CharterVisibility.community.rawValue == "community")
        #expect(CharterVisibility.public.rawValue == "public")
    }

    @Test("Init from raw value - valid strings")
    func testInitFromRawValue_Valid() {
        #expect(CharterVisibility(rawValue: "private") == .private)
        #expect(CharterVisibility(rawValue: "community") == .community)
        #expect(CharterVisibility(rawValue: "public") == .public)
    }

    @Test("Init from raw value - invalid string returns nil")
    func testInitFromRawValue_Invalid() {
        #expect(CharterVisibility(rawValue: "unknown") == nil)
        #expect(CharterVisibility(rawValue: "") == nil)
        #expect(CharterVisibility(rawValue: "Public") == nil) // case-sensitive
    }

    // MARK: - CaseIterable

    @Test("CaseIterable contains exactly three cases")
    func testCaseIterable_Count() {
        #expect(CharterVisibility.allCases.count == 3)
    }

    @Test("CaseIterable contains all expected cases")
    func testCaseIterable_AllCases() {
        let all = CharterVisibility.allCases
        #expect(all.contains(.private))
        #expect(all.contains(.community))
        #expect(all.contains(.public))
    }

    // MARK: - Display Name

    @Test("displayName - private")
    func testDisplayName_Private() {
        #expect(CharterVisibility.private.displayName == "Private")
    }

    @Test("displayName - community")
    func testDisplayName_Community() {
        #expect(CharterVisibility.community.displayName == "Community")
    }

    @Test("displayName - public")
    func testDisplayName_Public() {
        #expect(CharterVisibility.public.displayName == "Public")
    }

    // MARK: - Description

    @Test("description - private")
    func testDescription_Private() {
        #expect(CharterVisibility.private.description == "Only visible to you")
    }

    @Test("description - community")
    func testDescription_Community() {
        #expect(CharterVisibility.community.description == "Visible to community members")
    }

    @Test("description - public")
    func testDescription_Public() {
        #expect(CharterVisibility.public.description == "Visible to all sailors")
    }

    // MARK: - System Image

    @Test("systemImage - private uses lock icon")
    func testSystemImage_Private() {
        #expect(CharterVisibility.private.systemImage == "lock.fill")
    }

    @Test("systemImage - community uses person group icon")
    func testSystemImage_Community() {
        #expect(CharterVisibility.community.systemImage == "person.2.fill")
    }

    @Test("systemImage - public uses globe icon")
    func testSystemImage_Public() {
        #expect(CharterVisibility.public.systemImage == "globe")
    }

    // MARK: - Codable

    @Test("Codable round-trip - private")
    func testCodable_Private() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(CharterVisibility.private)
        let decoded = try decoder.decode(CharterVisibility.self, from: data)
        #expect(decoded == .private)
    }

    @Test("Codable round-trip - community")
    func testCodable_Community() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(CharterVisibility.community)
        let decoded = try decoder.decode(CharterVisibility.self, from: data)
        #expect(decoded == .community)
    }

    @Test("Codable round-trip - public")
    func testCodable_Public() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(CharterVisibility.public)
        let decoded = try decoder.decode(CharterVisibility.self, from: data)
        #expect(decoded == .public)
    }
}
