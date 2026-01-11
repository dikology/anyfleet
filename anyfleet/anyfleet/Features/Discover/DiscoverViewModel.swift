import Foundation
import Observation

@MainActor
@Observable
final class DiscoverViewModel: ErrorHandling {
    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let libraryStore: LibraryStoreProtocol
    private let coordinator: AppCoordinatorProtocol

    // MARK: - State

    var isLoading = false
    var content: [DiscoverContent] = []
    var currentError: AppError?
    var showErrorBanner: Bool = false

    // MARK: - Computed Properties

    var isEmpty: Bool {
        content.isEmpty && !isLoading
    }

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol,
        libraryStore: LibraryStoreProtocol,
        coordinator: AppCoordinatorProtocol
    ) {
        self.apiClient = apiClient
        self.libraryStore = libraryStore
        self.coordinator = coordinator
    }

    // MARK: - Data Loading

    /// Load discover content from public API
    func loadContent() async {
        guard !isLoading else { return }

        AppLogger.view.startOperation("Load Discover Content")
        isLoading = true
        clearError()

        // Check if we're in UI testing mode and return mock data
        if ProcessInfo.processInfo.environment["UITesting"] == "true" {
            content = mockDiscoverContent()
            AppLogger.view.completeOperation("Load Discover Content")
            AppLogger.view.info("Loaded \(content.count) mock discover items for UI testing")
            isLoading = false
            return
        }

        do {
            let response = try await apiClient.fetchPublicContent()
            content = response.map { DiscoverContent(from: $0) }

            AppLogger.view.completeOperation("Load Discover Content")
            AppLogger.view.info("Loaded \(content.count) discover items")

        } catch {
            AppLogger.view.error("Failed to load discover content", error: error)
            handleError(error)
        }

        isLoading = false
    }

    /// Refresh discover content
    func refresh() async {
        await loadContent()
    }

    // MARK: - Actions

    /// Handle tapping on a content item
    func onContentTapped(_ content: DiscoverContent) {
        AppLogger.view.info("Content tapped: \(content.publicID)")

        // For MVP, navigate to discover content route
        // This will show a placeholder until readers are implemented
        coordinator.push(.discoverContent(content.publicID), to: .discover)
    }

    /// Handle tapping on an author name
    func onAuthorTapped(_ username: String) {
        AppLogger.view.info("Author tapped: \(username)")
        // TODO: Implement author profile navigation/modal
        // For now, this is a placeholder for future implementation
    }

    /// Handle tapping on a fork button
    func onForkTapped(_ content: DiscoverContent) async {
        AppLogger.view.startOperation("Fork Content")
        AppLogger.view.info("Fork tapped: \(content.publicID)")

        do {
            // Fetch full content from backend
            AppLogger.view.info("About to fetch public content for fork: \(content.publicID)")
            let fullContent = try await apiClient.fetchPublicContent(publicID: content.publicID)
            AppLogger.view.info("Fetched full content for fork: \(fullContent.title)")

            // Create forked copy in library
            AppLogger.view.info("About to fork content into library")
            try await libraryStore.forkContent(from: fullContent)
            AppLogger.view.info("Successfully forked content")

            AppLogger.view.completeOperation("Fork Content")

            // Navigate to library tab to show the newly forked content
            coordinator.navigateToLibrary()

        } catch {
            AppLogger.view.error("Fork failed for content \(content.publicID)", error: error)
            handleError(error)
        }
    }

    // MARK: - UI Testing Support

    /// Returns mock discover content for UI testing
    private func mockDiscoverContent() -> [DiscoverContent] {
        [
            DiscoverContent(
                id: UUID(),
                title: "Pre-Departure Safety Checklist",
                description: "Run through this before every sail: weather, rigging, engine, and crew briefing.",
                contentType: .checklist,
                tags: ["safety", "pre-departure", "crew"],
                publicID: "pre-departure-checklist",
                authorUsername: "SailorMaria",
                viewCount: 42,
                forkCount: 2,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 7)
            ),
            DiscoverContent(
                id: UUID(),
                title: "Heavy Weather Tactics",
                description: "Step-by-step guide for reefing, heaving-to, and staying safe when the wind picks up.",
                contentType: .practiceGuide,
                tags: ["heavy weather", "reefing", "safety"],
                publicID: "heavy-weather-tactics",
                authorUsername: "CaptainJohn",
                viewCount: 127,
                forkCount: 1,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 14)
            ),
            DiscoverContent(
                id: UUID(),
                title: "COLREGs Flashcards",
                description: "Flashcards to memorize the most important right-of-way rules and light patterns.",
                contentType: .flashcardDeck,
                tags: ["colregs", "rules", "night"],
                publicID: "colregs-flashcards",
                authorUsername: "NavExpert",
                viewCount: 89,
                forkCount: 0,
                createdAt: Date().addingTimeInterval(-60 * 60 * 24 * 3)
            )
        ]
    }
}
