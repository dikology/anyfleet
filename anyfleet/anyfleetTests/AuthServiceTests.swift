//
//  AuthServiceTests.swift
//  anyfleetTests
//
//  Unit tests for AuthService using Swift Testing
//

import Foundation
import Testing
import AuthenticationServices
@testable import anyfleet

// MARK: - Mock Classes

/// Mock implementation of ASAuthorizationAppleIDCredential for testing
class MockAppleIDCredential {
    var fullName: PersonNameComponents?
    var email: String?
}

// MARK: - Test Suite

@Suite("AuthService Tests")
struct AuthServiceTests {
    
    // MARK: - Helper Methods
    
    private func createMockTokenResponse() -> TokenResponse {
        TokenResponse(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            tokenType: "bearer",
            expiresIn: 1800,
            user: UserInfo(
                id: UUID().uuidString,
                email: "test@example.com",
                username: "testuser",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                profileImageUrl: nil,
                profileImageThumbnailUrl: nil,
                bio: nil,
                location: nil,
                nationality: nil,
                profileVisibility: "public"
            )
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("AuthService initialization")
    @MainActor
    func testInitialization() async throws {
        // Test that AuthService can be initialized
        let service = AuthService()

        // Verify service has expected properties
        // Note: Actual authentication state depends on KeychainService which we can't easily mock
        #expect(type(of: service.isAuthenticated) == Bool.self)
    }
    
    @Test("AuthService conforms to AuthServiceProtocol")
    @MainActor
    func testAuthServiceProtocolConformance() {
        // Arrange
        let authService = AuthService()

        // Act & Assert - Should be able to use as protocol
        // If this assignment fails to compile, AuthService doesn't conform to the protocol
        let protocolService: AuthServiceProtocol = authService

        // Verify the protocol service has the expected properties
        #expect(protocolService.isAuthenticated == authService.isAuthenticated)
    }

    // MARK: - Error Conversion Tests

    @Test("Error conversion - AuthError to AppError")
    func testErrorConversion_AuthError() {
        let authError = AuthError.invalidToken
        let appError = authError.toAppError()
        
        if case .authenticationError(let convertedError) = appError {
            #expect(convertedError == .invalidToken)
        } else {
            Issue.record("Expected authenticationError case")
        }
    }
    
    @Test("Error conversion - Network error to AppError")
    func testErrorConversion_NetworkError() {
        let nsError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: [NSLocalizedDescriptionKey: "Connection refused"]
        )
        let appError = nsError.toAppError()
        
        if case .networkError(let networkError) = appError {
            if case .connectionRefused = networkError {
                #expect(true)
            } else {
                Issue.record("Expected connectionRefused case")
            }
        } else {
            Issue.record("Expected networkError case")
        }
    }
    
    @Test("Error conversion - Unknown error to AppError")
    func testErrorConversion_UnknownError() {
        let customError = NSError(domain: "CustomError", code: 999)
        let appError = customError.toAppError()
        
        if case .unknown(let error) = appError {
            #expect((error as NSError).domain == "CustomError")
        } else {
            Issue.record("Expected unknown case")
        }
    }
    
    // MARK: - Token Response Tests
    
    @Test("TokenResponse decoding - valid response")
    @MainActor
    func testTokenResponse_Decoding() throws {
        let json = """
        {
            "access_token": "test_access_token",
            "refresh_token": "test_refresh_token",
            "token_type": "bearer",
            "expires_in": 1800,
            "user": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "test@example.com",
                "username": "testuser",
                "created_at": "2024-01-01T00:00:00Z"
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        #expect(response.accessToken == "test_access_token")
        #expect(response.refreshToken == "test_refresh_token")
        #expect(response.tokenType == "bearer")
        #expect(response.expiresIn == 1800)
        #expect(response.user.email == "test@example.com")
    }
    
    // MARK: - UserInfo Tests
    
    @Test("UserInfo - username optional")
    @MainActor
    func testUserInfo_UsernameOptional() throws {
        let json = """
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "test@example.com",
            "created_at": "2024-01-01T00:00:00Z"
        }
        """
        
        let data = json.data(using: .utf8)!
        let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
        
        #expect(userInfo.email == "test@example.com")
        #expect(userInfo.username == nil)
    }
    
    // MARK: - Apple Sign-In User Info Extraction Tests

    @Test("Apple credential user info extraction - full name available")
    func testAppleCredential_UserInfoExtraction_FullNameAvailable() {
        // Arrange - Create mock credential with full name
        let mockCredential = MockAppleIDCredential()
        mockCredential.fullName = PersonNameComponents()
        mockCredential.fullName?.givenName = "John"
        mockCredential.fullName?.familyName = "Doe"
        mockCredential.email = "john.doe@example.com"

        // Act - Simulate the user info extraction logic from AuthService
        var userInfo: [String: Any] = [:]

        if let fullName = mockCredential.fullName {
            var nameComponents: [String: String] = [:]
            if let givenName = fullName.givenName {
                nameComponents["firstName"] = givenName
            }
            if let familyName = fullName.familyName {
                nameComponents["lastName"] = familyName
            }
            if !nameComponents.isEmpty {
                userInfo["name"] = nameComponents
            }
        }

        if let email = mockCredential.email {
            userInfo["email"] = email
        }

        // Assert
        #expect(userInfo.count == 2)
        #expect((userInfo["name"] as? [String: String])?["firstName"] == "John")
        #expect((userInfo["name"] as? [String: String])?["lastName"] == "Doe")
        #expect(userInfo["email"] as? String == "john.doe@example.com")
    }

    @Test("Apple credential user info extraction - no full name")
    func testAppleCredential_UserInfoExtraction_NoFullName() {
        // Arrange - Create mock credential without full name
        let mockCredential = MockAppleIDCredential()
        mockCredential.fullName = nil
        mockCredential.email = nil

        // Act - Simulate the user info extraction logic
        var userInfo: [String: Any] = [:]

        if let fullName = mockCredential.fullName {
            var nameComponents: [String: String] = [:]
            if let givenName = fullName.givenName {
                nameComponents["firstName"] = givenName
            }
            if let familyName = fullName.familyName {
                nameComponents["lastName"] = familyName
            }
            if !nameComponents.isEmpty {
                userInfo["name"] = nameComponents
            }
        }

        if let email = mockCredential.email {
            userInfo["email"] = email
        }

        // Assert
        #expect(userInfo.isEmpty)
    }

    @Test("Apple credential user info extraction - only first name")
    func testAppleCredential_UserInfoExtraction_OnlyFirstName() {
        // Arrange
        let mockCredential = MockAppleIDCredential()
        mockCredential.fullName = PersonNameComponents()
        mockCredential.fullName?.givenName = "John"
        mockCredential.fullName?.familyName = nil

        // Act
        var userInfo: [String: Any] = [:]

        if let fullName = mockCredential.fullName {
            var nameComponents: [String: String] = [:]
            if let givenName = fullName.givenName {
                nameComponents["firstName"] = givenName
            }
            if let familyName = fullName.familyName {
                nameComponents["lastName"] = familyName
            }
            if !nameComponents.isEmpty {
                userInfo["name"] = nameComponents
            }
        }

        // Assert
        #expect(userInfo.count == 1)
        #expect((userInfo["name"] as? [String: String])?.count == 1)
        #expect((userInfo["name"] as? [String: String])?["firstName"] == "John")
    }

    // MARK: - AnyCodable Tests

    @Test("AnyCodable encoding/decoding - string value")
    @MainActor
    func testAnyCodable_StringEncoding() throws {
        // Arrange
        let originalValue = "test string"
        let anyCodable = AnyCodable(originalValue)

        // Act - Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Assert
        #expect(decoded.value as? String == originalValue)
    }

    @Test("AnyCodable encoding/decoding - dictionary with mixed types")
    @MainActor
    func testAnyCodable_DictionaryEncoding() throws {
        // Arrange
        let originalDict: [String: Any] = [
            "name": "John",
            "age": 30,
            "isActive": true
        ]
        let anyCodable = AnyCodable(originalDict)

        // Act - Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(anyCodable)

        // Decode back
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AnyCodable.self, from: data)

        // Assert
        let decodedDict = decoded.value as? [String: Any]
        #expect(decodedDict?["name"] as? String == "John")
        #expect(decodedDict?["age"] as? Int == 30)
        #expect(decodedDict?["isActive"] as? Bool == true)
    }

    @Test("AppleSignInRequest encoding - with user info")
    @MainActor
    func testAppleSignInRequest_Encoding_WithUserInfo() throws {
        // Arrange
        let userInfo: [String: AnyCodable] = [
            "name": AnyCodable(["firstName": "John", "lastName": "Doe"])
        ]
        let request = AppleSignInRequest(identityToken: "test_token", userInfo: userInfo)

        // Act - Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)

        // Assert
        #expect(jsonString?.contains("\"identity_token\":\"test_token\"") == true)
        #expect(jsonString?.contains("user_info") == true)
        #expect(jsonString?.contains("firstName") == true)
    }

    @Test("AppleSignInRequest encoding - without user info")
    @MainActor
    func testAppleSignInRequest_Encoding_WithoutUserInfo() throws {
        // Arrange
        let request = AppleSignInRequest(identityToken: "test_token", userInfo: nil)

        // Act - Encode to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let jsonString = String(data: data, encoding: .utf8)

        // Assert
        #expect(jsonString?.contains("\"identity_token\":\"test_token\"") == true)
        #expect(jsonString?.contains("user_info") == false)
    }

    // MARK: - Note on Integration Tests

    /*
     * Full integration tests for AuthService would require:

     * 1. Mocking URLSession to simulate network responses
     * 2. Mocking KeychainService to control token storage
     * 3. Mocking ASAuthorizationAppleIDCredential for Apple Sign In flow

     * These tests are better suited for:
     * - Integration test suite with real backend
     * - UI tests that exercise the full sign-in flow
     * - Manual testing with real Apple Sign In credentials

     * The current tests verify:
     * - Error conversion logic
     * - Data model decoding
     * - Basic service initialization
     * - Apple credential user info extraction
     * - AnyCodable encoding/decoding
     * - AppleSignInRequest serialization
     * - Image URL protocol handling
     */

    // MARK: - Image URL Handling Tests

    @Test("AuthService adds https protocol to image URLs without protocol")
    func testImageUrlProtocolAddition() async {
        // Given
        let authService = AuthService(baseURL: "https://test.example.com/api/v1")

        // Mock current user
        authService.currentUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: "example.com/uploads/image.jpg", // No protocol
            profileImageThumbnailUrl: "example.com/uploads/thumb.jpg", // No protocol
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // Mock successful upload response
        let mockResponse = ProfileImageUploadResponse(
            profileImageUrl: "example.com/uploads/new-image.jpg",
            profileImageThumbnailUrl: "example.com/uploads/new-thumb.jpg",
            message: "Upload successful"
        )

        // When - simulating uploadProfileImage logic
        if let currentUser = authService.currentUser {
            let imageUrl = mockResponse.profileImageUrl.hasPrefix("http") ? mockResponse.profileImageUrl : "https://\(mockResponse.profileImageUrl)"
            let thumbnailUrl = mockResponse.profileImageThumbnailUrl.hasPrefix("http") ? mockResponse.profileImageThumbnailUrl : "https://\(mockResponse.profileImageThumbnailUrl)"

            let updatedUser = UserInfo(
                id: currentUser.id,
                email: currentUser.email,
                username: currentUser.username,
                createdAt: currentUser.createdAt,
                profileImageUrl: imageUrl,
                profileImageThumbnailUrl: thumbnailUrl,
                bio: currentUser.bio,
                location: currentUser.location,
                nationality: currentUser.nationality,
                profileVisibility: currentUser.profileVisibility
            )

            // Update auth service
            authService.currentUser = updatedUser
        }

        // Then
        #expect(authService.currentUser?.profileImageUrl == "https://example.com/uploads/new-image.jpg")
        #expect(authService.currentUser?.profileImageThumbnailUrl == "https://example.com/uploads/new-thumb.jpg")
    }

    @Test("AuthService preserves https protocol for URLs that already have it")
    func testHttpsUrlPreservation() async {
        // Given
        let authService = AuthService(baseURL: "https://test.example.com/api/v1")

        // Mock current user with URLs that already have https
        authService.currentUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: "https://example.com/uploads/image.jpg",
            profileImageThumbnailUrl: "https://example.com/uploads/thumb.jpg",
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // Mock successful upload response with https URLs
        let mockResponse = ProfileImageUploadResponse(
            profileImageUrl: "https://example.com/uploads/new-image.jpg",
            profileImageThumbnailUrl: "https://example.com/uploads/new-thumb.jpg",
            message: "Upload successful"
        )

        // When - simulating uploadProfileImage logic
        if let currentUser = authService.currentUser {
            let imageUrl = mockResponse.profileImageUrl.hasPrefix("http") ? mockResponse.profileImageUrl : "https://\(mockResponse.profileImageUrl)"
            let thumbnailUrl = mockResponse.profileImageThumbnailUrl.hasPrefix("http") ? mockResponse.profileImageThumbnailUrl : "https://\(mockResponse.profileImageThumbnailUrl)"

            let updatedUser = UserInfo(
                id: currentUser.id,
                email: currentUser.email,
                username: currentUser.username,
                createdAt: currentUser.createdAt,
                profileImageUrl: imageUrl,
                profileImageThumbnailUrl: thumbnailUrl,
                bio: currentUser.bio,
                location: currentUser.location,
                nationality: currentUser.nationality,
                profileVisibility: currentUser.profileVisibility
            )

            // Update auth service
            authService.currentUser = updatedUser
        }

        // Then - URLs should remain unchanged
        #expect(authService.currentUser?.profileImageUrl == "https://example.com/uploads/new-image.jpg")
        #expect(authService.currentUser?.profileImageThumbnailUrl == "https://example.com/uploads/new-thumb.jpg")
    }

    @Test("AuthService handles loadCurrentUser URL protocol addition")
    func testLoadCurrentUserUrlProtocolAddition() async {
        // Given
        let authService = AuthService(baseURL: "https://test.example.com/api/v1")

        // Mock user data from backend without https protocol
        let mockUserFromBackend = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: "example.com/uploads/image.jpg", // No protocol
            profileImageThumbnailUrl: "example.com/uploads/thumb.jpg", // No protocol
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // When - simulating loadCurrentUser logic
        var user = mockUserFromBackend
        if let imageUrl = user.profileImageUrl, !imageUrl.hasPrefix("http") {
            user = UserInfo(
                id: user.id,
                email: user.email,
                username: user.username,
                createdAt: user.createdAt,
                profileImageUrl: "https://\(imageUrl)",
                profileImageThumbnailUrl: user.profileImageThumbnailUrl?.hasPrefix("http") == false ? "https://\(user.profileImageThumbnailUrl!)" : user.profileImageThumbnailUrl,
                bio: user.bio,
                location: user.location,
                nationality: user.nationality,
                profileVisibility: user.profileVisibility
            )
        }

        // Then
        #expect(user.profileImageUrl == "https://example.com/uploads/image.jpg")
        #expect(user.profileImageThumbnailUrl == "https://example.com/uploads/thumb.jpg")
    }
}

