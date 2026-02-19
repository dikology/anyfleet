import Foundation
import AuthenticationServices

/// Protocol for authentication service functionality needed by APIClient and views
protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get }
    var currentUser: UserInfo? { get }
    func getAccessToken() async throws -> String
    func ensureCurrentUserLoaded() async throws
    func logout() async
    func updateProfile(username: String?, bio: String?, location: String?, nationality: String?, profileVisibility: String?) async throws -> UserInfo
    func uploadProfileImage(_ imageData: Data) async throws -> UserInfo
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async throws
}

/// Protocol for API client functionality for testing
protocol APIClientProtocol {
    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String,
        canFork: Bool,
        forkedFromID: UUID?
    ) async throws -> PublishContentResponse

    func unpublishContent(publicID: String) async throws

    func fetchPublicContent() async throws -> [SharedContentSummary]

    func fetchPublicContent(publicID: String) async throws -> SharedContentDetail

    func incrementForkCount(publicID: String) async throws

    func updatePublishedContent(
        publicID: String,
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String
    ) async throws -> UpdateContentResponse

    func fetchPublicProfile(username: String) async throws -> PublicProfileResponse

    // MARK: Charter API

    func createCharter(_ request: CharterCreateRequest) async throws -> CharterAPIResponse
    func fetchMyCharters() async throws -> CharterListAPIResponse
    func fetchCharter(id: UUID) async throws -> CharterAPIResponse
    func updateCharter(id: UUID, request: CharterUpdateRequest) async throws -> CharterAPIResponse
    func deleteCharter(id: UUID) async throws
    func discoverCharters(
        dateFrom: Date?,
        dateTo: Date?,
        nearLat: Double?,
        nearLon: Double?,
        radiusKm: Double,
        limit: Int,
        offset: Int
    ) async throws -> CharterDiscoveryAPIResponse
}

