//
//  CharterEditorViewModelTests.swift
//  anyfleetTests
//
//  Tests for the CharterEditorViewModel sync fixes (section 7.1 of refactor-march.md):
//  editing a non-private charter must immediately push, not wait for the SyncCoordinator timer.
//

import Foundation
import Testing
@testable import anyfleet

@Suite("CharterEditorViewModel — sync-on-edit fix (7.1)")
struct CharterEditorViewModelSyncTests {

    // MARK: - Helpers

    @MainActor
    private func makeDependencies(
        charterVisibility: CharterVisibility = .community,
        isAuthenticated: Bool = true
    ) -> (
        repository: MockLocalRepository,
        apiClient: MockAPIClient,
        store: CharterStore,
        charterSyncService: CharterSyncService,
        authService: MockAuthService
    ) {
        let repository = MockLocalRepository()
        let apiClient = MockAPIClient()
        let store = CharterStore(repository: repository)
        let authService = MockAuthService()
        authService.mockIsAuthenticated = isAuthenticated

        let charterSyncService = CharterSyncService(
            repository: repository,
            apiClient: apiClient,
            charterStore: store,
            authService: authService
        )

        // Mock updateCharter to return a charter with the existing (old) visibility
        var existingCharter = CharterModel(
            id: UUID(),
            name: "Old Name",
            boatName: nil,
            location: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            createdAt: Date(),
            checkInChecklistID: nil
        )
        existingCharter.visibility = charterVisibility
        repository.updateCharterResult = .success(existingCharter)

        return (repository, apiClient, store, charterSyncService, authService)
    }

    @MainActor
    private func makeViewModel(
        charterID: UUID,
        repository: MockLocalRepository,
        store: CharterStore,
        charterSyncService: CharterSyncService,
        formVisibility: CharterVisibility = .community
    ) -> CharterEditorViewModel {
        var form = CharterFormState()
        form.name = "New Name"
        form.startDate = Date()
        form.endDate = Date().addingTimeInterval(86400 * 7)
        form.visibility = formVisibility

        return CharterEditorViewModel(
            charterStore: store,
            charterSyncService: charterSyncService,
            charterID: charterID,
            onDismiss: { },
            initialForm: form
        )
    }

    // MARK: - Tests

    @Test("edit non-private charter with unchanged visibility → updateVisibility called and push triggered")
    @MainActor
    func testEditNonPrivateCharter_SameVisibility_PushTriggered() async {
        let charterID = UUID()
        let (repository, _, store, charterSyncService, _) = makeDependencies(charterVisibility: .community)
        let vm = makeViewModel(
            charterID: charterID,
            repository: repository,
            store: store,
            charterSyncService: charterSyncService,
            formVisibility: .community
        )

        await vm.saveCharter()

        // updateVisibility must have been called to set needsSync = true
        #expect(repository.updateCharterVisibilityCallCount >= 1,
                "Editing a non-private charter must call updateVisibility to mark needsSync = true")
        // pushPendingCharters internally calls fetchPendingSyncCharters
        #expect(repository.fetchPendingSyncChartersCallCount >= 1,
                "Editing a non-private charter must trigger an immediate push attempt")
    }

    @Test("edit non-private charter with visibility change → updateVisibility called and push triggered")
    @MainActor
    func testEditNonPrivateCharter_VisibilityChange_PushTriggered() async {
        let charterID = UUID()
        // Old visibility: .community, new: .public
        let (repository, _, store, charterSyncService, _) = makeDependencies(charterVisibility: .community)
        let vm = makeViewModel(
            charterID: charterID,
            repository: repository,
            store: store,
            charterSyncService: charterSyncService,
            formVisibility: .public
        )

        await vm.saveCharter()

        #expect(repository.updateCharterVisibilityCallCount >= 1)
        #expect(repository.lastUpdatedVisibility == .public)
        #expect(repository.fetchPendingSyncChartersCallCount >= 1)
    }

    @Test("edit non-private charter transitioning to private → updateVisibility called, no push")
    @MainActor
    func testEditNonPrivateCharter_ToPrivate_NoPublish() async {
        let charterID = UUID()
        // Old visibility: .community, new: .private
        let (repository, apiClient, store, charterSyncService, _) = makeDependencies(charterVisibility: .community)
        let vm = makeViewModel(
            charterID: charterID,
            repository: repository,
            store: store,
            charterSyncService: charterSyncService,
            formVisibility: .private
        )

        await vm.saveCharter()

        // Visibility must be updated to .private
        #expect(repository.updateCharterVisibilityCallCount >= 1)
        #expect(repository.lastUpdatedVisibility == .private)
        // No API call should be made for a private charter
        #expect(apiClient.createCharterCallCount == 0)
        #expect(apiClient.updateCharterCallCount == 0)
    }

    @Test("edit private charter with no visibility change → no updateVisibility, no push")
    @MainActor
    func testEditPrivateCharter_NoVisibilityChange_NoPush() async {
        let charterID = UUID()
        let (repository, apiClient, store, charterSyncService, _) = makeDependencies(charterVisibility: .private)
        let vm = makeViewModel(
            charterID: charterID,
            repository: repository,
            store: store,
            charterSyncService: charterSyncService,
            formVisibility: .private
        )

        await vm.saveCharter()

        #expect(repository.updateCharterVisibilityCallCount == 0,
                "Private→private edit must not call updateVisibility")
        #expect(repository.fetchPendingSyncChartersCallCount == 0,
                "Private→private edit must not trigger a push")
        #expect(apiClient.createCharterCallCount == 0)
    }
}
