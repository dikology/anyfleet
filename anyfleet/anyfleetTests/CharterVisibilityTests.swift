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
    //
    // These tests compare against L10n constants rather than hardcoded English
    // strings so they pass on any simulator locale (Russian, French, etc.).
    // What is verified is the *mapping*: each case must use its own L10n key,
    // not accidentally share another case's key.

    @Test("displayName - private uses correct L10n key")
    func testDisplayName_Private() {
        #expect(CharterVisibility.private.displayName == L10n.Charter.Visibility.Private.name)
    }

    @Test("displayName - community uses correct L10n key")
    func testDisplayName_Community() {
        #expect(CharterVisibility.community.displayName == L10n.Charter.Visibility.Community.name)
    }

    @Test("displayName - public uses correct L10n key")
    func testDisplayName_Public() {
        #expect(CharterVisibility.public.displayName == L10n.Charter.Visibility.Public.name)
    }

    @Test("displayName - all cases are non-empty and distinct")
    func testDisplayName_NonEmptyAndDistinct() {
        let names = CharterVisibility.allCases.map(\.displayName)
        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == CharterVisibility.allCases.count)
    }

    // MARK: - Description

    @Test("description - private uses correct L10n key")
    func testDescription_Private() {
        #expect(CharterVisibility.private.description == L10n.Charter.Visibility.Private.description)
    }

    @Test("description - community uses correct L10n key")
    func testDescription_Community() {
        #expect(CharterVisibility.community.description == L10n.Charter.Visibility.Community.description)
    }

    @Test("description - public uses correct L10n key")
    func testDescription_Public() {
        #expect(CharterVisibility.public.description == L10n.Charter.Visibility.Public.description)
    }

    @Test("description - all cases are non-empty and distinct")
    func testDescription_NonEmptyAndDistinct() {
        let descriptions = CharterVisibility.allCases.map(\.description)
        #expect(descriptions.allSatisfy { !$0.isEmpty })
        #expect(Set(descriptions).count == CharterVisibility.allCases.count)
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
