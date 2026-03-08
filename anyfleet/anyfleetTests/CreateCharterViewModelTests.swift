//
//  CreateCharterViewModelTests.swift
//  anyfleetTests
//
//  Unit tests for CharterEditorViewModel using Swift Testing
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterEditorViewModel Tests")
struct CharterEditorViewModelTests {
    
    @Test("Initialize with default form - create mode")
    @MainActor
    func testInitialization_CreateMode() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        var didDismiss = false
        
        // Act
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: { didDismiss = true }
        )
        
        // Assert
        #expect(viewModel.form.name.isEmpty)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.currentError == nil)
        #expect(viewModel.isNewCharter == true)
        #expect(didDismiss == false)
    }
    
    @Test("Initialize with custom form - create mode")
    @MainActor
    func testInitializationWithCustomForm_CreateMode() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        var customForm = CharterFormState()
        customForm.name = "Test Charter"
        customForm.destinationQuery = "Test Location"
        customForm.vessel = "Test Boat"
        
        // Act
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {},
            initialForm: customForm
        )
        
        // Assert
        #expect(viewModel.form.name == "Test Charter")
        #expect(viewModel.form.vessel == "Test Boat")
        #expect(viewModel.form.destinationQuery == "Test Location")
        #expect(viewModel.isNewCharter == true)
    }
    
    @Test("Initialize - edit mode")
    @MainActor
    func testInitialization_EditMode() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let charterID = UUID()
        
        // Act
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: charterID,
            onDismiss: {}
        )
        
        // Assert
        #expect(viewModel.isNewCharter == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentError == nil)
    }
    
    @Test("Completion progress - default form")
    @MainActor
    func testCompletionProgressDefault() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )

        // Act & Assert — default: startDate + endDate count (2/5); name, vessel, destination empty
        let expected = 2.0 / 5.0
        #expect(abs(viewModel.completionProgress - expected) < 0.001)
    }
    
    @Test("Completion progress - minimal filled form")
    @MainActor
    func testCompletionProgressMinimal() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )

        // Act - Clear all non-date fields
        viewModel.form.name = ""
        viewModel.form.vessel = ""
        viewModel.form.destinationQuery = ""
        viewModel.form.selectedPlace = nil
        // Note: Dates always have values (can't be "empty")
        // So startDate and endDate still count as filled

        // Assert — only dates filled (2/5) = 0.4
        let expected = 2.0 / 5.0
        #expect(abs(viewModel.completionProgress - expected) < 0.001)
    }
    
    @Test("Completion progress - partially filled form")
    @MainActor
    func testCompletionProgressPartial() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )

        // Act - Clear some fields to make it truly partial
        viewModel.form.name = ""        // Empty
        viewModel.form.vessel = ""      // Empty
        // startDate and endDate still have default values

        // Assert — dates filled (2/5) = 0.4
        #expect(abs(viewModel.completionProgress - 0.4) < 0.001)
    }
    
    @Test("Completion progress - fully filled form")
    @MainActor
    func testCompletionProgressFull() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        // Act
        viewModel.form.name = "Test"
        viewModel.form.vessel = "Boat"
        viewModel.form.destinationQuery = "Location"
        viewModel.form.startDate = Date().addingTimeInterval(86400) // Tomorrow
        viewModel.form.endDate = Date().addingTimeInterval(172800) // Day after
        
        // Assert — all 5 fields filled = 1.0
        #expect(viewModel.completionProgress == 1.0)
    }
    
    @Test("Form validation - valid form")
    @MainActor
    func testIsValid_ValidForm() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        // Act
        viewModel.form.name = "Test Charter"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Assert
        #expect(viewModel.isValid == true)
    }
    
    @Test("Form validation - empty name")
    @MainActor
    func testIsValid_EmptyName() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        // Act
        viewModel.form.name = ""
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Assert
        #expect(viewModel.isValid == false)
    }
    
    @Test("Form validation - whitespace only name")
    @MainActor
    func testIsValid_WhitespaceOnlyName() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        // Act
        viewModel.form.name = "   "
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Assert
        #expect(viewModel.isValid == false)
    }
    
    @Test("Form validation - end date before start date")
    @MainActor
    func testIsValid_InvalidDates() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        // Act
        viewModel.form.name = "Test"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(-86400) // Yesterday
        
        // Assert
        #expect(viewModel.isValid == false)
    }
    
    @Test("Save charter - create success")
    @MainActor
    func testSaveCharter_CreateSuccess() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        var didDismiss = false
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: { didDismiss = true }
        )
        
        viewModel.form.name = "Test Charter"
        viewModel.form.vessel = "Test Boat"
        viewModel.form.destinationQuery = "Test Location"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        mockRepository.createCharterResult = .success(())
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(mockRepository.createCharterCallCount == 1)
        #expect(mockRepository.lastCreatedCharter?.name == "Test Charter")
        #expect(mockRepository.lastCreatedCharter?.boatName == "Test Boat")
        #expect(mockRepository.lastCreatedCharter?.location == "Test Location")
        #expect(viewModel.isSaving == false)
        #expect(viewModel.currentError == nil)
        #expect(didDismiss == true)
    }
    
    @Test("Save charter - generates name if empty")
    @MainActor
    func testSaveCharter_GeneratesName() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        var didDismiss = false
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: { didDismiss = true }
        )
        
        viewModel.form.name = "" // Empty name
        viewModel.form.destinationQuery = "Greece"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        mockRepository.createCharterResult = .success(())
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(mockRepository.createCharterCallCount == 1)
        #expect(mockRepository.lastCreatedCharter?.name.contains("Greece") == true)
        #expect(didDismiss == true)
    }
    
    @Test("Save charter - create failure propagates error")
    @MainActor
    func testSaveCharter_CreateFailure() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        var didDismiss = false
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: { didDismiss = true }
        )
        
        viewModel.form.name = "Test"
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.createCharterResult = .failure(testError)
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(mockRepository.createCharterCallCount == 1)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.currentError != nil)
        #expect(didDismiss == false)
    }
    
    @Test("Save charter - prevents duplicate saves")
    @MainActor
    func testSaveCharter_PreventsDuplicates() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        viewModel.form.name = "Test"
        mockRepository.createCharterResult = .success(())
        
        // Simulate save in progress
        viewModel.isSaving = true
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        // Should not call repository since save is already in progress
        #expect(mockRepository.createCharterCallCount == 0)
    }
    
    @Test("Save charter - handles nil optional fields")
    @MainActor
    func testSaveCharter_NilOptionalFields() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        viewModel.form.name = "Test Charter"
        viewModel.form.vessel = "" // Empty should become nil
        viewModel.form.destinationQuery = "" // Empty should become nil
        
        mockRepository.createCharterResult = .success(())
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(mockRepository.lastCreatedCharter?.boatName == nil)
        #expect(mockRepository.lastCreatedCharter?.location == nil)
    }
    
    // MARK: - Edit Mode Tests
    
    @Test("Load charter - success")
    @MainActor
    func testLoadCharter_Success() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let charterID = UUID()
        let testCharter = CharterModel(
            id: charterID,
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.fetchCharterResult = .success(testCharter)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: charterID,
            onDismiss: {}
        )
        
        // Act
        await viewModel.loadCharter()
        
        // Assert
        #expect(viewModel.form.name == "Test Charter")
        #expect(viewModel.form.vessel == "Test Boat")
        #expect(viewModel.form.destinationQuery == "Test Location")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentError == nil)
    }
    
    @Test("Load charter - does not load for new charter")
    @MainActor
    func testLoadCharter_DoesNotLoadForNewCharter() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: nil,
            onDismiss: {}
        )
        
        // Act
        await viewModel.loadCharter()
        
        // Assert
        // Should not call fetchCharter for new charters
        // We can't easily verify this without a call count, but we can verify
        // that isLoading remains false and form is unchanged
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Load charter - handles error")
    @MainActor
    func testLoadCharter_HandlesError() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let charterID = UUID()
        let testError = NSError(domain: "TestError", code: 1)
        
        mockRepository.fetchCharterResult = .failure(testError)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: charterID,
            onDismiss: {}
        )
        
        // Act
        await viewModel.loadCharter()
        
        // Assert
        #expect(viewModel.isLoading == false)
        #expect(viewModel.currentError != nil)
    }
    
    @Test("Save charter - update success")
    @MainActor
    func testSaveCharter_UpdateSuccess() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let charterID = UUID()
        var didDismiss = false
        
        let updatedCharter = CharterModel(
            id: charterID,
            name: "Updated Charter",
            boatName: "Updated Boat",
            location: "Updated Location",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.updateCharterResult = .success(updatedCharter)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: charterID,
            onDismiss: { didDismiss = true }
        )
        
        viewModel.form.name = "Updated Charter"
        viewModel.form.vessel = "Updated Boat"
        viewModel.form.destinationQuery = "Updated Location"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(viewModel.isSaving == false)
        #expect(viewModel.currentError == nil)
        #expect(didDismiss == true)
    }
    
    @Test("Save charter - update failure propagates error")
    @MainActor
    func testSaveCharter_UpdateFailure() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let charterID = UUID()
        var didDismiss = false
        
        let testError = NSError(domain: "TestError", code: 1)
        mockRepository.updateCharterResult = .failure(testError)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: charterID,
            onDismiss: { didDismiss = true }
        )
        
        viewModel.form.name = "Test"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(viewModel.isSaving == false)
        #expect(viewModel.currentError != nil)
        #expect(didDismiss == false)
    }
    
    @Test("Save charter - update does not call create")
    @MainActor
    func testSaveCharter_UpdateDoesNotCallCreate() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let charterID = UUID()
        
        let updatedCharter = CharterModel(
            id: charterID,
            name: "Updated",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        mockRepository.updateCharterResult = .success(updatedCharter)
        
        let viewModel = CharterEditorViewModel(
            charterStore: store,
            charterID: charterID,
            onDismiss: {}
        )
        
        viewModel.form.name = "Updated"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        // Should not call createCharter when updating
        #expect(mockRepository.createCharterCallCount == 0)
    }
}

