//
//  SyncPayloadsTests.swift
//  anyfleetTests
//
//  Tests for SyncPayloads encoding/decoding functionality
//

import Foundation
import Testing
@testable import anyfleet

@Suite("Sync Payloads Tests")
struct SyncPayloadsTests {

    @Test("ContentPublishPayload - encoding with snake_case keys")
    @MainActor
    func testContentPublishPayloadEncoding() throws {
        // Arrange
        let checklistData: [String: Any] = [
            "id": "test-checklist-id",
            "title": "Test Checklist",
            "sections": [
                [
                    "id": "section-1",
                    "title": "Safety",
                    "items": [
                        ["id": "item-1", "title": "Check brakes", "isCompleted": false]
                    ]
                ]
            ],
            "tags": ["safety"],
            "checklistType": "general",
            "createdAt": "2024-12-24T10:00:00Z",
            "updatedAt": "2024-12-24T10:00:00Z",
            "syncStatus": "pending"
        ]

        let payload = ContentPublishPayload(
            title: "Test Checklist",
            description: "A test checklist for safety",
            contentType: "checklist",
            contentData: checklistData,
            tags: ["safety", "aviation"],
            language: "en",
            publicID: "test-checklist-abc123"
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - Check that JSON uses snake_case keys
        #expect(jsonString.contains("\"title\":\"Test Checklist\""))
        #expect(jsonString.contains("\"content_type\":\"checklist\""))
        #expect(jsonString.contains("\"public_id\":\"test-checklist-abc123\""))
        #expect(jsonString.contains("\"language\":\"en\""))
        #expect(jsonString.contains("\"tags\":[\"safety\",\"aviation\"]"))

        // Verify content_data is a JSON object, not a string
        #expect(jsonString.contains("\"content_data\":{"))
        #expect(jsonString.contains("\"id\":\"test-checklist-id\""))
        #expect(jsonString.contains("\"sections\":["))
    }

    @Test("ContentPublishPayload - round-trip encoding/decoding")
    @MainActor
    func testContentPublishPayloadRoundTrip() throws {
        // Arrange
        let originalContentData: [String: Any] = [
            "id": "round-trip-test-id",
            "title": "Round Trip Test",
            "sections": [],
            "tags": ["test"],
            "checklistType": "general",
            "createdAt": "2024-12-24T12:00:00Z",
            "updatedAt": "2024-12-24T12:00:00Z",
            "syncStatus": "pending"
        ]

        let originalPayload = ContentPublishPayload(
            title: "Round Trip Test",
            description: nil,
            contentType: "checklist",
            contentData: originalContentData,
            tags: ["test", "round-trip"],
            language: "en",
            publicID: "round-trip-test-xyz789"
        )

        // Act - Encode then decode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalPayload)

        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(ContentPublishPayload.self, from: data)

        // Assert - All fields match
        #expect(decodedPayload.title == originalPayload.title)
        #expect(decodedPayload.description == originalPayload.description)
        #expect(decodedPayload.contentType == originalPayload.contentType)
        #expect(decodedPayload.tags == originalPayload.tags)
        #expect(decodedPayload.language == originalPayload.language)
        #expect(decodedPayload.publicID == originalPayload.publicID)

        // Verify contentData is preserved as dictionary
        #expect(decodedPayload.contentData["id"] as? String == "round-trip-test-id")
        #expect(decodedPayload.contentData["title"] as? String == "Round Trip Test")
        #expect(decodedPayload.contentData["tags"] as? [String] == ["test"])
    }

    @Test("UnpublishPayload - encoding and decoding")
    @MainActor
    func testUnpublishPayloadEncodingDecoding() throws {
        // Arrange
        let publicID = "test-checklist-to-unpublish-abc123"
        let payload = UnpublishPayload(publicID: publicID)

        // Act - Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - Check snake_case encoding
        #expect(jsonString.contains("\"public_id\":\"\(publicID)\""))

        // Act - Decode
        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(UnpublishPayload.self, from: data)

        // Assert - PublicID matches
        #expect(decodedPayload.publicID == publicID)
    }

    @Test("ContentPublishPayload - handles complex nested contentData")
    @MainActor
    func testContentPublishPayloadComplexContentData() throws {
        // Arrange - Create a complex nested structure like a real checklist
        let complexContentData: [String: Any] = [
            "id": "complex-checklist-123",
            "title": "Complex Aviation Checklist",
            "sections": [
                [
                    "id": "pre-flight-section",
                    "title": "Pre-Flight Checks",
                    "items": [
                        [
                            "id": "item-1",
                            "title": "Check fuel levels",
                            "isCompleted": false,
                            "notes": "Minimum 3 hours reserve required"
                        ],
                        [
                            "id": "item-2",
                            "title": "Verify weather conditions",
                            "isCompleted": false,
                            "notes": nil
                        ]
                    ]
                ],
                [
                    "id": "in-flight-section",
                    "title": "In-Flight Procedures",
                    "items": [
                        [
                            "id": "item-3",
                            "title": "Monitor engine instruments",
                            "isCompleted": false
                        ]
                    ]
                ]
            ],
            "tags": ["aviation", "safety", "complex"],
            "checklistType": "pre-flight",
            "createdAt": "2024-12-24T15:30:00Z",
            "updatedAt": "2024-12-24T15:45:00Z",
            "syncStatus": "pending"
        ]

        let payload = ContentPublishPayload(
            title: "Complex Aviation Checklist",
            description: "Comprehensive pre-flight safety checklist",
            contentType: "checklist",
            contentData: complexContentData,
            tags: ["aviation", "safety"],
            language: "en",
            publicID: "complex-aviation-checklist-def456"
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - Complex nested structure is preserved
        #expect(jsonString.contains("\"sections\":"))
        #expect(jsonString.contains("\"pre-flight-section\""))
        #expect(jsonString.contains("\"in-flight-section\""))
        #expect(jsonString.contains("\"Check fuel levels\""))
        #expect(jsonString.contains("\"Monitor engine instruments\""))
        #expect(jsonString.contains("\"notes\":\"Minimum 3 hours reserve required\""))

        // Verify it's not double-encoded as a string
        #expect(!jsonString.contains("\\\"sections\\\"")) // No escaped quotes
    }

    @Test("AnyCodable - handles all data types")
    @MainActor
    func testAnyCodableDataTypes() throws {
        // Arrange
        let testData: [String: Any] = [
            "string": "test string",
            "int": 42,
            "double": 3.14159,
            "bool": true,
            "array": ["item1", "item2", 3],
            "null": NSNull(),
            "nested": [
                "key": "value",
                "number": 123
            ]
        ]

        // Act - Encode via AnyCodable
        let anyCodable = AnyCodable(testData)
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - All data types preserved
        #expect(jsonString.contains("\"string\":\"test string\""))
        #expect(jsonString.contains("\"int\":42"))
        #expect(jsonString.contains("\"double\":3.14159"))
        #expect(jsonString.contains("\"bool\":true"))
        #expect(jsonString.contains("\"array\":[\"item1\",\"item2\",3]"))
        #expect(jsonString.contains("\"nested\":"))
        #expect(jsonString.contains("\"key\":\"value\""))
        #expect(jsonString.contains("\"number\":123"))

        // Act - Decode back
        let decoder = JSONDecoder()
        let decodedAnyCodable = try decoder.decode(AnyCodable.self, from: data)
        let decodedData = decodedAnyCodable.value as? [String: Any]

        // Assert - Round trip preserves data
        #expect(decodedData?["string"] as? String == "test string")
        #expect(decodedData?["int"] as? Int == 42)
        #expect(decodedData?["double"] as? Double == 3.14159)
        #expect(decodedData?["bool"] as? Bool == true)
        #expect(decodedData?["array"] as? [Any] != nil)
    }

    @Test("ContentPublishPayload - minimal valid payload")
    @MainActor
    func testMinimalValidPayload() throws {
        // Arrange - Minimal valid checklist
        let minimalContentData: [String: Any] = [
            "id": "minimal-id",
            "title": "Minimal",
            "sections": [],
            "tags": [],
            "checklistType": "general",
            "createdAt": "2024-12-24T10:00:00Z",
            "updatedAt": "2024-12-24T10:00:00Z",
            "syncStatus": "pending"
        ]

        let payload = ContentPublishPayload(
            title: "Minimal Checklist",
            description: nil,
            contentType: "checklist",
            contentData: minimalContentData,
            tags: [],
            language: "en",
            publicID: "minimal-checklist-123"
        )

        // Act & Assert - Should encode without errors
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ContentPublishPayload.self, from: data)

        // Verify minimal fields
        #expect(decoded.title == "Minimal Checklist")
        #expect(decoded.description == nil)
        #expect(decoded.tags.isEmpty)
        #expect(decoded.publicID == "minimal-checklist-123")
    }
}
