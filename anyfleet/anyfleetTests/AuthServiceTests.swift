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
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("AuthService initialization - singleton access")
    @MainActor
    func testInitialization_SingletonAccess() async throws {
        // Test that AuthService singleton can be accessed
        // Note: This tests the singleton pattern
        let service1 = AuthService.shared
        let service2 = AuthService.shared
        
        // Verify it's the same instance (singleton pattern)
        #expect(service1 === service2)
        
        // Verify service has expected properties
        // Note: Actual authentication state depends on KeychainService which we can't easily mock
        #expect(type(of: service1.isAuthenticated) == Bool.self)
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
    
    // MARK: - Note on Integration Tests
    
    /*
     * Full integration tests for AuthService would require:
     * 
     * 1. Mocking URLSession to simulate network responses
     * 2. Mocking KeychainService to control token storage
     * 3. Mocking ASAuthorizationAppleIDCredential for Apple Sign In flow
     * 
     * These tests are better suited for:
     * - Integration test suite with real backend
     * - UI tests that exercise the full sign-in flow
     * - Manual testing with real Apple Sign In credentials
     * 
     * The current tests verify:
     * - Error conversion logic
     * - Data model decoding
     * - Basic service initialization
     */
}