// MARK: - Visibility / Sign-in Tests

@Suite("CharterEditorViewModel Visibility Tests")
struct CharterEditorViewModelVisibilityTests {

    // MARK: - Helpers

    @MainActor
    private func makeViewModel(isAuthenticated: Bool) -> CharterEditorViewModel {
        let store = CharterStore(repository: MockLocalRepository())
        let mockAuth = MockAuthService()
        mockAuth.mockIsAuthenticated = isAuthenticated
        return CharterEditorViewModel(
            charterStore: store,
            authService: mockAuth,
            onDismiss: {}
        )
    }

    // MARK: - onVisibilityChanged

    @Test("onVisibilityChanged - authenticated user can select community")
    @MainActor
    func testOnVisibilityChanged_Authenticated_AllowsNonPrivate() {
        let viewModel = makeViewModel(isAuthenticated: true)
        viewModel.onVisibilityChanged(.community)
        #expect(viewModel.form.visibility == .community)
        #expect(viewModel.showSignIn == false)
    }

    @Test("onVisibilityChanged - authenticated user can select public")
    @MainActor
    func testOnVisibilityChanged_Authenticated_AllowsPublic() {
        let viewModel = makeViewModel(isAuthenticated: true)
        viewModel.onVisibilityChanged(.public)
        #expect(viewModel.form.visibility == .public)
        #expect(viewModel.showSignIn == false)
    }

