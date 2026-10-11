import Foundation

/// The monthly API credit Anthropic includes with a Claude subscription
/// since 7 Oct 2026: $100 on Max 5x, $200 on Max 20x (Team varies by seat,
/// so it is not inferred). The credit is spent on the API, the Console and
/// the Agent SDK, not on Claude Code, and expires at the end of each billing
/// period. Pro and Free get none, so nothing is shown for them.
///
/// claude.ai exposes no endpoint for the grant or its remaining balance
/// (that lives in the Console, behind a separate login); what Runic can
/// know is the plan tier (from the OAuth credentials) and the next billing
/// date (from `subscription_details`, with the claude.ai switch on).
enum ClaudeAPICreditGrant {
    /// Monthly grant in USD for a `rate_limit_tier` such as
    /// `default_claude_max_20x`; nil when the tier carries none.
    static func monthlyUSD(rateLimitTier: String?) -> Double? {
        let tier = rateLimitTier?.lowercased() ?? ""
        guard tier.contains("max") else { return nil }
        if tier.contains("20x") { return 200 }
        if tier.contains("5x") { return 100 }
        return nil
    }

    /// The subscription's next charge from `GET /api/organizations/{org}/
    /// subscription_details` (`next_charge_at`, ISO 8601; `next_charge_date`
    /// as a fallback). The next credit lands with that charge.
    static func parseNextChargeDate(_ data: Data) -> Date? {
        struct Details: Decodable {
            let nextChargeAt: String?
            let nextChargeDate: String?

            private enum CodingKeys: String, CodingKey {
                case nextChargeAt = "next_charge_at"
                case nextChargeDate = "next_charge_date"
            }
        }
        guard let details = try? JSONDecoder().decode(Details.self, from: data) else { return nil }
        for candidate in [details.nextChargeAt, details.nextChargeDate].compactMap(\.self) {
            if let date = Self.parseDate(candidate) { return date }
        }
        return nil
    }

    private static func parseDate(_ text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "UTC")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: text)
    }
}
