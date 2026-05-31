import Foundation

#if os(macOS)
private struct OverageSpendLimitResponse: Decodable {
    let monthlyCreditLimit: Double?
    let currency: String?
    let usedCredits: Double?
    let isEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case monthlyCreditLimit = "monthly_credit_limit"
        case currency
        case usedCredits = "used_credits"
        case isEnabled = "is_enabled"
    }
}

private struct OrganizationResponse: Decodable {
    let uuid: String
    let name: String?
}

private struct AccountResponse: Decodable {
    let emailAddress: String?
    let memberships: [Membership]?

    enum CodingKeys: String, CodingKey {
        case emailAddress = "email_address"
        case memberships
    }

    struct Membership: Decodable {
        let organization: Organization

        struct Organization: Decodable {
            let uuid: String?
            let name: String?
            let rateLimitTier: String?
            let billingType: String?

            enum CodingKeys: String, CodingKey {
                case uuid
                case name
                case rateLimitTier = "rate_limit_tier"
                case billingType = "billing_type"
            }
        }
    }
}

extension ClaudeWebAPIFetcher {
    static func parseUsageResponse(_ data: Data) throws -> WebUsageData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FetchError.invalidResponse
        }

        // Parse five_hour (session) usage
        var sessionPercent: Double?
        var sessionResets: Date?
        if let fiveHour = json["five_hour"] as? [String: Any] {
            if let utilization = fiveHour["utilization"] as? Int {
                sessionPercent = Double(utilization)
            }
            if let resetsAt = fiveHour["resets_at"] as? String {
                sessionResets = self.parseISO8601Date(resetsAt)
            }
        }
        guard let sessionPercent else {
            // If we can't parse session utilization, treat this as a failure so callers can fall back to the CLI.
            throw FetchError.invalidResponse
        }

        // Parse seven_day (weekly) usage
        var weeklyPercent: Double?
        var weeklyResets: Date?
        if let sevenDay = json["seven_day"] as? [String: Any] {
            if let utilization = sevenDay["utilization"] as? Int {
                weeklyPercent = Double(utilization)
            }
            if let resetsAt = sevenDay["resets_at"] as? String {
                weeklyResets = self.parseISO8601Date(resetsAt)
            }
        }

        // Parse seven_day_opus (Opus-specific weekly) usage
        var opusPercent: Double?
        if let sevenDayOpus = json["seven_day_opus"] as? [String: Any] {
            if let utilization = sevenDayOpus["utilization"] as? Int {
                opusPercent = Double(utilization)
            }
        }

        return WebUsageData(
            sessionPercentUsed: sessionPercent,
            sessionResetsAt: sessionResets,
            weeklyPercentUsed: weeklyPercent,
            weeklyResetsAt: weeklyResets,
            opusPercentUsed: opusPercent,
            extraUsageCost: nil,
            accountOrganization: nil,
            accountEmail: nil,
            loginMethod: nil)
    }

    static func parseOverageSpendLimit(_ data: Data) -> ProviderCostSnapshot? {
        guard let decoded = try? JSONDecoder().decode(OverageSpendLimitResponse.self, from: data) else { return nil }
        guard decoded.isEnabled == true else { return nil }
        guard let used = decoded.usedCredits,
              let limit = decoded.monthlyCreditLimit,
              let currency = decoded.currency,
              !currency.isEmpty else { return nil }

        let usedAmount = used / 100.0
        let limitAmount = limit / 100.0

        return ProviderCostSnapshot(
            used: usedAmount,
            limit: limitAmount,
            currencyCode: currency,
            period: "Monthly",
            resetsAt: nil,
            updatedAt: Date())
    }

    #if DEBUG

    // MARK: - Test hooks (DEBUG-only)

    public static func _parseUsageResponseForTesting(_ data: Data) throws -> WebUsageData {
        try self.parseUsageResponse(data)
    }

    public static func _parseOrganizationsResponseForTesting(_ data: Data) throws -> OrganizationInfo {
        try self.parseOrganizationResponse(data)
    }

    public static func _parseOverageSpendLimitForTesting(_ data: Data) -> ProviderCostSnapshot? {
        self.parseOverageSpendLimit(data)
    }

    public static func _parseAccountInfoForTesting(_ data: Data, orgId: String?) -> WebAccountInfo? {
        self.parseAccountInfo(data, orgId: orgId)
    }
    #endif

    static func parseOrganizationResponse(_ data: Data) throws -> OrganizationInfo {
        guard let organizations = try? JSONDecoder().decode([OrganizationResponse].self, from: data) else {
            throw FetchError.invalidResponse
        }
        guard let first = organizations.first else { throw FetchError.noOrganization }
        let name = first.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = (name?.isEmpty ?? true) ? nil : name
        return OrganizationInfo(id: first.uuid, name: sanitized)
    }

    static func parseAccountInfo(_ data: Data, orgId: String?) -> WebAccountInfo? {
        guard let response = try? JSONDecoder().decode(AccountResponse.self, from: data) else { return nil }
        let email = response.emailAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let membership = Self.selectMembership(response.memberships, orgId: orgId)
        let plan = Self.inferPlan(
            rateLimitTier: membership?.organization.rateLimitTier,
            billingType: membership?.organization.billingType)
        return WebAccountInfo(email: email, loginMethod: plan)
    }

    private static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func selectMembership(
        _ memberships: [AccountResponse.Membership]?,
        orgId: String?) -> AccountResponse.Membership?
    {
        guard let memberships, !memberships.isEmpty else { return nil }
        if let orgId {
            if let match = memberships.first(where: { $0.organization.uuid == orgId }) { return match }
        }
        return memberships.first
    }

    private static func inferPlan(rateLimitTier: String?, billingType: String?) -> String? {
        let tier = rateLimitTier?.lowercased() ?? ""
        let billing = billingType?.lowercased() ?? ""
        if tier.contains("max") { return "Claude Max" }
        if tier.contains("pro") { return "Claude Pro" }
        if tier.contains("team") { return "Claude Team" }
        if tier.contains("enterprise") { return "Claude Enterprise" }
        if billing.contains("stripe"), tier.contains("claude") { return "Claude Pro" }
        return nil
    }

    struct ProbeParseResult {
        let keys: [String]
        let emails: [String]
        let planHints: [String]
        let notableFields: [String]
        let preview: String?
    }

    static func parseProbeBody(
        data: Data,
        fallbackText: String,
        contentType: String?) -> ProbeParseResult
    {
        let trimmed = fallbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksJSON = (contentType?.lowercased().contains("application/json") ?? false) ||
            trimmed.hasPrefix("{") || trimmed.hasPrefix("[")

        var keys: [String] = []
        var notableFields: [String] = []
        if looksJSON, let json = try? JSONSerialization.jsonObject(with: data) {
            if let dict = json as? [String: Any] {
                keys = dict.keys.sorted()
            } else if let array = json as? [[String: Any]], let first = array.first {
                keys = first.keys.sorted()
            }
            notableFields = Self.extractNotableFields(from: json)
        }

        let emails = Self.extractEmails(from: trimmed)
        let planHints = Self.extractPlanHints(from: trimmed)
        let preview = trimmed.isEmpty ? nil : String(trimmed.prefix(500))
        return ProbeParseResult(
            keys: keys,
            emails: emails,
            planHints: planHints,
            notableFields: notableFields,
            preview: preview)
    }

    private static func extractEmails(from text: String) -> [String] {
        let pattern = #"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var results: [String] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 0), in: text) else { return }
            let value = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { results.append(value) }
        }
        return Array(Set(results)).sorted()
    }

    private static func extractPlanHints(from text: String) -> [String] {
        let pattern = #"(?i)\b(max|pro|team|ultra|enterprise)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var results: [String] = []
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: text) else { return }
            let value = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { results.append(value) }
        }
        return Array(Set(results)).sorted()
    }

    private static func extractNotableFields(from json: Any) -> [String] {
        let pattern = #"(?i)(plan|tier|subscription|seat|billing|product)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        var results: [String] = []

        func keyMatches(_ key: String) -> Bool {
            let range = NSRange(key.startIndex..<key.endIndex, in: key)
            return regex.firstMatch(in: key, options: [], range: range) != nil
        }

        func appendValue(_ keyPath: String, value: Any) {
            if results.count >= 40 { return }
            let rendered: String
            switch value {
            case let str as String:
                rendered = str
            case let num as NSNumber:
                rendered = num.stringValue
            case let bool as Bool:
                rendered = bool ? "true" : "false"
            default:
                return
            }
            let trimmed = rendered.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            results.append("\(keyPath)=\(trimmed)")
        }

        func walk(_ value: Any, path: String) {
            if let dict = value as? [String: Any] {
                for (key, nested) in dict {
                    let nextPath = path.isEmpty ? key : "\(path).\(key)"
                    if keyMatches(key) {
                        appendValue(nextPath, value: nested)
                    }
                    walk(nested, path: nextPath)
                }
            } else if let array = value as? [Any] {
                for (idx, nested) in array.enumerated() {
                    let nextPath = "\(path)[\(idx)]"
                    walk(nested, path: nextPath)
                }
            }
        }

        walk(json, path: "")
        return results
    }
}
#endif
