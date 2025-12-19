//
//  AuthStateObserver.swift
//  anyfleet
//
//  Observable wrapper for AuthService state
//

import Foundation
import Observation
import OSLog

/// Observable wrapper that exposes AuthService state for UI consumption
///
/// This class provides a clean interface for views to observe authentication state
/// without directly depending on AuthService. It uses the @Observable macro to
/// automatically notify SwiftUI views when authentication state changes.
@MainActor
@Observable
final class AuthStateObserver {
    private let authService: AuthService
    
    /// Whether the user is currently signed in
    var isSignedIn: Bool {
        authService.isAuthenticated
    }
    
    /// The current authenticated user, or nil if not signed in
    var currentUser: UserInfo? {
        authService.currentUser
    }
    
    /// User's email address, if available
    var userEmail: String? {
        currentUser?.email
    }
    
    /// User's username, if available
    var username: String? {
        currentUser?.username
    }
    
    // MARK: - Initialization
    
    /// Creates an AuthStateObserver
    /// - Parameter authService: The AuthService to observe
    init(authService: AuthService) {
        self.authService = authService
        AppLogger.auth.debug("AuthStateObserver initialized")
    }
}

