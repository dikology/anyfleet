//
//  TokenRefreshTests.swift
//  anyfleetTests
//
//  Tests for the 401 → token-refresh → retry flow in APIClient,
//  and for the concurrent-refresh deduplication in AuthService.
//

import Foundation
import Testing
@testable import anyfleet

// MARK: - URLProtocol stub

/// Stubs URLSession responses by replaying a FIFO queue keyed on URL path.
/// Register responses with `enqueue` before executing requests; call `reset` between tests.
final class StubURLProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var queues: [String: [(statusCode: Int, body: Data)]] = [:]

    static func enqueue(path: String, statusCode: Int, body: Data = Data()) {
        lock.withLock {
            queues[path, default: []].append((statusCode, body))
        }
    }

    static func reset() {
        lock.withLock { queues.removeAll() }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let pair = Self.lock.withLock {
            Self.queues[path]?.isEmpty == false ? Self.queues[path]!.removeFirst() : nil
        }
        let statusCode = pair?.statusCode ?? 200
        let body = pair?.body ?? Data()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Test helpers

private func makeStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Minimal valid JSON for `CharterListAPIResponse` (empty items list).
private let emptyCharterListJSON = """
{"items":[],"total":0,"limit":20,"offset":0}
""".data(using: .utf8)!

/// Token refresh success payload matching `TokenResponse`.
/// Asserts `operation` throws a given `APIError` case (avoids `#expect(throws:)` + `InferIsolatedConformances`).
private func assertThrowsAPIError(
    _ expected: APIError,
    performing operation: () async throws -> Void
) async {
    do {
        try await operation()
        Issue.record("Expected APIError, but no error was thrown")
    } catch let error as APIError {
        let matches: Bool
        switch (expected, error) {
        case (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound):
            matches = true
        default:
            matches = false
        }
        if !matches {
            Issue.record("Expected \(expected), got \(error)")
        }
    } catch {
        Issue.record("Expected APIError \(expected), got \(error)")
    }
}

private func tokenRefreshJSON(access: String = "new_access", refresh: String = "new_refresh") -> Data {
    """
    {
        "access_token": "\(access)",
        "refresh_token": "\(refresh)",
        "token_type": "bearer",
        "expires_in": 1800,
        "user": {
            "id": "\(UUID().uuidString)",
            "email": "test@example.com",
            "username": "testuser",
            "created_at": "2026-01-01T00:00:00Z"
        }
    }
    """.data(using: .utf8)!
}

// MARK: - APIClient 401 retry tests

/// `fetchMyCharters` hits GET /charters (path `/api/v1/charters` on the simulator base URL).
@Suite("APIClient – 401 token-refresh retry")
struct APIClientTokenRefreshTests {

    // Simulator base URL → full path used by stub
    private let chartersPath = "/api/v1/charters"

    @Test("Successful 200 response does not trigger a token refresh")
    @MainActor
    func testSuccess_noRefresh() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 200, body: emptyCharterListJSON)

        let auth = MockAuthService()
        let client = APIClient(authService: auth, session: makeStubSession())

        _ = try await client.fetchMyCharters()

        #expect(auth.refreshCallCount == 0)
        #expect(auth.getAccessTokenCallCount == 1)
    }

    @Test("401 triggers one refresh then succeeds on retry")
    @MainActor
    func testUnauthorized_refreshAndRetry_succeeds() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 401)
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 200, body: emptyCharterListJSON)

        let auth = MockAuthService()
        let client = APIClient(authService: auth, session: makeStubSession())

        _ = try await client.fetchMyCharters()

        #expect(auth.refreshCallCount == 1, "Exactly one refresh should fire on 401")
        #expect(auth.getAccessTokenCallCount == 2, "Initial token + new token after refresh")
    }

    @Test("When retry also returns 401, throws unauthorized without looping")
    @MainActor
    func testUnauthorized_retryAlso401_throws() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 401)
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 401)

        let auth = MockAuthService()
        let client = APIClient(authService: auth, session: makeStubSession())

        await assertThrowsAPIError(.unauthorized) {
            _ = try await client.fetchMyCharters()
        }
        #expect(auth.refreshCallCount == 1, "Should not loop — one refresh attempt only")
    }

    @Test("When refresh itself fails, throws unauthorized and does not issue retry request")
    @MainActor
    func testUnauthorized_refreshFails_throws() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 401)
        // No second enqueue — if a retry fires the stub returns an empty-queue 200 which
        // would successfully decode as EmptyCharterList and falsely pass.

        let auth = MockAuthService()
        auth.shouldFailRefresh = true
        let client = APIClient(authService: auth, session: makeStubSession())

        await assertThrowsAPIError(.unauthorized) {
            _ = try await client.fetchMyCharters()
        }
        #expect(auth.refreshCallCount == 1)
        // getAccessToken was called once (before the 401); not called again because refresh failed
        #expect(auth.getAccessTokenCallCount == 1)
    }

    @Test("403 Forbidden is not retried and does not call refresh")
    @MainActor
    func test403_noRefresh() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 403)

        let auth = MockAuthService()
        let client = APIClient(authService: auth, session: makeStubSession())

        await assertThrowsAPIError(.forbidden) {
            _ = try await client.fetchMyCharters()
        }
        #expect(auth.refreshCallCount == 0)
    }

    @Test("404 Not Found is not retried and does not call refresh")
    @MainActor
    func test404_noRefresh() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 404)

        let auth = MockAuthService()
        let client = APIClient(authService: auth, session: makeStubSession())

        await assertThrowsAPIError(.notFound) {
            _ = try await client.fetchMyCharters()
        }
        #expect(auth.refreshCallCount == 0)
    }

    @Test("Fresh token from tokenSequence is sent on retry after 401")
    @MainActor
    func testUnauthorized_freshTokenSentOnRetry() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 401)
        StubURLProtocol.enqueue(path: chartersPath, statusCode: 200, body: emptyCharterListJSON)

        let auth = MockAuthService()
        auth.tokenSequence = ["expired_token", "fresh_token_after_refresh"]
        let client = APIClient(authService: auth, session: makeStubSession())

        _ = try await client.fetchMyCharters()

        // Both tokens were consumed
        #expect(auth.tokenSequence.isEmpty, "Both tokens in sequence should be consumed")
        #expect(auth.getAccessTokenCallCount == 2)
    }
}

