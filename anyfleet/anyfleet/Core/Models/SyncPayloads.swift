import Foundation

// MARK: - Publish Payload

/// Payload for publishing content to backend
/// Uses explicit CodingKeys to map Swift camelCase to JSON snake_case
struct ContentPublishPayload: Codable {
    let title: String
    let description: String?
    let contentType: String
    let contentData: [String: Any]  // Will be encoded as JSON object
    let tags: [String]
    let language: String
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case contentType = "content_type"
        case contentData = "content_data"
        case tags
        case language
        case publicID = "public_id"
    }
    
    // MARK: - Initializer
    
    init(
        title: String,
        description: String?,
        contentType: String,
        contentData: [String: Any],
        tags: [String],
        language: String,
        publicID: String
    ) {
        self.title = title
        self.description = description
        self.contentType = contentType
        self.contentData = contentData
        self.tags = tags
        self.language = language
        self.publicID = publicID
    }
    
    // MARK: - Encoding
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(tags, forKey: .tags)
        try container.encode(language, forKey: .language)
        try container.encode(publicID, forKey: .publicID)
        
        // Encode contentData as nested JSON object (not string!)
        let jsonData = try JSONSerialization.data(withJSONObject: contentData)
        let jsonDecoder = JSONDecoder()
        let json = try jsonDecoder.decode(AnyCodable.self, from: jsonData)
        try container.encode(json, forKey: .contentData)
    }
    
    // MARK: - Decoding
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Debug: Check what keys are available
        let allKeys = container.allKeys.map { $0.stringValue }.joined(separator: ", ")
        print("DEBUG: Available keys in container: \(allKeys)")
        
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        contentType = try container.decode(String.self, forKey: .contentType)
        tags = try container.decode([String].self, forKey: .tags)
        language = try container.decode(String.self, forKey: .language)
        
        // Debug: Check if publicID key exists
        if container.contains(.publicID) {
            print("DEBUG: publicID key found in container")
            publicID = try container.decode(String.self, forKey: .publicID)
        } else {
            print("DEBUG: publicID key NOT found in container")
            print("DEBUG: CodingKey .publicID has stringValue: \(CodingKeys.publicID.stringValue)")
            throw DecodingError.keyNotFound(
                CodingKeys.publicID,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "publicID key not found in payload")
            )
        }
        
        // Decode contentData as nested JSON object
        let json = try container.decode(AnyCodable.self, forKey: .contentData)
        contentData = json.value as? [String: Any] ?? [:]
    }
}

// MARK: - Unpublish Payload

/// Payload for unpublishing content
struct UnpublishPayload: Codable {
    let publicID: String
    
    enum CodingKeys: String, CodingKey {
        case publicID = "public_id"
    }
    
    // REQUIRED: Initializer to create instances
    init(publicID: String) {
        self.publicID = publicID
    }
}

// MARK: - Helper for Dynamic JSON

/// Helper to encode/decode dynamic JSON structures like [String: Any]
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
