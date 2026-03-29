import Foundation

enum AppConfiguration {
    /// API base URL for the current build configuration, from `API_BASE_URL` in Info.plist.
    static let apiBaseURL: URL = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: urlString)
        else {
            preconditionFailure("API_BASE_URL not set in Info.plist")
        }
        return url
    }()

    /// Scheme + host (+ port if non-default) for image and asset URLs.
    static let apiHost: String = {
        guard let components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme,
              let host = components.host
        else { return "" }
        if let port = components.port {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }()

    static var isStaging: Bool {
        apiBaseURL.absoluteString.contains("staging")
    }
}
