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
    func charterListView_builds() throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let viewModel = CharterListViewModel(charterStore: dependencies.charterStore, coordinator: coordinator)

        // Act & Assert - creating the view with viewModel and environment objects should not throw
        #expect(throws: Never.self) {
            let view = CharterListView(viewModel: viewModel)
                .environment(\.appDependencies, dependencies)
                .environment(\.appCoordinator, coordinator)
            // View creation with environment objects succeeds
            _ = view
        }
    }

    @Test("CharterListView builds with custom viewModel")
    @MainActor
    func charterListView_buildsWithCustomViewModel() throws {
        // Arrange
        let dependencies = try AppDependencies.makeForTesting()
        let coordinator = AppCoordinator(dependencies: dependencies)
        let viewModel = CharterListViewModel(charterStore: dependencies.charterStore, coordinator: coordinator)

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