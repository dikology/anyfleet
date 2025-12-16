//
//  CreateCharterViewModel.swift
//  anyfleet
//
//  ViewModel for charter creation flow.
//

import Foundation
import Observation

/// ViewModel managing the charter creation flow.
///
/// Handles form state, validation, progress tracking, and save operations
/// for creating new charters.
///
/// ## Usage
///
/// ```swift
/// struct CreateCharterView: View {
///     @State private var viewModel: CreateCharterViewModel
///
///     var body: some View {
///         // View implementation
///     }
/// }
/// ```
@MainActor
@Observable
final class CreateCharterViewModel {
    // MARK: - Dependencies
    
    private let charterStore: CharterStore
    private let onDismiss: () -> Void
    
    // MARK: - State
    
    /// The current form state
    var form: CharterFormState
    
    /// Whether a save operation is in progress
    var isSaving = false
    
    /// Error that occurred during save, if any
    var saveError: Error?
    
    /// Progress through the form (0.0 to 1.0)
    var completionProgress: Double {
        calculateProgress()
    }
    
    /// Whether the form is valid and can be saved
    var isValid: Bool {
        !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        form.endDate >= form.startDate
    }
    
    // MARK: - Initialization
    
    /// Creates a new CreateCharterViewModel.
    ///
    /// - Parameters:
    ///   - charterStore: The charter store for saving charters
    ///   - onDismiss: Callback to dismiss the view after successful save
    ///   - initialForm: Initial form state (defaults to empty form)
    init(
        charterStore: CharterStore,
        onDismiss: @escaping () -> Void,
        initialForm: CharterFormState = .init()
    ) {
        self.charterStore = charterStore
        self.onDismiss = onDismiss
        self.form = initialForm
    }
    
    // MARK: - Actions
    
    /// Saves the charter and dismisses the view on success.
    func saveCharter() async {
        AppLogger.view.startOperation("Save Charter")
        
        guard !isSaving else {
            AppLogger.view.warning("Save already in progress, ignoring duplicate request")
            return
        }
        
        isSaving = true
        saveError = nil
        
        do {
            // Generate a name if not provided
            let charterName = form.name.isEmpty 
                ? "\(form.destination.isEmpty ? "Charter" : form.destination) - \(form.dateSummary)"
                : form.name
            
            AppLogger.view.info("Creating charter with name: '\(charterName)'")
            AppLogger.view.debug("Charter details - boatName: \(form.vessel.isEmpty ? "nil" : form.vessel), location: \(form.destination.isEmpty ? "nil" : form.destination), startDate: \(form.startDate), endDate: \(form.endDate)")
            
            let charter = try await charterStore.createCharter(
                name: charterName,
                boatName: form.vessel.isEmpty ? nil : form.vessel,
                location: form.destination.isEmpty ? nil : form.destination,
                startDate: form.startDate,
                endDate: form.endDate,
                checkInChecklistID: nil
            )
            
            AppLogger.view.info("Charter created successfully with ID: \(charter.id.uuidString)")
            AppLogger.view.completeOperation("Save Charter")
            
            // Reset saving state before dismissing
            isSaving = false
            onDismiss()
        } catch {
            AppLogger.view.failOperation("Save Charter", error: error)
            saveError = error
            isSaving = false
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateProgress() -> Double {
        let total = 6.0
        var count = 0.0
        if !form.name.isEmpty { count += 1 }
        if form.startDate != .now { count += 1 }
        if form.endDate != .now { count += 1 }
        if !form.region.isEmpty { count += 1 }
        if !form.vessel.isEmpty { count += 1 }
        if form.guests > 0 { count += 1 }
        return count / total
    }
}

