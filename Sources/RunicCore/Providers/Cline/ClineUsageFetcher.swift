import Foundation

// MARK: - API response models

/// Every Cline API response is wrapped as `{success, error, data}`.
struct ClineEnvelope<Payload: Decodable>: Decodable {
    let success: Bool?
    let error: String?
    let data: Payload?

    enum CodingKeys: String, CodingKey {
        case success
        case error
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try? container.decodeIfPresent(Bool.self, forKey: .success)
        // `error` is a string in practice; tolerate an object or anything else.
        self.error = try? container.decodeIfPresent(String.self, forKey: .error)
        self.data = try container.decodeIfPresent(Payload.self, forKey: .data)
    }
}

/// A number that some Cline endpoints send as a JSON string ("0.0123").
struct ClineLenientDouble: Decodable, Equatable {
    let value: Double?

    init(_ value: Double?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            self.value = number
        } else if let text = try? container.decode(String.self) {
            self.value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            self.value = nil
        }
    }
}

struct ClineUser: Decodable {
    let id: String?
    let email: String?
    let displayName: String?
}

struct ClineBalance: Decodable {
    let balance: ClineLenientDouble?
    let userId: String?
}

struct ClineUsageList: Decodable {
    let items: [ClineUsageItem]?
}

struct ClineUsageItem: Decodable {
    let aiInferenceProviderName: String?
    let aiModelName: String?
    let promptTokens: ClineLenientDouble?
    let completionTokens: ClineLenientDouble?
    let totalTokens: ClineLenientDouble?
    let costUsd: ClineLenientDouble?
    let creditsUsed: ClineLenientDouble?
    let createdAt: String?
    let generationId: String?

    var createdDate: Date? {
        self.createdAt.flatMap(ClineUsageFetcher.parseDate)
    }
}

/// Everything one refresh learned about a Cline account.
struct ClineAccountUsage {
    let user: ClineUser
    let balance: ClineBalance
    /// Nil when the usages call failed; the balance still shows.
    let usages: [ClineUsageItem]?
}

// MARK: - Fetcher

enum ClineUsageFetcher {
    private static let log = RunicLog.logger("cline-usage")

    static let baseURL = URL(string: "https://api.cline.bot")!

    /// Cline reports `balance` as an integer with no documented unit. Its own
    /// clients disagree: the newer CLI divides by 1,000,000 (micro-USD), an
    /// older webview divided by 10,000. Micro-USD matches the CLI and the
    /// per-item `creditsUsed / 1e6 == costUsd` relationship in usage records,
    /// so that's the divisor used here. If balances look 100x off, this is the
    /// one constant to revisit.
    static let balanceUnitsPerUSD: Double = 1_000_000

    static func fetchAll(apiKey: String) async throws -> ClineAccountUsage {
        let user: ClineUser = try await self.get("/api/v1/users/me", apiKey: apiKey)
        guard let userID = user.id, !userID.isEmpty else {
            throw ClineAPIError.missingUserID
        }
        let encodedID = userID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userID
        let balance: ClineBalance = try await self.get("/api/v1/users/\(encodedID)/balance", apiKey: apiKey)

        var usages: [ClineUsageItem]?
        do {
            let list: ClineUsageList = try await self.get("/api/v1/users/\(encodedID)/usages", apiKey: apiKey)
            usages = list.items ?? []
        } catch {
            // Best effort: spend figures are a bonus on top of the balance.
            self.log.warning("Cline usages request failed: \(error.localizedDescription)")
            usages = nil
        }
        return ClineAccountUsage(user: user, balance: balance, usages: usages)
    }

    private static func get<Payload: Decodable>(_ path: String, apiKey: String) async throws -> Payload {
        guard let url = URL(string: path, relativeTo: self.baseURL) else {
            throw ClineAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClineAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ClineAPIError.httpError(statusCode: httpResponse.statusCode)
        }
        return try self.decodeEnvelope(Payload.self, from: data)
    }

    /// Unwraps `{success, error, data}`; a `success: false` or missing `data`
    /// becomes an error carrying Cline's own message.
    static func decodeEnvelope<Payload: Decodable>(_: Payload.Type, from data: Data) throws -> Payload {
        let envelope: ClineEnvelope<Payload>
        do {
            envelope = try JSONDecoder().decode(ClineEnvelope<Payload>.self, from: data)
        } catch {
            throw ClineAPIError.decodingError
        }
        if envelope.success == false {
            throw ClineAPIError.apiError(envelope.error)
        }
        guard let payload = envelope.data else {
            throw ClineAPIError.apiError(envelope.error)
        }
        return payload
    }

    static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }

    /// Sums `costUsd` for items created in the current local day and calendar
    /// month. Items without a parseable date or cost are skipped.
    static func spend(
        items: [ClineUsageItem],
        now: Date,
        calendar: Calendar = .current) -> (today: Double, thisMonth: Double)
    {
        var today = 0.0
        var month = 0.0
        for item in items {
            guard let date = item.createdDate, let cost = item.costUsd?.value else { continue }
            if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                month += cost
                if calendar.isDate(date, inSameDayAs: now) {
                    today += cost
                }
            }
        }
        return (today, month)
    }
}

// MARK: - Snapshot conversion

extension ClineAccountUsage {
    var availableUSD: Double {
        (self.balance.balance?.value ?? 0) / ClineUsageFetcher.balanceUnitsPerUSD
    }

    func toUsageSnapshot(now: Date = Date(), calendar: Calendar = .current) -> UsageSnapshot {
        let available = self.availableUSD
        var summary = "Balance: \(BalanceFormatter.amount(available, currency: "USD"))"

        let reported: ProviderBalance.ReportedSpend? = self.usages.map { items in
            let spend = ClineUsageFetcher.spend(items: items, now: now, calendar: calendar)
            return .init(today: spend.today, thisWeek: nil, thisMonth: spend.thisMonth, scope: nil)
        }
        if let reported, reported.today > 0 {
            summary += " · Today: \(BalanceFormatter.amount(reported.today, currency: "USD"))"
        }

        let email = self.user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let identity = ProviderIdentitySnapshot(
            providerID: .cline,
            accountEmail: (email?.isEmpty ?? true) ? nil : email,
            accountOrganization: nil,
            loginMethod: nil)

        return UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: summary,
                hasKnownLimit: false),
            secondary: nil,
            tertiary: nil,
            balance: ProviderBalance(
                available: available,
                currency: "USD",
                reportedSpend: reported),
            updatedAt: now,
            identity: identity)
    }
}

// MARK: - Errors

enum ClineAPIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case missingUserID
    case apiError(String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Cline returned an invalid response."
        case let .httpError(statusCode):
            statusCode == 401 || statusCode == 403
                ? "Cline rejected the API key (HTTP \(statusCode))."
                : "Cline request failed (HTTP \(statusCode))."
        case .decodingError:
            "Cline response could not be decoded."
        case .missingUserID:
            "Cline did not return a user ID for this API key."
        case let .apiError(message):
            message.map { "Cline API error: \($0)" } ?? "Cline API returned no data."
        }
    }
}
