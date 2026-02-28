//
//  AppDependenciesTests.swift
//  anyfleetTests
//
//  Unit tests for AppDependencies dependency injection container
//

import Foundation
import Testing
import GRDB
@testable import anyfleet

@Suite("AppDependencies Tests")
struct AppDependenciesTests {
    
    @Test("AppDependencies initialization - creates all dependencies")
    @MainActor
    func testInitialization() async throws {
        // Act
        let dependencies = AppDependencies()
        
        // Assert - verify all dependencies are initialized properly
        #expect(dependencies.database === AppDatabase.shared)
        #expect(dependencies.charterStore.charters.isEmpty)  // Initial state
        
        // Verify localization service has a valid language
        let language = dependencies.localizationService.effectiveLanguage
        #expect(language == .english || language == .russian)
    }
    
    @Test("AppDependencies - database is shared instance")
    @MainActor
    func testDatabaseIsSharedInstance() async throws {
        // Arrange
        let dependencies = AppDependencies()
        
        // Act & Assert
        #expect(dependencies.database === AppDatabase.shared)
    }
    
    @Test("AppDependencies - repository uses correct database")
    @MainActor
    func testRepositoryUsesCorrectDatabase() async throws {
        // Arrange - use test database to avoid polluting simulator database
        let dependencies = try AppDependencies.makeForTesting()
        
        // Act - create a charter through the repository
        let charter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: "Test Boat",
            location: "Test Location",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        try await dependencies.repository.createCharter(charter)
        
        // Assert - verify it was saved to the database
        let fetched = try await dependencies.repository.fetchCharter(id: charter.id)
        #expect(fetched?.id == charter.id)
        #expect(fetched?.name == charter.name)
    }
    
    @Test("AppDependencies - charterStore uses correct repository")
    @MainActor
    func testCharterStoreUsesCorrectRepository() async throws {
        // Arrange - use test database to avoid polluting simulator database
        let dependencies = try AppDependencies.makeForTesting()
        
        // Act - create a charter through the store
        let charter = try await dependencies.charterStore.createCharter(
            name: "Store Test Charter",
            boatName: "Store Test Boat",
            location: "Store Test Location",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7)
        )
        
        // Assert - verify it's in the store's cache
        #expect(dependencies.charterStore.charters.contains { $0.id == charter.id })
        
