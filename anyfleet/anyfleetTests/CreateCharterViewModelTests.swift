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
        #expect(viewModel.saveError == nil)
        #expect(viewModel.isNewCharter == true)
        #expect(didDismiss == false)
    }
    
    @Test("Initialize with custom form - create mode")
    @MainActor
    func testInitializationWithCustomForm_CreateMode() async throws {
        // Arrange
        let mockRepository = MockLocalRepository()
        let store = CharterStore(repository: mockRepository)
        let customForm = CharterFormState(
            name: "Test Charter",
            destination: "Test Location",
            vessel: "Test Boat"
        )
        
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
        #expect(viewModel.form.destination == "Test Location")
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
        #expect(viewModel.loadError == nil)
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
        
        // Act & Assert
        // Default form has startDate, endDate, region, vessel, and guests populated
        // Only name is empty, so 5/6 fields = ~0.833
        let expected = 5.0 / 6.0
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
        
        // Act - Clear optional string fields and set guests to 0
        viewModel.form.name = ""
        viewModel.form.region = ""
        viewModel.form.vessel = ""
        viewModel.form.guests = 0
        // Note: Dates always have values (can't be "empty")
        // So startDate and endDate still count as filled
        
        // Assert
        // Only dates are filled (2/6) = 0.333...
        let expected = 2.0 / 6.0
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
        viewModel.form.region = ""      // Empty
        viewModel.form.vessel = ""      // Empty
        // startDate, endDate, and guests still have default values
        
        // Assert
        // 3 fields filled (startDate, endDate, guests) out of 6 = 0.5
        #expect(viewModel.completionProgress == 0.5)
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
        viewModel.form.destination = "Location"
        viewModel.form.region = "Region"
        viewModel.form.guests = 4
        viewModel.form.startDate = Date().addingTimeInterval(86400) // Tomorrow
        viewModel.form.endDate = Date().addingTimeInterval(172800) // Day after
        
        // Assert
        // All 6 fields filled = 1.0
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
        viewModel.form.destination = "Test Location"
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
        #expect(viewModel.saveError == nil)
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
        viewModel.form.destination = "Greece"
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
        #expect(viewModel.saveError != nil)
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
        viewModel.form.destination = "" // Empty should become nil
        
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
        #expect(viewModel.form.destination == "Test Location")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.loadError == nil)
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
        #expect(viewModel.loadError != nil)
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
        viewModel.form.destination = "Updated Location"
        viewModel.form.startDate = Date()
        viewModel.form.endDate = Date().addingTimeInterval(86400)
        
        // Act
        await viewModel.saveCharter()
        
        // Assert
        #expect(viewModel.isSaving == false)
        #expect(viewModel.saveError == nil)
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
        #expect(viewModel.saveError != nil)
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

