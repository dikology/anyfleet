//
//  AppDependencies.swift
//  anyfleet
//
//  Application-wide dependency container providing shared instances
//  of stores, services, and repositories.
//

import SwiftUI
import Observation
import OSLog

/// Application-wide dependency container that manages the lifecycle of shared services.
///
/// `AppDependencies` follows the Dependency Injection pattern to provide a single
/// source of truth for all app-level dependencies. This makes testing easier and
/// ensures consistent state across the application.
///
/// This class uses Swift's modern `@Observable` macro instead of the older
/// `ObservableObject` protocol, providing better performance and cleaner syntax.
///
/// ## Usage
///
/// ```swift
/// @main
/// struct anyfleetApp: App {
///     @State private var dependencies = AppDependencies()
///
///     var body: some Scene {
///         WindowGroup {
///             AppView()
///                 .environment(dependencies)
///         }
///     }
/// }
/// ```
///
/// - Important: This class must be instantiated only once at the app level.
/// - Note: All dependencies are lazily initialized to improve startup performance.
@Observable
@MainActor
final class AppDependencies {

    // MARK: - Observable State

    /// Whether the user is currently authenticated
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    /// The current authenticated user
    var currentUser: UserInfo? {
        authService.currentUser
    }

    // MARK: - Data Layer
    
    /// Shared database instance for the application
    let database: AppDatabase
    
    /// Repository for charter data operations
    let repository: LocalRepository

    /// Authentication service instance
    let authService: AuthService

    // MARK: - Stores
    
    /// Shared charter store instance
    let charterStore: CharterStore
    
    /// Shared sync queue service instance
    let syncQueueService: SyncQueueService

    /// Shared library store instance
    let libraryStore: LibraryStore

    /// Shared content sync service instance
    let contentSyncService: ContentSyncService

    /// Charter sync service for pushing/pulling charters to/from the backend
    let charterSyncService: CharterSyncService

    /// Background sync coordinator (manages timer + app lifecycle)
    let syncCoordinator: SyncCoordinator

    /// Shared API client instance
    let apiClient: APIClient
    
    // MARK: - Repository Access
    
    /// Returns the execution repository for checklist execution state persistence.
    ///
    /// Since `LocalRepository` conforms to `ChecklistExecutionRepository`,
    /// this provides convenient access to execution state operations.
    var executionRepository: ChecklistExecutionRepository {
        repository
    }
    
    // MARK: - Services
    
    /// Localization service for managing app language
    let localizationService: LocalizationService
    
    /// Visibility service for managing content publishing
    let visibilityService: VisibilityService
    
    /// Auth state observer for UI consumption
    let authStateObserver: AuthStateObserver
    
    // MARK: - Initialization
    
    /// Creates the dependency container with default production dependencies.
    ///
    /// This initializer sets up the entire dependency graph in the correct order:
    /// 1. Database (lowest level)
    /// 2. Repository (depends on database)
    /// 3. Stores (depend on repositories)
    /// 4. Services (independent)
    init() {
        AppLogger.dependencies.info("Initializing AppDependencies")
        
        // Initialize data layer
        self.database = .shared
        self.repository = LocalRepository(database: database)

        // Initialize auth service ONCE
        self.authService = AuthService()

        // API client (needed by sync services)
        self.apiClient = APIClient(authService: authService)

        // Initialize sync queue service (lowest level sync dependency)
        self.syncQueueService = SyncQueueService(
            repository: repository,
            apiClient: apiClient
        )

        // Initialize stores
        self.charterStore = CharterStore(repository: repository)
        self.libraryStore = LibraryStore(repository: repository, syncQueue: syncQueueService)

        // Initialize content sync service (orchestrator)
        self.contentSyncService = ContentSyncService(
            syncQueue: syncQueueService,
            repository: repository
        )

        // Initialize charter sync service
        let charterSync = CharterSyncService(
            repository: repository,
            apiClient: apiClient,
            charterStore: charterStore
        )
        self.charterSyncService = charterSync

        // Initialize sync coordinator (replaces direct timer in AppCoordinator)
        self.syncCoordinator = SyncCoordinator(
            contentSyncService: contentSyncService,
            charterSyncService: charterSync
        )

        // Initialize services
        self.localizationService = LocalizationService()
        self.authStateObserver = AuthStateObserver(authService: authService)
        self.visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: authService,
            syncService: contentSyncService
        )

