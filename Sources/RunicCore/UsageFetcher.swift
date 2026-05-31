import Foundation

public struct UsageFetcher: Sendable {
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        LoginShellPathCache.shared.captureOnce()
    }

    public func loadLatestUsage() async throws -> UsageSnapshot {
        try await self.withFallback(primary: self.loadRPCUsage, secondary: self.loadTTYUsage)
    }

    private func loadRPCUsage() async throws -> UsageSnapshot {
        let rpc = try CodexRPCClient()
        defer { rpc.shutdown() }

        try await rpc.initialize(clientName: "runic", clientVersion: "0.5.4")
        // The app-server answers on a single stdout stream, so keep requests
        // serialized to avoid starving one reader when multiple awaiters race
        // for the same pipe.
        let limits = try await rpc.fetchRateLimits().rateLimits
        let account = try? await rpc.fetchAccount()

        guard let primary = Self.makeWindow(from: limits.primary),
              let secondary = Self.makeWindow(from: limits.secondary)
        else {
            throw UsageError.noRateLimitsFound
        }

        let identity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: account?.account.flatMap { details in
                if case let .chatgpt(email, _) = details { email } else { nil }
            },
            accountOrganization: nil,
            loginMethod: account?.account.flatMap { details in
                if case let .chatgpt(_, plan) = details { plan } else { nil }
            })
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            updatedAt: Date(),
            identity: identity)
    }

    private func loadTTYUsage() async throws -> UsageSnapshot {
        let status = try await CodexStatusProbe().fetch()
        guard let fiveLeft = status.fiveHourPercentLeft, let weekLeft = status.weeklyPercentLeft else {
            throw UsageError.noRateLimitsFound
        }

        let primary = RateWindow(
            usedPercent: max(0, 100 - Double(fiveLeft)),
            windowMinutes: 300,
            resetsAt: nil,
            resetDescription: status.fiveHourResetDescription)
        let secondary = RateWindow(
            usedPercent: max(0, 100 - Double(weekLeft)),
            windowMinutes: 10080,
            resetsAt: nil,
            resetDescription: status.weeklyResetDescription)

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: nil,
            updatedAt: Date(),
            identity: nil)
    }

    public func loadLatestCredits() async throws -> CreditsSnapshot {
        try await self.withFallback(primary: self.loadRPCCredits, secondary: self.loadTTYCredits)
    }

    private func loadRPCCredits() async throws -> CreditsSnapshot {
        let rpc = try CodexRPCClient()
        defer { rpc.shutdown() }
        try await rpc.initialize(clientName: "runic", clientVersion: "0.5.4")
        let limits = try await rpc.fetchRateLimits().rateLimits
        guard let credits = limits.credits else { throw UsageError.noRateLimitsFound }
        let remaining = Self.parseCredits(credits.balance)
        return CreditsSnapshot(remaining: remaining, events: [], updatedAt: Date())
    }

    private func loadTTYCredits() async throws -> CreditsSnapshot {
        let status = try await CodexStatusProbe().fetch()
        guard let credits = status.credits else { throw UsageError.noRateLimitsFound }
        return CreditsSnapshot(remaining: credits, events: [], updatedAt: Date())
    }

    private func withFallback<T>(
        primary: @escaping () async throws -> T,
        secondary: @escaping () async throws -> T) async throws -> T
    {
        do {
            return try await primary()
        } catch let primaryError {
            do {
                return try await secondary()
            } catch {
                // Preserve the original failure so callers see the primary path error.
                throw primaryError
            }
        }
    }

    public func debugRawRateLimits() async -> String {
        do {
            let rpc = try CodexRPCClient()
            defer { rpc.shutdown() }
            try await rpc.initialize(clientName: "runic", clientVersion: "0.5.4")
            let limits = try await rpc.fetchRateLimits()
            let data = try JSONEncoder().encode(limits)
            return String(data: data, encoding: .utf8) ?? "<unprintable>"
        } catch {
            return "Codex RPC probe failed: \(error)"
        }
    }

    public func loadAccountInfo() -> AccountInfo {
        // Keep using auth.json for quick startup (non-blocking, no RPC spin-up required).
        let authURL = URL(fileURLWithPath: self.environment["CODEX_HOME"] ?? "\(NSHomeDirectory())/.codex")
            .appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: authURL),
              let auth = try? JSONDecoder().decode(AuthFile.self, from: data),
              let idToken = auth.tokens?.idToken
        else {
            return AccountInfo(email: nil, plan: nil)
        }

        guard let payload = UsageFetcher.parseJWT(idToken) else {
            return AccountInfo(email: nil, plan: nil)
        }

        let authDict = payload["https://api.openai.com/auth"] as? [String: Any]
        let profileDict = payload["https://api.openai.com/profile"] as? [String: Any]

        let plan = (authDict?["chatgpt_plan_type"] as? String)
            ?? (payload["chatgpt_plan_type"] as? String)

        let email = (payload["email"] as? String)
            ?? (profileDict?["email"] as? String)

        return AccountInfo(email: email, plan: plan)
    }

    private static func makeWindow(from rpc: RPCRateLimitWindow?) -> RateWindow? {
        guard let rpc else { return nil }
        let resetsAtDate = rpc.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let resetDescription = resetsAtDate.map { UsageFormatter.resetDescription(from: $0) }
        return RateWindow(
            usedPercent: rpc.usedPercent,
            windowMinutes: rpc.windowDurationMins,
            resetsAt: resetsAtDate,
            resetDescription: resetDescription)
    }

    private static func parseCredits(_ balance: String?) -> Double {
        guard let balance, let val = Double(balance) else { return 0 }
        return val
    }

    public static func parseJWT(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadPart = parts[1]

        var padded = String(payloadPart)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 {
            padded.append("=")
        }
        guard let data = Data(base64Encoded: padded) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }
}

/// Minimal auth.json struct preserved from previous implementation
private struct AuthFile: Decodable {
    struct Tokens: Decodable { let idToken: String? }
    let tokens: Tokens?
}
