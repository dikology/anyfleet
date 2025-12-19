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
    
    var id: String { errorDescription ?? "unknown" }
    
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

// MARK: - Error Conversion Helpers

extension Error {
    /// Converts any Error to AppError for consistent error handling
    func toAppError() -> AppError {
        if let authError = self as? AuthError {
            return .authenticationError(authError)
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