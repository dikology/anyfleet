//
 //  CharterListViewTests.swift
 //  anyfleetTests
 //
 //  UI tests for CharterListView to ensure proper environment object handling
 //

import Testing
@testable import anyfleet

@Suite("CharterListView UI Tests")
struct CharterListViewTests {

    @Test("CharterListView builds with environment objects")
    @MainActor
    func charterListView_builds() {
        // Arrange
        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)

        // Act & Assert - creating the view with environment objects should not throw
        #expect(throws: Never.self) {
            let view = CharterListView()
                .environment(\.appDependencies, dependencies)
                .environment(\.appCoordinator, coordinator)
            // View creation with environment objects succeeds
            _ = view
        }
    }

    @Test("CharterListView builds with custom viewModel")
    @MainActor
    func charterListView_buildsWithCustomViewModel() {
        // Arrange
        let dependencies = AppDependencies()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let charterStore = CharterStore(repository: LocalRepository())
        let viewModel = CharterListViewModel(charterStore: charterStore, coordinator: coordinator)

        // Act & Assert - creating the view with custom viewModel and environment objects should not throw
        #expect(throws: Never.self) {
            let view = CharterListView(viewModel: viewModel)
                .environment(\.appDependencies, dependencies)
                .environment(\.appCoordinator, coordinator)
            // View creation with custom viewModel and environment objects succeeds
            _ = view
        }
    }
}