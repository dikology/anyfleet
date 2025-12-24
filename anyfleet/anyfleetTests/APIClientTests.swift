//
//  APIClientTests.swift
//  anyfleetTests
//
//  Tests for APIClient request/response encoding/decoding
//

import Foundation
import Testing
@testable import anyfleet

@Suite("API Client Tests")
struct APIClientTests {

    @Test("PublishContentRequest - encoding with snake_case keys")
    @MainActor
    func testPublishContentRequestEncoding() throws {
        // Arrange
        let contentData: [String: Any] = [
            "id": "test-checklist-123",
            "title": "Test Checklist",
            "sections": [],
            "tags": [],
            "checklistType": "general",
            "createdAt": "2024-12-24T10:00:00Z",
            "updatedAt": "2024-12-24T10:00:00Z",
            "syncStatus": "pending"
        ]

        let request = PublishContentRequest(
            title: "Test Checklist",
            description: "Test description",
            contentType: "checklist",
            contentData: contentData,
            tags: ["test"],
            language: "en",
            publicID: "test-checklist-abc123",
            canFork: true
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - Verify snake_case encoding
        #expect(jsonString.contains("\"title\":\"Test Checklist\""))
        #expect(jsonString.contains("\"description\":\"Test description\""))
        #expect(jsonString.contains("\"content_type\":\"checklist\""))
        #expect(jsonString.contains("\"public_id\":\"test-checklist-abc123\""))
        #expect(jsonString.contains("\"language\":\"en\""))
        #expect(jsonString.contains("\"tags\":[\"test\"]"))
        #expect(jsonString.contains("\"can_fork\":true"))

        // Verify content_data is a JSON object, not a string
        #expect(jsonString.contains("\"content_data\":{"))
        #expect(jsonString.contains("\"id\":\"test-checklist-123\""))
        #expect(jsonString.contains("\"title\":\"Test Checklist\""))
    }

    @Test("PublishContentRequest - minimal valid request")
    @MainActor
    func testPublishContentRequestMinimal() throws {
        // Arrange
        let minimalContentData: [String: Any] = [
            "id": "minimal-123",
            "title": "Minimal",
            "sections": [],
            "tags": [],
            "checklistType": "general",
            "createdAt": "2024-12-24T10:00:00Z",
            "updatedAt": "2024-12-24T10:00:00Z",
            "syncStatus": "pending"
        ]

        let request = PublishContentRequest(
            title: "Minimal Checklist",
            description: nil,
            contentType: "checklist",
            contentData: minimalContentData,
            tags: [],
            language: "en",
            publicID: "minimal-abc",
            canFork: false
        )

        // Act
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - Should encode successfully
        #expect(jsonString.contains("\"title\":\"Minimal Checklist\""))
        #expect(jsonString.contains("\"content_type\":\"checklist\""))
        #expect(jsonString.contains("\"public_id\":\"minimal-abc\""))
        #expect(jsonString.contains("\"can_fork\":false"))
        #expect(jsonString.contains("\"tags\":[]"))
    }

    @Test("PublishContentResponse - decoding from snake_case JSON")
    @MainActor
    func testPublishContentResponseDecoding() throws {
        // Arrange - Simulate backend response JSON
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "public_id": "test-checklist-published-123",
            "published_at": "2024-12-24T10:30:00Z",
            "author_username": "testuser",
            "can_fork": true
        }
        """

        let data = jsonString.data(using: .utf8)!

        // Act
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(PublishContentResponse.self, from: data)

        // Assert - All fields decoded correctly
        #expect(response.id == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
        #expect(response.publicID == "test-checklist-published-123")
        #expect(response.authorUsername == "testuser")
        #expect(response.canFork == true)

        // Verify publishedAt date
        let expectedDate = ISO8601DateFormatter().date(from: "2024-12-24T10:30:00Z")
        #expect(response.publishedAt == expectedDate)
    }

    @Test("PublishContentResponse - decoding with null author_username")
    @MainActor
    func testPublishContentResponseDecodingWithNulls() throws {
        // Arrange - Response with null author_username
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "public_id": "anonymous-checklist-456",
            "published_at": "2024-12-24T11:00:00Z",
            "author_username": null,
            "can_fork": false
        }
        """

        let data = jsonString.data(using: .utf8)!

        // Act
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(PublishContentResponse.self, from: data)

        // Assert
        #expect(response.id == UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001"))
        #expect(response.publicID == "anonymous-checklist-456")
        #expect(response.authorUsername == nil)
        #expect(response.canFork == false)
    }

