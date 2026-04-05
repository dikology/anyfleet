//
//  CharterEditorViewModel.swift
//  anyfleet
//
//  ViewModel for charter editing flow.
//

import Foundation
import Observation
import CoreLocation
import SwiftUI

/// ViewModel managing the charter editing flow.
///
/// Handles form state, validation, progress tracking, and save operations
/// for editing charters.
///
/// When the user selects a non-private visibility while unauthenticated,
/// `showSignIn` becomes `true` and `form.visibility` is held at its previous
/// value. After a successful sign-in (`onSignInSuccess()`) the originally
/// intended visibility is applied. Dismissing the sheet (`onSignInDismiss()`)
/// discards the pending selection.
///
/// ## Usage
///
/// ```swift
/// struct CharterEditorView: View {
///     @State private var viewModel: CharterEditorViewModel
///
///     var body: some View {
///         // View implementation
///     }
/// }
/// ```
@MainActor
@Observable
final class CharterEditorViewModel: ErrorHandling {
    // MARK: - Dependencies

    private let charterStore: CharterStore
    private let charterSyncService: CharterSyncService?
    private let authService: (any AuthServiceProtocol)?
    private let apiClient: (any APIClientProtocol)?
    let locationSearchService: any LocationSearchService
    private let charterID: UUID?
    private let onDismiss: () -> Void
    private let presentToast: ((String, ToastVariant) -> Void)?
    private let storeReviewPrompt: (any StoreReviewPrompting)?

    // MARK: - Community manager (publish on behalf)

    var managedCommunities: [ManagedCommunity] = []
    var selectedVirtualCaptain: VirtualCaptain?
    var showVirtualCaptainPicker = false

    var isCommunityManager: Bool { !managedCommunities.isEmpty }

    var selectedVirtualCaptainCommunity: ManagedCommunity? {
        guard let vc = selectedVirtualCaptain else { return nil }
        return managedCommunities.first { $0.id == vc.communityId }
    }
    
    // MARK: - State
    
    /// The current form state
    var form: CharterFormState
    
    /// Whether a save operation is in progress
    var isSaving = false

    /// Whether a load operation is in progress
    var isLoading = false

    var currentError: AppError?
    var showErrorBanner: Bool = false

    /// `true` while the sign-in sheet should be presented.
    var showSignIn = false

    /// Visibility the user intended before auth was required.
    /// Applied to `form.visibility` on successful sign-in.
    private var pendingVisibility: CharterVisibility?
    
    /// Progress through the form (0.0 to 1.0)
    var completionProgress: Double {
        calculateProgress()
    }

    /// Whether the charter is new
    var isNewCharter: Bool {
        charterID == nil
    }
    
    /// Whether the form is valid and can be saved
    var isValid: Bool {
        !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        form.endDate >= form.startDate
    }
    
    // MARK: - Initialization
    
    /// Creates a new CharterEditorViewModel.
    ///
    /// - Parameters:
    ///   - charterStore: The charter store for editing charters
    ///   - charterSyncService: Optional sync service for pushing charters
    ///   - authService: Optional auth service used to gate non-private visibility selection
    ///   - locationSearchService: Place search service for destination autocomplete
    ///   - charterID: The ID of the charter to edit
    ///   - onDismiss: Callback to dismiss the view after successful save
    ///   - presentToast: Optional global toast after a successful save
    ///   - storeReviewPrompt: Optional handler for App Store review prompts after a successful save
    ///   - initialForm: Initial form state (if nil, creates empty form)
    init(
        charterStore: CharterStore,
        charterSyncService: CharterSyncService? = nil,
        authService: (any AuthServiceProtocol)? = nil,
        apiClient: (any APIClientProtocol)? = nil,
        locationSearchService: any LocationSearchService = MKLocationSearchService(),
        charterID: UUID? = nil,
        onDismiss: @escaping () -> Void,
        presentToast: ((String, ToastVariant) -> Void)? = nil,
        storeReviewPrompt: (any StoreReviewPrompting)? = nil,
        initialForm: CharterFormState? = nil
    ) {
        self.charterStore = charterStore
        self.charterSyncService = charterSyncService
        self.authService = authService
        self.apiClient = apiClient
        self.locationSearchService = locationSearchService
        self.charterID = charterID
        self.onDismiss = onDismiss
        self.presentToast = presentToast
        self.storeReviewPrompt = storeReviewPrompt
        self.form = initialForm ?? CharterFormState()
    }
    