// MARK: - AuthService concurrent refresh deduplication

@Suite("AuthService – concurrent refresh deduplication")
struct AuthServiceRefreshDeduplicationTests {

    /// Verifies that two concurrent calls to `refreshAccessToken()` result in exactly one
    /// network round-trip. The backend uses rotating single-use refresh tokens, so a second
    /// network call would consume an already-invalidated token and force a logout.
    @Test("Concurrent refreshAccessToken calls coalesce into a single network request")
    @MainActor
    func testConcurrentRefresh_firesOnce() async throws {
        StubURLProtocol.reset()

        // Enqueue exactly ONE valid response.  If two requests fire, the second gets an
        // empty-queue 200 with an empty body, which fails to decode TokenResponse and surfaces
        // a decoding error — making the concurrency bug visible.
        StubURLProtocol.enqueue(
            path: "/api/v1/auth/refresh",
            statusCode: 200,
            body: tokenRefreshJSON(access: "fresh_access", refresh: "fresh_refresh")
        )

        let keychain = KeychainService.shared
        keychain.saveRefreshToken("seed_refresh_token")
        keychain.deleteAccessToken()
        defer {
            keychain.deleteAccessToken()
            keychain.deleteRefreshToken()
        }

        let authService = AuthService(session: makeStubSession())

        // Fire two concurrent refresh calls from the main actor.
        // When task A suspends at `await session.data(for:)`, task B runs and sees
        // `tokenRefreshTask != nil` — it awaits the same task instead of making a new request.
        async let first: Void = authService.refreshAccessToken()
        async let second: Void = authService.refreshAccessToken()
        try await first
        try await second

        #expect(keychain.getAccessToken() == "fresh_access", "Access token should be updated")
        #expect(keychain.getRefreshToken() == "fresh_refresh", "Refresh token should rotate")
    }

    @Test("getAccessToken returns stored token without triggering a network refresh")
    @MainActor
    func testGetAccessToken_storedToken_noNetwork() async throws {
        let keychain = KeychainService.shared
        keychain.saveAccessToken("already_valid_token")
        defer { keychain.deleteAccessToken() }

        let authService = AuthService()
        let token = try await authService.getAccessToken()

        #expect(token == "already_valid_token")
    }

    @Test("getAccessToken refreshes when no access token is stored")
    @MainActor
    func testGetAccessToken_noToken_triggersRefresh() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.enqueue(
            path: "/api/v1/auth/refresh",
            statusCode: 200,
            body: tokenRefreshJSON(access: "refreshed_token", refresh: "new_refresh")
        )

        let keychain = KeychainService.shared
        keychain.deleteAccessToken()
        keychain.saveRefreshToken("valid_refresh_token")
        defer {
            keychain.deleteAccessToken()
            keychain.deleteRefreshToken()
        }

        let authService = AuthService(session: makeStubSession())
        let token = try await authService.getAccessToken()

        #expect(token == "refreshed_token")
    }
}