/// API client for authenticated requests to backend
final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let authService: AuthServiceProtocol
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(authService: AuthServiceProtocol) {
        // Environment-based URL
        #if targetEnvironment(simulator)
        self.baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
        #else
        self.baseURL = URL(string: "https://elegant-empathy-production-583b.up.railway.app/api/v1")!
        #endif
        
        self.authService = authService
        self.session = URLSession.shared
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        // REMOVED: keyDecodingStrategy - we use explicit CodingKeys everywhere
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        // REMOVED: keyEncodingStrategy - we use explicit CodingKeys instead
    }
    
    // MARK: - Content Endpoints
    
    func publishContent(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String,
        canFork: Bool,
        forkedFromID: UUID? = nil
    ) async throws -> PublishContentResponse {
        let request = PublishContentRequest(
            title: title,
            description: description,
            contentType: contentType,
            contentData: contentData,
            tags: tags,
            language: language,
            publicID: publicID,
            canFork: canFork,
            forkedFromID: forkedFromID
        )

        return try await post("/content/share", body: request)
    }
    
    func unpublishContent(publicID: String) async throws {
        try await delete("/content/\(publicID)")
    }

    func fetchPublicContent() async throws -> [SharedContentSummary] {
        return try await getUnauthenticated("/content/public", body: EmptyBody())
    }

    func fetchPublicContent(publicID: String) async throws -> SharedContentDetail {
        AppLogger.api.debug("Fetching public content: \(publicID)")
        do {
            let result: SharedContentDetail = try await getUnauthenticated("/content/\(publicID)", body: EmptyBody())
            AppLogger.api.debug("Successfully fetched public content: \(publicID)")
            return result
        } catch {
            AppLogger.api.error("Failed to fetch public content \(publicID)", error: error)
            throw error
        }
    }

    func incrementForkCount(publicID: String) async throws {
        try await postUnauthenticated("/content/\(publicID)/fork", body: EmptyBody())
    }

    func updatePublishedContent(
        publicID: String,
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String
    ) async throws -> UpdateContentResponse {
        let request = UpdateContentRequest(
            title: title,
            description: description,
            contentType: contentType,
            contentData: contentData,
            tags: tags,
            language: language
        )

        return try await put("/content/\(publicID)", body: request)
    }
    
    func fetchPublicProfile(username: String) async throws -> PublicProfileResponse {
        AppLogger.api.debug("Fetching public profile for username: \(username)")
        do {
            let result: PublicProfileResponse = try await getUnauthenticated("/users/\(username)", body: EmptyBody())
            AppLogger.api.debug("Successfully fetched public profile for: \(username)")
            return result
        } catch {
            AppLogger.api.error("Failed to fetch public profile for \(username)", error: error)
            throw error
        }
    }

    // MARK: - Charter Endpoints

    func createCharter(_ request: CharterCreateRequest) async throws -> CharterAPIResponse {
        AppLogger.api.debug("Creating charter: \(request.name)")
        return try await post("/charters", body: request)
    }

    func fetchMyCharters() async throws -> CharterListAPIResponse {
        AppLogger.api.debug("Fetching user's charters")
        return try await get("/charters", body: EmptyBody())
    }

    func fetchCharter(id: UUID) async throws -> CharterAPIResponse {
        AppLogger.api.debug("Fetching charter: \(id.uuidString)")
        return try await get("/charters/\(id.uuidString)", body: EmptyBody())
    }

    func updateCharter(id: UUID, request: CharterUpdateRequest) async throws -> CharterAPIResponse {
        AppLogger.api.debug("Updating charter: \(id.uuidString)")
        return try await put("/charters/\(id.uuidString)", body: request)
    }

    func deleteCharter(id: UUID) async throws {
        AppLogger.api.debug("Deleting charter: \(id.uuidString)")
        try await delete("/charters/\(id.uuidString)")
    }

    func discoverCharters(
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        nearLat: Double? = nil,
        nearLon: Double? = nil,
        radiusKm: Double = 50.0,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> CharterDiscoveryAPIResponse {
        AppLogger.api.debug("Discovering charters (offset: \(offset))")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "radius_km", value: String(radiusKm)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        let iso8601 = ISO8601DateFormatter()
        if let dateFrom {
            components.queryItems?.append(URLQueryItem(name: "date_from", value: iso8601.string(from: dateFrom)))
        }
        if let dateTo {
            components.queryItems?.append(URLQueryItem(name: "date_to", value: iso8601.string(from: dateTo)))
        }
        if let nearLat {
            components.queryItems?.append(URLQueryItem(name: "near_lat", value: String(nearLat)))
        }
        if let nearLon {
            components.queryItems?.append(URLQueryItem(name: "near_lon", value: String(nearLon)))
        }
        let queryString = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return try await get("/charters/discover\(queryString)", body: EmptyBody())
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(
        _ path: String,
        body: EmptyBody
    ) async throws -> T {
        try await request(method: "GET", path: path, body: body)
    }

    private func getUnauthenticated<T: Decodable>(
        _ path: String,
        body: EmptyBody
    ) async throws -> T {
        try await requestUnauthenticated(method: "GET", path: path, body: body)
    }

    private func postUnauthenticated(
        _ path: String,
        body: EmptyBody
    ) async throws {
        try await performRequestUnauthenticated(method: "POST", path: path, body: body)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }

    private func put<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        try await request(method: "PUT", path: path, body: body)
    }

    private func delete(_ path: String) async throws {
        try await performRequest(method: "DELETE", path: path, body: EmptyBody())
    }

    private func performRequestUnauthenticated<B: Encodable>(
        method: String,
        path: String,
        body: B
    ) async throws {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // No auth header for unauthenticated requests

        // Encode body
        if !(body is EmptyBody) {
            urlRequest.httpBody = try encoder.encode(body)
        }

        // Perform request
        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle status codes (only care about success/failure, no response body)
        switch httpResponse.statusCode {
        case 200...299:
            return

        case 401:
            throw APIError.unauthorized

        case 404:
            throw APIError.notFound

        case 409:
            throw APIError.conflict

        default:
            if httpResponse.statusCode >= 400 && httpResponse.statusCode < 500 {
                throw APIError.clientError(httpResponse.statusCode)
            } else {
                throw APIError.serverError
            }
        }
    }

    private func performRequest<B: Encodable>(
        method: String,
        path: String,
        body: B
    ) async throws {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // Get access token (will refresh if needed)
        let accessToken = try await authService.getAccessToken()

        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        // Encode body
        if !(body is EmptyBody) {
            urlRequest.httpBody = try encoder.encode(body)
        }

        // Perform request
        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle status codes (only care about success/failure, no response body)
        switch httpResponse.statusCode {
        case 200...299:
            return

        case 401:
            throw APIError.unauthorized

        case 403:
            throw APIError.forbidden

        case 404:
            throw APIError.notFound

        case 409:
            throw APIError.conflict

        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)

        case 500...599:
            throw APIError.serverError

        default:
            throw APIError.invalidResponse
        }
    }

    private func request<T: Decodable, B: Encodable>(
        method: String,
        path: String,
        body: B
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Get access token (will refresh if needed)
        let accessToken = try await authService.getAccessToken()
        
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Encode body
        if !(body is EmptyBody) {
            urlRequest.httpBody = try encoder.encode(body)
        }
        
        // Perform request
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            return try decoder.decode(T.self, from: data)
            
        case 401:
            throw APIError.unauthorized
            
        case 403:
            throw APIError.forbidden
            
        case 404:
            throw APIError.notFound
            
        case 409:
            throw APIError.conflict
            
        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)
            
        case 500...599:
            throw APIError.serverError
            
        default:
            throw APIError.invalidResponse
        }
    }

    private func requestUnauthenticated<T: Decodable, B: Encodable>(
        method: String,
        path: String,
        body: B
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        // No Authorization header for unauthenticated requests

        // Encode body
        if !(body is EmptyBody) {
            urlRequest.httpBody = try encoder.encode(body)
        }

        // Perform request
        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            return try decoder.decode(T.self, from: data)

        case 401:
            throw APIError.unauthorized

        case 403:
            throw APIError.forbidden

        case 404:
            throw APIError.notFound

        case 409:
            throw APIError.conflict

        case 400...499:
            throw APIError.clientError(httpResponse.statusCode)

        case 500...599:
            throw APIError.serverError

        default:
            throw APIError.invalidResponse
        }
    }
}

