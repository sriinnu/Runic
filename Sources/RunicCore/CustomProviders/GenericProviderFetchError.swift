import Foundation

/// Errors that can occur during fetch operations
public enum FetchError: LocalizedError, Sendable {
    case noUsageEndpoint
    case noBalanceEndpoint
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case invalidJSON
    case missingToken(String)
    case invalidDateRange
    case extractionFailed(String)
    case insecureURL(String)

    public var errorDescription: String? {
        switch self {
        case .noUsageEndpoint:
            "No usage endpoint configured for this provider"
        case .noBalanceEndpoint:
            "No balance endpoint configured for this provider"
        case let .invalidURL(url):
            "Invalid URL: \(url)"
        case .invalidResponse:
            "Invalid response from provider API"
        case let .httpError(code):
            "HTTP error \(code) from provider API"
        case .invalidJSON:
            "Failed to parse JSON response from provider"
        case let .missingToken(account):
            "No API token found for '\(account)'. Store it in Keychain or set as environment variable."
        case .invalidDateRange:
            "Failed to calculate date range for URL template"
        case let .extractionFailed(field):
            "Failed to extract field '\(field)' from response"
        case let .insecureURL(url):
            "Only HTTPS URLs are allowed. Got: \(url)"
        }
    }

    public var failureReason: String? {
        switch self {
        case let .missingToken(account):
            "The token for account '\(account)' is not configured in Keychain or environment variables"
        case let .httpError(code):
            "The server returned HTTP status code \(code)"
        case .invalidJSON:
            "The response is not valid JSON or has unexpected structure"
        case let .extractionFailed(field):
            "The field '\(field)' was not found in the response or has wrong type"
        case .insecureURL:
            "The URL scheme is not HTTPS"
        default:
            nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case let .missingToken(account):
            "Store your API token in Keychain with account name '\(account)' or set it as environment variable"
        case .noUsageEndpoint:
            "Configure a usage endpoint in the provider settings"
        case .noBalanceEndpoint:
            "Configure a balance endpoint in the provider settings"
        case let .httpError(code) where code == 401:
            "Check that your API token is valid and has not expired"
        case let .httpError(code) where code == 429:
            "You have been rate limited. Try again later."
        case .invalidJSON:
            "Check the API endpoint URL and response mapping configuration"
        case .insecureURL:
            "Change the provider URL to use HTTPS (e.g., https://api.example.com)"
        default:
            nil
        }
    }
}