        // Assert - verify it was persisted to the database
        let fetched = try await dependencies.repository.fetchCharter(id: charter.id)
        #expect(fetched?.id == charter.id)
    }
    
    @Test("AppDependencies.makeForTesting - creates test dependencies")
    func testMakeForTesting() async throws {
        // Act
        let dependencies = try await AppDependencies.makeForTesting()
        
        // Assert - verify test dependencies are properly initialized
        await MainActor.run {
            #expect(dependencies.database !== AppDatabase.shared)  // Different instance
            #expect(dependencies.charterStore.charters.isEmpty)  // Clean state
            
            // Verify localization service has a valid language
            let language = dependencies.localizationService.effectiveLanguage
            #expect(language == .english || language == .russian)
        }
    }
    
    @Test("AppDependencies.makeForTesting - uses in-memory database")
    func testMakeForTestingUsesInMemoryDatabase() async throws {
        // Arrange
        let dependencies = try await AppDependencies.makeForTesting()
        
        // Act - create a charter in the test database
        let charter = CharterModel(
            id: UUID(),
            name: "Test Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        try await dependencies.repository.createCharter(charter)
        
        // Assert - verify it's isolated from the shared database
        let fetched = try await dependencies.repository.fetchCharter(id: charter.id)
        #expect(fetched?.id == charter.id)
        
        // Verify it's NOT in the shared database
        let sharedFetched = try await AppDatabase.shared.dbWriter.read { db in
            try CharterRecord
                .filter(CharterRecord.Columns.id == charter.id.uuidString)
                .fetchOne(db)
        }
        #expect(sharedFetched == nil)
    }
    
    @Test("AppDependencies - single instance pattern")
    @MainActor
    func testSingleInstancePattern() async throws {
        // Arrange - use test database to avoid polluting simulator database
        // Note: This test demonstrates that separate instances share the same database
        let testDatabase = try AppDatabase.makeEmpty()
        let repository = LocalRepository(database: testDatabase)
        let dependencies1 = AppDependencies(database: testDatabase, repository: repository)
        let dependencies2 = AppDependencies(database: testDatabase, repository: repository)
        
        // Act - create a charter in first instance
        let charter = try await dependencies1.charterStore.createCharter(
            name: "Test Charter",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        // Assert - verify it's NOT automatically in the second instance
        // (This demonstrates why we need a single instance at app level)
        #expect(dependencies2.charterStore.charters.isEmpty)
        
        // But after loading, it should be there (from shared test database)
        try await dependencies2.charterStore.loadCharters()
        #expect(dependencies2.charterStore.charters.contains { $0.id == charter.id })
    }
    
    @Test("AppDependencies.shared - always returns the same instance (singleton)")
    @MainActor
    func testSharedIsSingleton() {
        let first = AppDependencies.shared
        let second = AppDependencies.shared
        // Reference equality: both must be the exact same object.
        // If they differ, two SyncCoordinators run concurrently and each pushes
        // pending charters, causing duplicate server records.
        #expect(first === second)
    }

    @Test("AppDependencies - localization service is initialized")
    @MainActor
    func testLocalizationServiceInitialized() async throws {
        // Arrange
        let dependencies = AppDependencies()

        // Act & Assert - verify service is functional
        let language = dependencies.localizationService.effectiveLanguage
        #expect(language == .english || language == .russian)

        // Test localization works
        let testString = dependencies.localizationService.localized("home")
        #expect(!testString.isEmpty)
    }

    @Test("AppDependencies - authentication state reactivity")
    @MainActor
    func testAuthenticationStateReactivity() async throws {
        // Arrange - use test dependencies to avoid keychain pollution
        let dependencies = try AppDependencies.makeForTesting()

        // Simulate authentication by directly setting the auth service state
        // (In real usage, this would happen through the AuthService methods)
        dependencies.authService.isAuthenticated = true
        let testUser = UserInfo(
            id: "test-user-id",
            email: "test@example.com",
            username: "testuser",
            createdAt: "2024-01-01T00:00:00Z",
            profileImageUrl: nil,
            profileImageThumbnailUrl: nil,
            bio: nil,
            location: nil,
            nationality: nil,
            profileVisibility: "public"
        )
        dependencies.authService.currentUser = testUser

        // Assert that the computed properties reflect the change
        #expect(dependencies.isAuthenticated == true)
        #expect(dependencies.currentUser?.email == "test@example.com")
        #expect(dependencies.currentUser?.username == "testuser")

        // Simulate logout
        dependencies.authService.isAuthenticated = false
        dependencies.authService.currentUser = nil

        // Assert that the computed properties reflect the logout
        #expect(!dependencies.isAuthenticated)
        #expect(dependencies.currentUser == nil)
    }
}

// MARK: - Integration Tests

@Suite("AppDependencies Integration Tests")
struct AppDependenciesIntegrationTests {
    
    @Test("Full flow - create charter through dependencies")
    @MainActor
    func testFullFlowCreateCharter() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        
        // Act - create charter
        let charter = try await dependencies.charterStore.createCharter(
            name: "Integration Test Charter",
            boatName: "Test Vessel",
            location: "Mediterranean",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            checkInChecklistID: nil
        )
        
        // Assert - verify in store
        #expect(dependencies.charterStore.charters.count == 1)
        #expect(dependencies.charterStore.charters.first?.id == charter.id)
        
        // Assert - verify in database
        let fetched = try await dependencies.repository.fetchCharter(id: charter.id)
        #expect(fetched?.id == charter.id)
        #expect(fetched?.name == "Integration Test Charter")
        #expect(fetched?.boatName == "Test Vessel")
        #expect(fetched?.location == "Mediterranean")
    }
    
    @Test("Full flow - load charters from database")
    @MainActor
    func testFullFlowLoadCharters() async throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        
        // Create some charters directly in the database
        let charter1 = CharterModel(
            id: UUID(),
            name: "Charter 1",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        let charter2 = CharterModel(
            id: UUID(),
            name: "Charter 2",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date(),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        
        try await dependencies.repository.createCharter(charter1)
        try await dependencies.repository.createCharter(charter2)
        
        // Act - load charters into store
        try await dependencies.charterStore.loadCharters()
        
        // Assert
        #expect(dependencies.charterStore.charters.count == 2)
        #expect(dependencies.charterStore.charters.contains { $0.id == charter1.id })
        #expect(dependencies.charterStore.charters.contains { $0.id == charter2.id })
    }
    
    @Test("Dependency graph consistency")
    @MainActor
    func testDependencyGraphConsistency() async throws {
        // Arrange - use test database to avoid polluting simulator database
        let dependencies = try AppDependencies.makeForTesting()
        
        // Act - perform operations through different layers
        let charter = try await dependencies.charterStore.createCharter(
            name: "Consistency Test",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date()
        )
        
        // Assert - verify data is consistent across all layers
        
        // 1. Store has it
        #expect(dependencies.charterStore.charters.contains { $0.id == charter.id })
        
        // 2. Repository can fetch it
        let repoFetch = try await dependencies.repository.fetchCharter(id: charter.id)
        #expect(repoFetch?.id == charter.id)
        
        // 3. Database has it
        let dbFetch = try await dependencies.database.dbWriter.read { db in
            try CharterRecord
                .filter(CharterRecord.Columns.id == charter.id.uuidString)
                .fetchOne(db)
        }
        #expect(dbFetch?.id == charter.id.uuidString)
    }
}

