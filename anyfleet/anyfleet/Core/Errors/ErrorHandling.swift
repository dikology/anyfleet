//
//  ErrorHandling.swift
//  anyfleet
//
//  Unified error handling protocol for ViewModels
//

import Foundation
import Observation

/// Protocol for ViewModels that need to handle and display errors
@MainActor
protocol ErrorHandling: AnyObject {
    /// The current error to display, if any
    var currentError: AppError? { get set }

    /// Whether to show the error banner
    var showErrorBanner: Bool { get set }

    /// Handle an error by setting it as the current error and showing the banner
    func handleError(_ error: AppError)

    /// Handle a raw Error by converting it to AppError and showing the banner
    func handleError(_ error: Error)

    /// Clear the current error and hide the banner
    func clearError()

    /// Handle an error with an optional retry action
    func handleError(_ error: AppError, retryAction: (() -> Void)?)
}

// MARK: - Default Implementation

extension ErrorHandling {
    func handleError(_ error: AppError) {
        currentError = error
        showErrorBanner = true
        AppLogger.view.error("Error handled: \(error.localizedDescription)")
    }

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        handleError(appError)
    }

    func clearError() {
        currentError = nil
        showErrorBanner = false
    }

    func handleError(_ error: AppError, retryAction: (() -> Void)?) {
        handleError(error)
        // Store retry action if needed for ErrorBanner component
    }
}