    @Test("onVisibilityChanged - unauthenticated selecting community shows sign-in")
    @MainActor
    func testOnVisibilityChanged_Unauthenticated_Community_ShowsSignIn() {
        let viewModel = makeViewModel(isAuthenticated: false)
        viewModel.onVisibilityChanged(.community)
        #expect(viewModel.showSignIn == true)
        // Visibility must not have changed yet
        #expect(viewModel.form.visibility == .private)
    }

    @Test("onVisibilityChanged - unauthenticated selecting public shows sign-in")
    @MainActor
    func testOnVisibilityChanged_Unauthenticated_Public_ShowsSignIn() {
        let viewModel = makeViewModel(isAuthenticated: false)
        viewModel.onVisibilityChanged(.public)
        #expect(viewModel.showSignIn == true)
        #expect(viewModel.form.visibility == .private)
    }

    @Test("onVisibilityChanged - unauthenticated selecting private is always allowed")
    @MainActor
    func testOnVisibilityChanged_Unauthenticated_Private_NeverBlocksSignIn() {
        let viewModel = makeViewModel(isAuthenticated: false)
        viewModel.form.visibility = .community  // start at non-private
        viewModel.onVisibilityChanged(.private)
        #expect(viewModel.form.visibility == .private)
        #expect(viewModel.showSignIn == false)
    }

    @Test("onVisibilityChanged - no authService skips sign-in gate")
    @MainActor
    func testOnVisibilityChanged_NoAuthService_UpdatesDirectly() {
        let store = CharterStore(repository: MockLocalRepository())
        let viewModel = CharterEditorViewModel(charterStore: store, onDismiss: {})
        viewModel.onVisibilityChanged(.community)
        #expect(viewModel.form.visibility == .community)
        #expect(viewModel.showSignIn == false)
    }

    // MARK: - onSignInSuccess

    @Test("onSignInSuccess - applies pending visibility and clears sheet flag")
    @MainActor
    func testOnSignInSuccess_AppliesPendingVisibility() {
        let viewModel = makeViewModel(isAuthenticated: false)
        // Trigger the gate so pendingVisibility is stored
        viewModel.onVisibilityChanged(.community)
        #expect(viewModel.showSignIn == true)

        viewModel.onSignInSuccess()

        #expect(viewModel.showSignIn == false)
        #expect(viewModel.form.visibility == .community)
    }

    @Test("onSignInSuccess - called with no pending visibility is a no-op on form")
    @MainActor
    func testOnSignInSuccess_NoPendingVisibility_IsNoOp() {
        let viewModel = makeViewModel(isAuthenticated: true)
        // No pending visibility set
        viewModel.onSignInSuccess()
        #expect(viewModel.showSignIn == false)
        #expect(viewModel.form.visibility == .private)
    }

    // MARK: - onSignInDismiss

    @Test("onSignInDismiss - discards pending visibility and clears sheet flag")
    @MainActor
    func testOnSignInDismiss_DiscardsPendingVisibility() {
        let viewModel = makeViewModel(isAuthenticated: false)
        viewModel.onVisibilityChanged(.public)
        #expect(viewModel.showSignIn == true)

        viewModel.onSignInDismiss()

        #expect(viewModel.showSignIn == false)
        // Visibility stays private (pending selection was discarded)
        #expect(viewModel.form.visibility == .private)
    }
}

