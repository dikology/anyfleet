import Foundation

/// API client for authenticated requests to backend
final class APIClient {
    private let baseURL: URL
    private let authService: AuthService
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(authService: AuthService) {
        // Environment-based URL
        #if DEBUG
        self.baseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
        #else
        self.baseURL = URL(string: "https://api.anyfleet.app/api/v1")!
        #endif
        
        self.authService = authService
        self.session = URLSession.shared
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase  // Keep for responses
        
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
        canFork: Bool
    ) async throws -> PublishContentResponse {
        let request = PublishContentRequest(
            title: title,
            description: description,
            contentType: contentType,
            contentData: contentData,
            tags: tags,
            language: language,
            publicID: publicID,
            canFork: canFork
        )
        
        return try await post("/content/share", body: request)
    }
    
    func unpublishContent(publicID: String) async throws {
        try await delete("/content/\(publicID)")
    }
    
    // MARK: - HTTP Methods
    
    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B
    ) async throws -> T {
        try await request(method: "POST", path: path, body: body)
    }
    
    private func delete(_ path: String) async throws {
        try await performRequest(method: "DELETE", path: path, body: EmptyBody())
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

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case language
        case publicID = "public_id"
        case canFork = "can_fork"
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