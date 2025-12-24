//
//  MockAuthService.swift
//  anyfleetTests
//
//  Mock auth service for unit testing
//

import Foundation
@testable import anyfleet

/// Mock auth service that implements AuthServiceProtocol for testing
final class MockAuthService: AuthServiceProtocol {
    var mockAccessToken: String = "mock_access_token_123"
    var shouldFail = false
    var getAccessTokenCallCount = 0
    var mockIsAuthenticated = true
    var mockCurrentUser: UserInfo?

    var isAuthenticated: Bool {
        mockIsAuthenticated
    }

    var currentUser: UserInfo? {
        mockCurrentUser
    }

    func getAccessToken() async throws -> String {
        getAccessTokenCallCount += 1
        if shouldFail {
            throw AuthError.invalidToken
        }
        return mockAccessToken
    }
}
