import Foundation

/// Claude's banked "reset your limits" grants (claude.ai → Settings → Usage →
/// Resets). The usage endpoint only includes them when asked with
/// `cedar_ember=1`, under the `cedar_ember` key; without the flag the key is
/// null. Same shape on `claude.ai/api/organizations/{org}/usage`; observed
/// 2026-09-22 with an Opus 5.5 launch grant.
struct ClaudeLimitResetStatus: Decodable {
    static let queryItem = URLQueryItem(name: "cedar_ember", value: "1")

    let eligible: Bool?
    let grants: [Grant]?

    struct Grant: Decodable {
        let id: String
        let label: String?
        let resetsTotal: Int?
        let resetsLeft: Int?
        let startsAt: String?
        let endsAt: String?
        let paused: Bool?

        enum CodingKeys: String, CodingKey {
            case id
            case label
            case resetsTotal = "resets_total"
            case resetsLeft = "resets_left"
            case startsAt = "starts_at"
            case endsAt = "ends_at"
            case paused
        }
    }

    /// One credit per reset left in each live grant, so the shared panel can
    /// list them with their expiry. Nil when nothing is banked.
    func resetCredits(now: Date = Date()) -> UsageResetCredits? {
        var credits: [UsageResetCredit] = []
        for grant in self.grants ?? [] {
            let left = max(0, grant.resetsLeft ?? 0)
            guard left > 0, grant.paused != true else { continue }
            let endsAt = ClaudeOAuthUsageFetcher.parseISO8601Date(grant.endsAt)
            if let endsAt, endsAt <= now { continue }
            let startsAt = ClaudeOAuthUsageFetcher.parseISO8601Date(grant.startsAt)
            for index in 0..<left {
                credits.append(UsageResetCredit(
                    id: left == 1 ? grant.id : "\(grant.id)#\(index + 1)",
                    title: grant.label,
                    status: "available",
                    grantedAt: startsAt,
                    expiresAt: endsAt,
                    resetType: "claude_limit_reset"))
            }
        }
        guard !credits.isEmpty else { return nil }
        return UsageResetCredits(availableCount: credits.count, credits: credits)
    }
}
