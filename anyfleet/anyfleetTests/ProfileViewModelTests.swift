//
//  ProfileViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for ProfileViewModel auth state observation
//

import Foundation
import Testing
@testable import anyfleet

@Suite("ProfileViewModel Tests")
struct ProfileViewModelTests {

    // MARK: - Auth State Observation Tests

    @Test("ProfileViewModel exposes auth state correctly")
    @MainActor
    func testAuthStateObservation() async {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        mockAuthObserver.mockIsSignedIn = false
        mockAuthObserver.mockCurrentUser = nil

        // When
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver)

        // Then
        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.currentUser == nil)

        // When auth state changes
        mockAuthObserver.mockIsSignedIn = true
        mockAuthObserver.mockCurrentUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // Then viewModel reflects the changes
        #expect(viewModel.isSignedIn == true)
        #expect(viewModel.currentUser?.email == "test@example.com")
        #expect(viewModel.currentUser?.username == "Test User")
    }

    @Test("ProfileViewModel handles missing authObserver gracefully")
    @MainActor
    func testMissingAuthObserver() {
        // Given
        let mockAuthService = MockAuthService()

        // When - authObserver is nil, should create default AuthStateObserver
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: nil)

        // Then - should not crash and have valid authObserver
        #expect(viewModel.authObserver != nil)
    }

    @Test("ProfileViewModel profile completion calculation works correctly")
    @MainActor
    func testProfileCompletionCalculation() {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver)

        // Test with minimal user (just username, no image or bio)
        let minimalUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )

        // When
        let completion = viewModel.calculateProfileCompletion(for: minimalUser)

        // Then - should be 33% (1 out of 3 fields: username)
        #expect(completion == 33)

        // Test with complete profile
        let completeUser = UserInfo(
            id: "test-id",
            email: "test@example.com",
            username: "Test User",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: "https://example.com/image.jpg",
            profileImageThumbnailUrl: "https://example.com/thumb.jpg",
            bio: "Test bio",
            location: "Test location",
            nationality: "Test nationality",
            profileVisibility: "public"
        )

        // When
        let completeCompletion = viewModel.calculateProfileCompletion(for: completeUser)

        // Then - should be 100% (3 out of 3 fields)
        #expect(completeCompletion == 100)
    }
}

// MARK: - Mock Classes

class MockAuthStateObserver: AuthStateObserverProtocol {
    var mockIsSignedIn: Bool = false
    var mockCurrentUser: UserInfo? = nil
    var mockCurrentUserID: UUID? = nil

    var isSignedIn: Bool { mockIsSignedIn }
    var currentUser: UserInfo? { mockCurrentUser }
    var currentUserID: UUID? { mockCurrentUserID }
}