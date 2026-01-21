//
//  AuthStateObserver.swift
//  anyfleet
//
//  Observable wrapper for AuthService state
//

import Foundation
import Observation
import OSLog

/// Protocol defining the interface for authentication state observation.
/// Used for dependency injection and testing.
protocol AuthStateObserverProtocol: AnyObject {
    var isSignedIn: Bool { get }
    var currentUser: UserInfo? { get }
    var currentUserID: UUID? { get }
}

/// Observable wrapper that exposes AuthService state for UI consumption
///
/// This class provides a clean interface for views to observe authentication state
/// without directly depending on AuthService. It uses the @Observable macro to
/// automatically notify SwiftUI views when authentication state changes.
@MainActor
@Observable
final class AuthStateObserver: AuthStateObserverProtocol {
    private let authService: AuthService
    
    /// Whether the user is currently signed in
    var isSignedIn: Bool {
        authService.isAuthenticated
    }
    
    /// The current authenticated user, or nil if not signed in
    var currentUser: UserInfo? {
        let user = authService.currentUser
        // Debug: Log when currentUser is accessed
        if let user = user {
            AppLogger.auth.debug("AuthStateObserver.currentUser accessed: \(user.username ?? "nil") with image: \(user.profileImageUrl ?? "nil")")
        } else {
            AppLogger.auth.debug("AuthStateObserver.currentUser accessed: nil")
        }
        return user
    }
    
    /// User's email address, if available
    var userEmail: String? {
        currentUser?.email
    }
    
    /// User's username, if available
    var username: String? {
        currentUser?.username
    }

    /// The current user's ID, if available
    var currentUserID: UUID? {
        guard let idString = currentUser?.id else { return nil }
        return UUID(uuidString: idString)
    }
    
    // MARK: - Initialization
    
    /// Creates an AuthStateObserver
    /// - Parameter authService: The AuthService to observe
    init(authService: AuthService) {
        self.authService = authService
        AppLogger.auth.debug("AuthStateObserver initialized")
    }
}