// MARK: - Request/Response Types

struct PublishContentRequest: Encodable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
    let tags: [String]
    let language: String
    let publicID: String
    let canFork: Bool
    let forkedFromID: UUID?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case language
        case publicID = "public_id"
        case canFork = "can_fork"
        case forkedFromID = "forked_from_id"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        try container.encode(publicID, forKey: .publicID)
        try container.encode(canFork, forKey: .canFork)
        try container.encodeIfPresent(forkedFromID, forKey: .forkedFromID)
        
        // Encode contentData as nested JSON object (same as SyncPayloads)
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let decoder = JSONDecoder()
        let json = try decoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
}

struct PublishContentResponse: Codable {
    let id: UUID
    let publicID: String
    let publishedAt: Date
    let authorUsername: String?
    let canFork: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case publicID = "public_id"
        case publishedAt = "published_at"
        case authorUsername = "author_username"
        case canFork = "can_fork"
    }
}

struct UpdateContentRequest: Encodable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]
    let tags: [String]
    let language: String

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case language
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)

        // Encode contentData as nested JSON object (same as SyncPayloads)
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let decoder = JSONDecoder()
        let json = try decoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
}

struct UpdateContentResponse: Codable {
    let id: UUID
    let publicID: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case publicID = "public_id"
        case updatedAt = "updated_at"
    }
}

// AnyCodable is now defined in SyncPayloads.swift and shared across the module

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case clientError(Int)
    case serverError
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Resource already exists"
        case .clientError(let code):
            return "Client error: \(code)"
        case .serverError:
            return "Server error"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

struct EmptyBody: Codable {}
struct EmptyResponse: Codable {}

// MARK: - Public Profile Response

struct PublicProfileStatsResponse: Codable {
    let totalContributions: Int
    let averageRating: Double?
    let totalForks: Int
    
    enum CodingKeys: String, CodingKey {
        case totalContributions = "total_contributions"
        case averageRating = "average_rating"
        case totalForks = "total_forks"
    }
}

struct PublicProfileResponse: Codable {
    let id: UUID
    let username: String
    let profileImageUrl: String?
    let profileImageThumbnailUrl: String?
    let bio: String?
    let location: String?
    let nationality: String?
    let isVerified: Bool
    let verificationTier: String?
    let createdAt: Date
    let stats: PublicProfileStatsResponse
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageUrl = "profile_image_url"
        case profileImageThumbnailUrl = "profile_image_thumbnail_url"
        case bio
        case location
        case nationality
        case isVerified = "is_verified"
        case verificationTier = "verification_tier"
        case createdAt = "created_at"
        case stats
    }
    
    /// Convert to AuthorProfile for use in AuthorProfileModal
    func toAuthorProfile(email: String = "") -> AuthorProfile {
        return AuthorProfile(
            username: username,
            email: email,
            profileImageUrl: profileImageUrl,
            profileImageThumbnailUrl: profileImageThumbnailUrl,
            bio: bio,
            location: location,
            nationality: nationality,
            isVerified: isVerified,
            stats: AuthorStats(
                averageRating: stats.averageRating,
                totalContributions: stats.totalContributions,
                totalForks: stats.totalForks
            )
        )
    }
}