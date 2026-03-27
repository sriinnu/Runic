import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

/// Generic fetcher for custom API provider usage and balance data
public actor GenericProviderFetcher {
    private let config: CustomProviderConfig
    private let keychainService = "com.sriinnu.athena.Runic"
    private let log = RunicLog.logger("generic-provider-fetcher")

    public init(config: CustomProviderConfig) {
        self.config = config
    }

    // MARK: - Public Fetch Methods

    /// Fetch usage data from the custom provider
    public func fetchUsage() async throws -> UsageData {
        guard let endpoint = config.endpoints.usage else {
            throw FetchError.noUsageEndpoint
        }

        // 1. Build URL with variable substitution
        let url = try buildURL(from: endpoint.url, with: endpoint.queryParams)

        // 2. Create request with auth headers
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth headers
        try await self.addAuthHeaders(to: &request)

        // 3. Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FetchError.httpError(httpResponse.statusCode)
        }

        // 4. Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidJSON
        }

        // 5. Extract fields using mapping
        return try self.extractUsageData(from: json, mapping: endpoint.mapping)
    }

    /// Fetch balance data from the custom provider
    public func fetchBalance() async throws -> BalanceData {
        guard let endpoint = config.endpoints.balance else {
            throw FetchError.noBalanceEndpoint
        }

        // 1. Build URL with variable substitution
        let url = try buildURL(from: endpoint.url, with: nil)

        // 2. Create request with auth headers
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth headers
        try await self.addAuthHeaders(to: &request)

        // 3. Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FetchError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw FetchError.httpError(httpResponse.statusCode)
        }

        // 4. Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidJSON
        }

        // 5. Extract fields using mapping
        return try self.extractBalanceData(from: json, mapping: endpoint.mapping)
    }

    /// Convert usage data to Runic's UsageSnapshot format
    public func toUsageSnapshot(_ data: UsageData) -> UsageSnapshot {
        let usedPercent: Double = if let quota = data.quota, let used = data.used, quota > 0 {
            (used / quota) * 100.0
        } else if let remaining = data.remaining, let quota = data.quota, quota > 0 {
            ((quota - remaining) / quota) * 100.0
        } else {
            0
        }

        let primary = RateWindow(
            usedPercent: max(0, min(100, usedPercent)),
            windowMinutes: nil,
            resetsAt: data.resetDate,
            resetDescription: data.resetDate.map { self.resetDescription(from: $0) })

        return UsageSnapshot(
            primary: primary,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    // MARK: - URL Building

    /// Build URL with variable substitution and query parameters
    private func buildURL(from template: String, with params: [String: String]?) throws -> URL {
        var urlString = template

        // Replace date variables
        urlString = try self.substituteDateVariables(in: urlString)

        // Build URL components
        guard var components = URLComponents(string: urlString) else {
            throw FetchError.invalidURL(urlString)
        }

        // Add query parameters
        if let params, !params.isEmpty {
            var queryItems = components.queryItems ?? []
            queryItems.append(contentsOf: params.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw FetchError.invalidURL(urlString)
        }

        guard url.scheme?.lowercased() == "https" else {
            throw FetchError.insecureURL(urlString)
        }

        return url
    }

    /// Replace date variables in URL template
    private func substituteDateVariables(in template: String) throws -> String {
        var result = template
        let now = Date()

        // Date formatters
        let iso8601Formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // {{date}} - Today's date in ISO8601 format
        if result.contains("{{date}}") {
            result = result.replacingOccurrences(of: "{{date}}", with: iso8601Formatter.string(from: now))
        }

        // {{date:yyyy-MM-dd}} - Custom date format
        if let customMatch = result.range(of: #"\{\{date:([^}]+)\}\}"#, options: .regularExpression) {
            let pattern = String(result[customMatch])
            if let formatRange = pattern.range(of: "(?<=:)[^}]+", options: .regularExpression) {
                let format = String(pattern[formatRange])
                dateFormatter.dateFormat = format
                result = result.replacingOccurrences(of: pattern, with: dateFormatter.string(from: now))
            }
        }

        // {{start}} and {{end}} - Date range (default: current month)
        if result.contains("{{start}}") || result.contains("{{end}}") {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let startOfMonth = calendar.date(from: components) else {
                throw FetchError.invalidDateRange
            }
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now

            result = result.replacingOccurrences(of: "{{start}}", with: dateFormatter.string(from: startOfMonth))
            result = result.replacingOccurrences(of: "{{end}}", with: dateFormatter.string(from: endOfMonth))
        }

        // {{timestamp}} - Unix timestamp
        if result.contains("{{timestamp}}") {
            result = result.replacingOccurrences(of: "{{timestamp}}", with: "\(Int(now.timeIntervalSince1970))")
        }

        return result
    }

    // MARK: - Authentication

    /// Add authentication headers to the request
    private func addAuthHeaders(to request: inout URLRequest) async throws {
        // Load token from keychain
        let token = try await loadToken()

        // Add auth header based on type
        switch self.config.auth.type {
        case .apiKey:
            let value = (config.auth.headerPrefix ?? "") + token
            request.setValue(value, forHTTPHeaderField: self.config.auth.headerName)

        case .bearer:
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        case .basic:
            let encoded = Data("\(token):".utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")

        case .oauth:
            // OAuth typically uses Bearer token
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        case .custom:
            // Custom auth uses the exact header name and prefix from config
            let value = (config.auth.headerPrefix ?? "") + token
            request.setValue(value, forHTTPHeaderField: self.config.auth.headerName)
        }

        // Add additional headers
        self.config.auth.additionalHeaders?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    /// Load token from keychain or environment
    private func loadToken() async throws -> String {
        // Try keychain first
        if let token = keychainToken(account: config.auth.tokenKeychain) {
            return token
        }

        // Try environment variable
        let envKey = self.config.auth.tokenKeychain.uppercased().replacingOccurrences(of: "-", with: "_")
        if let token = ProcessInfo.processInfo.environment[envKey] {
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw FetchError.missingToken(self.config.auth.tokenKeychain)
    }

    /// Read token from keychain
    private func keychainToken(account: String) -> String? {
        #if canImport(Security)
        var result: CFTypeRef?
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.keychainService,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationUI as String: "kSecUseAuthenticationUIFail" as CFString,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        #if canImport(LocalAuthentication)
        let authContext = LAContext()
        authContext.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = authContext
        #endif

        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        if status == errSecInteractionNotAllowed {
            return nil
        }
        guard status == errSecSuccess else {
            self.log.error("Keychain read failed for \(account): \(status)")
            return nil
        }

        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty
        else {
            return nil
        }

        return token
        #else
        _ = account
        return nil
        #endif
    }

    // MARK: - Data Extraction

    /// Extract usage data using JSONPath-like mapping
    private func extractUsageData(from json: [String: Any], mapping: ResponseMapping) throws -> UsageData {
        var data = UsageData()

        // Extract quota
        if let quotaPath = mapping.quota {
            data.quota = self.extractDouble(from: json, path: quotaPath, nested: mapping.nestedPaths)
        }

        // Extract used amount
        if let usedPath = mapping.used {
            data.used = self.extractDouble(from: json, path: usedPath, nested: mapping.nestedPaths)
        }

        // Extract remaining amount
        if let remainingPath = mapping.remaining {
            data.remaining = self.extractDouble(from: json, path: remainingPath, nested: mapping.nestedPaths)
        }

        // Extract cost
        if let costPath = mapping.cost {
            data.cost = self.extractDouble(from: json, path: costPath, nested: mapping.nestedPaths)
        }

        // Extract reset date
        if let resetPath = mapping.resetDate {
            data.resetDate = self.extractDate(from: json, path: resetPath, nested: mapping.nestedPaths)
        }

        // Extract tokens
        if let tokensPath = mapping.tokens {
            data.tokens = self.extractInt(from: json, path: tokensPath, nested: mapping.nestedPaths)
        }

        return data
    }

    /// Extract balance data using JSONPath-like mapping
    private func extractBalanceData(from json: [String: Any], mapping: ResponseMapping) throws -> BalanceData {
        var data = BalanceData()

        // Extract balance (use 'remaining' or 'used' mapping)
        if let balancePath = mapping.remaining ?? mapping.used {
            data.balance = self.extractDouble(from: json, path: balancePath, nested: mapping.nestedPaths)
        }

        // Try to detect currency from response
        data.currency = self.extractString(from: json, path: "currency", nested: true) ?? "USD"

        return data
    }

    // MARK: - JSONPath Extraction

    /// Extract nested value using dot notation path
    private func extractValue(from json: [String: Any], path: String, nested: Bool) -> Any? {
        if !nested {
            return json[path]
        }

        let components = path.split(separator: ".").map(String.init)
        var current: Any? = json

        for component in components {
            // Handle array indexing: field[0]
            if let bracketIndex = component.firstIndex(of: "["),
               let closeBracket = component.firstIndex(of: "]")
            {
                let fieldName = String(component[..<bracketIndex])
                let indexStr = String(component[component.index(after: bracketIndex)..<closeBracket])

                guard let dict = current as? [String: Any],
                      let array = dict[fieldName] as? [Any],
                      let index = Int(indexStr),
                      index < array.count
                else {
                    return nil
                }
                current = array[index]
            } else {
                // Regular field access
                guard let dict = current as? [String: Any] else {
                    return nil
                }
                current = dict[component]
            }
        }

        return current
    }

    /// Extract Double value from JSON path
    private func extractDouble(from json: [String: Any], path: String, nested: Bool) -> Double? {
        guard let value = extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        // Handle different numeric types
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let string as String:
            return Double(string)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }

    /// Extract Int value from JSON path
    private func extractInt(from json: [String: Any], path: String, nested: Bool) -> Int? {
        guard let value = extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let string as String:
            return Int(string)
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    /// Extract String value from JSON path
    private func extractString(from json: [String: Any], path: String, nested: Bool) -> String? {
        guard let value = extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return String(describing: value)
        }
    }

    /// Extract Date value from JSON path (supports Unix timestamp and ISO8601)
    private func extractDate(from json: [String: Any], path: String, nested: Bool) -> Date? {
        guard let value = extractValue(from: json, path: path, nested: nested) else {
            return nil
        }

        // Try Unix timestamp (seconds or milliseconds)
        if let timestamp = value as? Double {
            // If timestamp > 10 billion, assume milliseconds
            let interval = timestamp > 10_000_000_000 ? timestamp / 1000.0 : timestamp
            return Date(timeIntervalSince1970: interval)
        }

        if let timestamp = value as? Int {
            let interval = timestamp > 10_000_000_000 ? Double(timestamp) / 1000.0 : Double(timestamp)
            return Date(timeIntervalSince1970: interval)
        }

        // Try ISO8601 string
        if let dateString = value as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try RFC3339 with fractional seconds
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - Helpers

    /// Format reset date into human-readable description
    private func resetDescription(from date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)

        if interval <= 0 {
            return "Reset now"
        }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "Resets in \(days)d"
        } else if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }
}

// MARK: - Data Structures

/// Usage data fetched from custom provider
public struct UsageData: Sendable {
    public var quota: Double?
    public var used: Double?
    public var remaining: Double?
    public var cost: Double?
    public var resetDate: Date?
    public var tokens: Int?

    public init(
        quota: Double? = nil,
        used: Double? = nil,
        remaining: Double? = nil,
        cost: Double? = nil,
        resetDate: Date? = nil,
        tokens: Int? = nil)
    {
        self.quota = quota
        self.used = used
        self.remaining = remaining
        self.cost = cost
        self.resetDate = resetDate
        self.tokens = tokens
    }

    public func toCustomUsageData() -> CustomUsageData {
        CustomUsageData(
            quota: self.quota,
            used: self.used,
            remaining: self.remaining,
            cost: self.cost,
            resetDate: self.resetDate,
            tokens: self.tokens)
    }
}

/// Balance data fetched from custom provider
public struct BalanceData: Sendable {
    public var balance: Double?
    public var currency: String?

    public init(balance: Double? = nil, currency: String? = nil) {
        self.balance = balance
        self.currency = currency
    }
}

// MARK: - Errors

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
