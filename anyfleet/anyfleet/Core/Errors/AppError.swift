//
//  AppError.swift
//  anyfleet
//
//  Centralized error taxonomy for presenting user-friendly feedback
//

import Foundation

enum AppError: LocalizedError, Identifiable {
    case notFound(entity: String, id: UUID)
    case validationFailed(field: String, reason: String)
    case databaseError(underlying: Error)
    case networkError(NetworkError)
    case authenticationError(AuthError)
    case unknown(Error)
    
    @MainActor
    var id: String { errorDescription ?? "unknown" }
    
    @MainActor
    var errorDescription: String? {
        switch self {
        case .notFound(let entity, let id):
            return String(format: L10n.Error.notFound, entity, id.uuidString)
        case .validationFailed(let field, let reason):
            return String(format: L10n.Error.validationFailed, field, reason)
        case .databaseError(let underlying):
            return String(format: L10n.Error.databaseError, underlying.localizedDescription)
        case .networkError(let networkError):
            return networkError.localizedDescription
        case .authenticationError(let authError):
            return authError.localizedDescription
        case .unknown(let error):
            return String(format: L10n.Error.generic, error.localizedDescription)
        }
    }
    
    @MainActor
    var recoverySuggestion: String? {
        // User-friendly suggestions
        switch self {
        case .notFound:
            return L10n.Error.notFoundRecovery
        case .validationFailed:
            return L10n.Error.validationFailedRecovery
        case .databaseError:
            return L10n.Error.databaseErrorRecovery
        case .networkError(let networkError):
            return networkError.recoverySuggestion
        case .authenticationError(let authError):
            switch authError {
            case .invalidToken:
                return L10n.Error.authInvalidTokenRecovery
            case .networkError:
                return L10n.Error.authNetworkErrorRecovery
            case .invalidResponse:
                return L10n.Error.authInvalidResponseRecovery
            case .unauthorized:
                return L10n.Error.authUnauthorizedRecovery
            }
        case .unknown:
            return L10n.Error.unknownRecovery
        }
    }
}

// Specialized error types
enum ValidationError: LocalizedError {
    case emptyTitle
    case invalidDateRange
    case missingRequiredField(String)
}

enum DatabaseError: LocalizedError {
    case recordNotFound
    case constraintViolation
    case migrationFailed
}

// MARK: - Network Errors

enum NetworkError: LocalizedError {
    case offline
    case timedOut
    case connectionRefused
    case unreachableHost
    case unknown(Error)
    
    @MainActor
    var errorDescription: String? {
        switch self {
        case .offline:
            return L10n.Error.networkOffline
        case .timedOut:
            return L10n.Error.networkTimedOut
        case .connectionRefused:
            return L10n.Error.networkConnectionRefused
        case .unreachableHost:
            return L10n.Error.networkUnreachableHost
        case .unknown(let error):
            return String(format: L10n.Error.networkUnknown, error.localizedDescription)
        }
    }
    
    @MainActor
    var recoverySuggestion: String? {
        switch self {
        case .offline:
            return L10n.Error.networkOfflineRecovery
        case .timedOut:
            return L10n.Error.networkTimedOutRecovery
        case .connectionRefused:
            return L10n.Error.networkConnectionRefusedRecovery
        case .unreachableHost:
            return L10n.Error.networkUnreachableHostRecovery
        case .unknown:
            return L10n.Error.networkUnknownRecovery
        }
    }
}

// MARK: - Library Domain Errors

enum LibraryError: LocalizedError, Equatable {
    case notFound(UUID)
    case invalidState(String)
    case networkUnavailable
    case permissionDenied
    case validationFailed(String)
    case syncFailed(String)
    case invalidContentData(String)
    case unsupportedContentType(String)

    @MainActor
    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return String(format: L10n.Error.libraryNotFound, id.uuidString)
        case .invalidState(let reason):
            return reason
        case .networkUnavailable:
            return L10n.Error.networkOffline
        case .permissionDenied:
            return L10n.Error.authUnauthorized
        case .validationFailed(let reason):
            return String(format: L10n.Error.validationFailed, "content", reason)
        case .syncFailed(let reason):
            return String(format: L10n.Error.librarySyncFailed, reason)
        case .invalidContentData(let reason):
            return String(format: L10n.Error.libraryInvalidContent, reason)
        case .unsupportedContentType(let typeName):
            return "Content type '\(typeName)' is not supported"
        }
    }

    @MainActor
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return L10n.Error.networkOfflineRecovery
        case .permissionDenied:
            return L10n.Error.authUnauthorizedRecovery
        case .notFound:
            return L10n.Error.libraryNotFoundRecovery
        case .syncFailed:
            return L10n.Error.librarySyncFailedRecovery
        case .invalidState, .validationFailed, .invalidContentData:
            return L10n.Error.genericRecovery
        case .unsupportedContentType:
            return "Please use a supported content type such as a checklist."
        }
    }
}

// MARK: - Error Conversion Helpers

extension Error {
    /// Converts any Error to AppError for consistent error handling
    func toAppError() -> AppError {
        if let authError = self as? AuthError {
            return .authenticationError(authError)
        }

        if let libraryError = self as? LibraryError {
            return .unknown(libraryError)
        }

        // Check for URLSession/network errors
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain {
            let networkError: NetworkError
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                networkError = .offline
            case NSURLErrorTimedOut:
                networkError = .timedOut
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                networkError = .connectionRefused
            case NSURLErrorDNSLookupFailed:
                networkError = .unreachableHost
            default:
                networkError = .unknown(self)
            }
            return .networkError(networkError)
        }

        return .unknown(self)
    }
}