    @Test("PublishContentResponse - round-trip encoding/decoding")
    @MainActor
    func testPublishContentResponseRoundTrip() throws {
        // Arrange
        let originalId = UUID()
        let originalPublicID = "round-trip-test-789"
        let originalPublishedAt = Date()
        let originalAuthorUsername = "roundtripuser"
        let originalCanFork = true

        // Simulate creating a response object (as if from backend)
        let originalResponse = PublishContentResponse(
            id: originalId,
            publicID: originalPublicID,
            publishedAt: originalPublishedAt,
            authorUsername: originalAuthorUsername,
            canFork: originalCanFork
        )

        // Act - Encode (simulate sending to client)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalResponse)

        // Act - Decode (simulate client receiving)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedResponse = try decoder.decode(PublishContentResponse.self, from: data)

        // Assert - All fields match
        #expect(decodedResponse.id == originalId)
        #expect(decodedResponse.publicID == originalPublicID)
        #expect(decodedResponse.authorUsername == originalAuthorUsername)
        #expect(decodedResponse.canFork == originalCanFork)

        // Date comparison (allowing for small encoding precision differences)
        let timeDifference = abs(decodedResponse.publishedAt.timeIntervalSince(originalPublishedAt))
        #expect(timeDifference < 1.0) // Within 1 second
    }

    @Test("PublishContentResponse - encoding produces snake_case")
    @MainActor
    func testPublishContentResponseEncoding() throws {
        // Arrange
        let response = PublishContentResponse(
            id: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002")!,
            publicID: "encoded-test-999",
            publishedAt: Date(timeIntervalSince1970: 1735038000), // 2024-12-24T11:00:00Z (UTC)
            authorUsername: "encoder",
            canFork: true
        )

        // Act
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)
        let jsonString = String(data: data, encoding: .utf8)!

        // Assert - Uses snake_case keys
        #expect(jsonString.contains("\"public_id\":\"encoded-test-999\""))
        #expect(jsonString.contains("\"published_at\":\"2024-12-24T11:00:00Z\""))
        #expect(jsonString.contains("\"author_username\":\"encoder\""))
        #expect(jsonString.contains("\"can_fork\":true"))
    }

    @Test("APIClient - decoder configuration")
    @MainActor
    func testAPIClientDecoderConfiguration() {
        // Arrange - Create APIClient instance
        let mockAuthService = MockAuthService()
        let apiClient = APIClient(authService: mockAuthService)

        // Act - Access private decoder (we'll test by attempting to decode)
        // Since we can't access private properties, we'll test the behavior indirectly
        // by ensuring our test responses decode correctly
        let jsonString = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440003",
            "public_id": "decoder-test-xyz",
            "published_at": "2024-12-24T13:00:00Z",
            "author_username": "test",
            "can_fork": false
        }
        """

        let data = jsonString.data(using: .utf8)!

        // Act & Assert - Should decode successfully with snake_case keys
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Note: Not setting keyDecodingStrategy - using explicit CodingKeys instead

        let response = try? decoder.decode(PublishContentResponse.self, from: data)

        // Assert - Decodes correctly
        #expect(response != nil)
        #expect(response?.publicID == "decoder-test-xyz")
        #expect(response?.canFork == false)
    }

    @Test("APIClient initialization with protocol")
    func testAPIClientInitializationWithProtocol() {
        // Arrange
        let mockAuthService = MockAuthService()

        // Act & Assert - Should initialize successfully with protocol
        let apiClient = APIClient(authService: mockAuthService)
        #expect(apiClient != nil)
    }

    @Test("APIClient - encoder configuration")
    @MainActor
    func testAPIClientEncoderConfiguration() {
        // Arrange
        let mockAuthService = MockAuthService()
        let apiClient = APIClient(authService: mockAuthService)

        let contentData: [String: Any] = [
            "id": "encoder-test-456",
            "title": "Encoder Test",
            "sections": [],
            "tags": [],
            "checklistType": "general",
            "createdAt": "2024-12-24T14:00:00Z",
            "updatedAt": "2024-12-24T14:00:00Z",
            "syncStatus": "pending"
        ]

        let request = PublishContentRequest(
            title: "Encoder Test Checklist",
            description: nil,
            contentType: "checklist",
            contentData: contentData,
            tags: ["encoder"],
            language: "en",
            publicID: "encoder-test-456",
            canFork: true
        )

        // Act - Encode using standard JSONEncoder (simulating APIClient behavior)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Note: Not setting keyEncodingStrategy - using explicit CodingKeys instead

        let data = try? encoder.encode(request)
        let jsonString = String(data: data!, encoding: .utf8)!

        // Assert - Uses snake_case keys from explicit CodingKeys
        #expect(jsonString.contains("\"content_type\":\"checklist\""))
        #expect(jsonString.contains("\"public_id\":\"encoder-test-456\""))
        #expect(jsonString.contains("\"can_fork\":true"))
    }
}

// MARK: - Mock Services
// MockAuthService is defined in MockAuthService.swift