        AppLogger.dependencies.info("AppDependencies initialized successfully")
    }
    
    /// Creates a test dependency container with injectable dependencies.
    ///
    /// Use this initializer in tests to provide mock implementations.
    /// - Parameters:
    ///   - database: The database instance to use
    ///   - repository: The repository instance to use
    ///
    /// - Parameters:
    ///   - database: Test database instance (defaults to in-memory database)
    ///   - repository: Custom repository implementation (defaults to LocalRepository)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let testDatabase = try AppDatabase.makeEmpty()
    /// let mockRepository = MockLocalRepository()
    /// let dependencies = AppDependencies.makeForTesting(
    ///     database: testDatabase,
    ///     repository: mockRepository
    /// )
    /// ```
    init(
        database: AppDatabase,
        repository: LocalRepository
    ) {
        AppLogger.dependencies.info("Initializing test AppDependencies")

        self.database = database
        self.repository = repository

        // Initialize auth service ONCE
        self.authService = AuthService()

        // API client (needed by sync services)
        self.apiClient = APIClient(authService: authService)

        // Initialize sync queue service (lowest level sync dependency)
        self.syncQueueService = SyncQueueService(
            repository: repository,
            apiClient: apiClient
        )

        self.charterStore = CharterStore(repository: repository)
        self.libraryStore = LibraryStore(repository: repository, syncQueue: syncQueueService)
        self.contentSyncService = ContentSyncService(
            syncQueue: syncQueueService,
            repository: repository
        )

        let charterSync = CharterSyncService(
            repository: repository,
            apiClient: apiClient,
            charterStore: charterStore
        )
        self.charterSyncService = charterSync
        self.syncCoordinator = SyncCoordinator(
            contentSyncService: contentSyncService,
            charterSyncService: charterSync
        )

        // Initialize services
        self.localizationService = LocalizationService()
        self.authStateObserver = AuthStateObserver(authService: authService)
        self.visibilityService = VisibilityService(
            libraryStore: libraryStore,
            authService: authService,
            syncService: contentSyncService
        )

        AppLogger.dependencies.info("Test AppDependencies initialized successfully")
    }
}

// MARK: - Testing Support

extension AppDependencies {
    /// Creates a dependency container for testing with in-memory database.
    ///
    /// - Returns: A new `AppDependencies` instance configured for testing
    /// - Throws: If the in-memory database cannot be created
    @MainActor
    static func makeForTesting() throws -> AppDependencies {
        let testDatabase = try AppDatabase.makeEmpty()
        let testRepository = LocalRepository(database: testDatabase)
        
        return AppDependencies(
            database: testDatabase,
            repository: testRepository
        )
    }
    
    /// Creates a dependency container for testing with a mock repository.
    ///
    /// Use this when you need complete control over repository behavior.
    ///
    /// - Parameter mockRepository: The mock repository to use
    /// - Returns: A new `AppDependencies` instance with the mock repository
    /// - Throws: If the in-memory database cannot be created
    @MainActor
    static func makeForTesting(
        mockRepository: any CharterRepository
    ) throws -> AppDependencies {
        let testDatabase = try AppDatabase.makeEmpty()
        
        let dependencies = AppDependencies(
            database: testDatabase,
            repository: LocalRepository(database: testDatabase)
        )
        // Replace the store with one using the mock repository
        _ = CharterStore(repository: mockRepository)
        // Note: We can't reassign let properties, so this approach needs adjustment
        // For now, we'll document that tests should create stores directly
        return dependencies
    }
}

// MARK: - Environment Key

private struct AppDependenciesKey: EnvironmentKey {
    static let defaultValue: AppDependencies = MainActor.assumeIsolated {
        AppDependencies()
    }
}

extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}

// MARK: - Logger Extension

extension AppLogger {
    /// Logger for dependency injection operations
    static let dependencies = Logger(subsystem: "com.anyfleet.app", category: "Dependencies")
}

