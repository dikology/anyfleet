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
    case unknown(Error)
    
    var id: String { errorDescription ?? "unknown" }
    
    var errorDescription: String? {
        switch self {
        case .notFound(let entity, let id):
            return "\(entity) with ID \(id.uuidString) not found"
        case .validationFailed(let field, let reason):
            return "\(field): \(reason)"
        case .databaseError(let underlying):
            return "Database error: \(underlying.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        // User-friendly suggestions
        switch self {
        case .notFound:
            return "The requested item was not found."
        case .validationFailed:
            return "The input failed validation. Please check the fields and try again."
        case .databaseError:
            return "The database operation failed. Please try again later."
        case .unknown:
            return "An unknown error occurred. Please try again later."
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