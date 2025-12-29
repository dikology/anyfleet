import Foundation
import Observation

@MainActor
@Observable
final class DiscoverViewModel: ErrorHandling {
    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let libraryStore: LibraryStore
    private let coordinator: AppCoordinator

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
        libraryStore: LibraryStore,
        coordinator: AppCoordinator
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
            let fullContent = try await apiClient.fetchPublicContent(publicID: content.publicID)
            AppLogger.view.info("Fetched full content for fork: \(fullContent.title)")

            // Create forked copy in library
            try await libraryStore.forkContent(from: fullContent)

            AppLogger.view.completeOperation("Fork Content")

            // Navigate to library tab to show the newly forked content
            coordinator.navigateToLibrary()

        } catch {
            AppLogger.view.error("Fork failed for content \(content.publicID)", error: error)
            handleError(error)
        }
    }
}
