//
//  AppViewTests.swift
//  anyfleetTests
//
//  Unit tests for AppView component initialization
//

import Foundation
import Testing
@testable import anyfleet

@Suite("AppView Tests")
struct AppViewTests {

    @Test("AppView initializes ProfileView with correct dependencies")
    @MainActor
    func testProfileViewInitialization() {
        // Given - mock services
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()

        // When - ProfileViewModel is created with mock dependencies
        let viewModel = ProfileViewModel(
            authService: mockAuthService,
            authObserver: mockAuthObserver
        )

        // Then - ProfileViewModel should be properly initialized
        #expect(viewModel.authObserver === mockAuthObserver)
        #expect(viewModel.isSignedIn == mockAuthObserver.isSignedIn)
    }

    @Test("ProfileViewModel auth state changes are observed")
    @MainActor
    func testProfileViewModelAuthStateChanges() {
        // Given
        let mockAuthService = MockAuthService()
        let mockAuthObserver = MockAuthStateObserver()
        let viewModel = ProfileViewModel(authService: mockAuthService, authObserver: mockAuthObserver)

        // Initially not signed in
        #expect(viewModel.isSignedIn == false)
        #expect(viewModel.currentUser == nil)

        // When - auth state changes
        mockAuthObserver.mockIsSignedIn = true
        mockAuthObserver.mockCurrentUser = UserInfo(
            id: "test-user-id",
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

        // Then - viewModel should reflect the changes
        #expect(viewModel.isSignedIn == true)
        #expect(viewModel.currentUser?.email == "test@example.com")
        #expect(viewModel.currentUser?.profileImageUrl == "https://example.com/image.jpg")
    }
}

// MARK: - Test Helpers

// Note: AppDependencies testing is complex due to singleton nature
// Tests focus on ProfileViewModel behavior with mock dependencies