    // MARK: - Actions

    /// Loads the charter from the charter store.
    func loadCharter() async {
        guard let charterID = charterID, !isNewCharter else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let charter = try await charterStore.fetchCharter(charterID)
            form.name = charter.name
            form.startDate = charter.startDate
            form.endDate = charter.endDate
            form.vessel = charter.boatName ?? ""
            form.visibility = charter.visibility

            // Restore geocoded place if coordinates were previously saved
            if let lat = charter.latitude,
               let lon = charter.longitude,
               let locationText = charter.location {
                form.selectedPlace = PlaceResult(
                    id: charter.locationPlaceID ?? "\(lat),\(lon)",
                    name: locationText,
                    subtitle: "",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    countryCode: nil
                )
                form.destinationQuery = locationText
            } else {
                form.destinationQuery = charter.location ?? ""
            }
        } catch {
            handleError(error)
        }
    }

    func loadManagedCommunities() async {
        guard let apiClient, authService?.isAuthenticated == true else {
            managedCommunities = []
            return
        }
        do {
            managedCommunities = try await apiClient.getManagedCommunities()
        } catch {
            managedCommunities = []
        }
    }

    /// After `loadCharter` and `loadManagedCommunities`, maps stored `onBehalfOfVirtualCaptainID` to `selectedVirtualCaptain`.
    func resolveVirtualCaptainSelectionFromStore() async {
        guard let charterID, let apiClient else {
            selectedVirtualCaptain = nil
            return
        }
        guard let charter = try? await charterStore.fetchCharter(charterID),
              let targetID = charter.onBehalfOfVirtualCaptainID
        else {
            selectedVirtualCaptain = nil
            return
        }
        for community in managedCommunities {
            do {
                let response = try await apiClient.listVirtualCaptains(communityId: community.id, limit: 100, offset: 0)
                if let match = response.items.first(where: { $0.id == targetID }) {
                    selectedVirtualCaptain = match
                    return
                }
            } catch {
                continue
            }
        }
        selectedVirtualCaptain = nil
    }
    
    /// Saves the charter and dismisses the view on success.
    func saveCharter() async {
        AppLogger.view.startOperation("Save Charter")

        guard !isSaving else {
            AppLogger.view.warning("Save already in progress, ignoring duplicate request")
            return
        }

        isSaving = true
        defer { isSaving = false }
        
        do {
            if isNewCharter {
                let charterName = form.name.isEmpty
                    ? "\(form.destinationText.isEmpty ? "Charter" : form.destinationText) - \(form.dateSummary)"
                    : form.name
                
                AppLogger.view.info("Creating charter with name: '\(charterName)'")
                AppLogger.view.debug("Charter details - boatName: \(form.vessel.isEmpty ? "nil" : form.vessel), location: \(form.destinationText.isEmpty ? "nil" : form.destinationText), startDate: \(form.startDate), endDate: \(form.endDate)")
                
                var charter = try await charterStore.createCharter(
                    name: charterName,
                    boatName: form.vessel.isEmpty ? nil : form.vessel,
                    location: form.destinationText.isEmpty ? nil : form.destinationText,
                    latitude: form.selectedPlace?.coordinate.latitude,
                    longitude: form.selectedPlace?.coordinate.longitude,
                    locationPlaceID: form.selectedPlace?.id,
                    startDate: form.startDate,
                    endDate: form.endDate,
                    checkInChecklistID: nil
                )

                if form.visibility != .private {
                    charter.visibility = form.visibility
                    charter.needsSync = true
                    charter.onBehalfOfVirtualCaptainID = selectedVirtualCaptain?.id
                    try await charterStore.saveCharter(charter)
                    await charterSyncService?.pushPendingCharters()
                }

                AppLogger.view.info("Charter created successfully with ID: \(charter.id.uuidString)")
                AppLogger.view.completeOperation("Save Charter")

                HapticEngine.notification(.success)
                presentToast?(L10n.Toast.charterSaved, .success)
                scheduleReviewPromptAfterCharterSave()
                onDismiss()
            } else {
                guard let charterID = charterID else { return }
                let onBehalf = form.visibility == .private ? nil : selectedVirtualCaptain?.id
                let charter = try await charterStore.updateCharter(
                    charterID,
                    name: form.name,
                    boatName: form.vessel.isEmpty ? nil : form.vessel,
                    location: form.destinationText.isEmpty ? nil : form.destinationText,
                    latitude: form.selectedPlace?.coordinate.latitude,
                    longitude: form.selectedPlace?.coordinate.longitude,
                    locationPlaceID: form.selectedPlace?.id,
                    startDate: form.startDate,
                    endDate: form.endDate,
                    checkInChecklistID: nil,
                    onBehalfOfVirtualCaptainID: onBehalf
                )

                // For any non-private charter, updateVisibility sets needsSync = true (idempotent
                // when visibility hasn't changed) and triggers an immediate push. This ensures
                // field edits (name, vessel, dates) on shared charters sync right away instead of
                // waiting up to 5 minutes for the SyncCoordinator timer.
                if form.visibility != .private {
                    try await charterStore.updateVisibility(charterID, visibility: form.visibility)
                    await charterSyncService?.pushPendingCharters()
                } else if charter.visibility != .private {
                    // Transitioning from non-private to private: update visibility only, no push.
                    try await charterStore.updateVisibility(charterID, visibility: .private)
                }

                AppLogger.view.info("Charter updated successfully with ID: \(charter.id.uuidString)")
                AppLogger.view.completeOperation("Save Charter")

                HapticEngine.notification(.success)
                presentToast?(L10n.Toast.charterSaved, .success)
                scheduleReviewPromptAfterCharterSave()
                onDismiss()
            }
        } catch {
            AppLogger.view.failOperation("Save Charter", error: error)
            handleError(error)
        }
    }
    
    // MARK: - Visibility / Sign-in

    /// Called whenever the user picks a visibility option.
    ///
    /// If `newVisibility` is non-private and the user is not authenticated,
    /// the selection is held in `pendingVisibility`, `form.visibility` is
    /// unchanged, and `showSignIn` is set to `true` so the view can present
    /// the sign-in sheet.
    func onVisibilityChanged(_ newVisibility: CharterVisibility) {
        if newVisibility == .private {
            selectedVirtualCaptain = nil
        }
        if newVisibility != .private, let authService, !authService.isAuthenticated {
            pendingVisibility = newVisibility
            showSignIn = true
            return
        }
        form.visibility = newVisibility
    }

    /// Called by the view when the sign-in sheet reports success.
    /// Applies the pending visibility the user originally intended.
    func onSignInSuccess() {
        showSignIn = false
        if let pending = pendingVisibility {
            form.visibility = pending
            pendingVisibility = nil
        }
    }

    /// Called by the view when the sign-in sheet is dismissed without signing in.
    /// Discards the pending visibility selection.
    func onSignInDismiss() {
        showSignIn = false
        pendingVisibility = nil
    }

    /// Defers the system review sheet slightly so the success toast and dismiss animation register first.
    private func scheduleReviewPromptAfterCharterSave() {
        guard storeReviewPrompt != nil else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            storeReviewPrompt?.considerPrompt(after: .charterSavedSuccessfully)
        }
    }

    // MARK: - Private Helpers
    
    private static let totalProgressFields = 5.0

    private func calculateProgress() -> Double {
        var count = 0.0
        if !form.name.isEmpty { count += 1 }
        if form.startDate != .now { count += 1 }
        if form.endDate != .now { count += 1 }
        if !form.vessel.isEmpty { count += 1 }
        if form.selectedPlace != nil || !form.destinationQuery.isEmpty { count += 1 }
        return count / CharterEditorViewModel.totalProgressFields
    }
}
