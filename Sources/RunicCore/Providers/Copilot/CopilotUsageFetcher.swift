import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CopilotUsageFetchError: LocalizedError, Sendable {
    case unauthorized(details: String)
    case endpointUnavailable(details: String)
    case invalidResponse(details: String)
    case noQuotaData
    case allAttemptsFailed(details: [String])

    public var errorDescription: String? {
        switch self {
        case let .unauthorized(details):
            if details.isEmpty {
                return "GitHub Copilot token unauthorized. Sign in again."
            }
            return "GitHub Copilot token unauthorized. \(details)"
        case let .endpointUnavailable(details):
            if details.isEmpty {
                return "GitHub Copilot usage endpoint unavailable."
            }
            return "GitHub Copilot usage endpoint unavailable. \(details)"
        case let .invalidResponse(details):
            if details.isEmpty {
                return "GitHub Copilot returned an invalid response."
            }
            return "GitHub Copilot returned an invalid response. \(details)"
        case .noQuotaData:
            return "GitHub Copilot returned no quota snapshots."
        case let .allAttemptsFailed(details):
            let compact = details
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " | ")
            if compact.isEmpty {
                return "GitHub Copilot usage fetch failed after multiple attempts."
            }
            return "GitHub Copilot usage fetch failed after multiple attempts. \(compact)"
        }
    }
}

public struct CopilotUsageFetcher: Sendable {
    private struct CopilotSessionTokenResponse: Decodable {
        let token: String
    }

    private let token: String
    private let tokenSourceLabel: String
    private static let log = RunicLog.logger("copilot-usage")

    public init(token: String, tokenSourceLabel: String = "settings") {
        self.token = token
        self.tokenSourceLabel = tokenSourceLabel
    }

    public func fetch() async throws -> UsageSnapshot {
        guard let url = URL(string: "https://api.github.com/copilot_internal/user") else {
            throw URLError(.badURL)
        }
        Self.log.debug("Starting Copilot fetch using token source \(self.tokenSourceLabel).")

        var attemptNotes: [String] = []
        let githubAuthHeaders = [
            ("token", "token \(self.token)"),
            ("bearer", "Bearer \(self.token)"),
        ]
        attemptNotes.append("auth-source=\(self.tokenSourceLabel)")

        for (label, value) in githubAuthHeaders {
            do {
                Self.log.debug("Attempting Copilot fetch with \(label) auth.")
                let usage = try await self.fetchUsage(url: url, authorization: value)
                return try self.makeSnapshot(from: usage)
            } catch let error as CopilotUsageFetchError {
                attemptNotes.append("\(label): \(error.localizedDescription)")
                Self.log.warning("Copilot fetch with \(label) auth failed: \(error.localizedDescription)")
            } catch {
                attemptNotes.append("\(label): \(error.localizedDescription)")
                Self.log.warning("Copilot fetch with \(label) auth failed: \(error.localizedDescription)")
            }
        }

        if let copilotSessionToken = try? await self.exchangeCopilotSessionToken() {
            Self.log.debug("Attempting Copilot token-exchange flow.")
            do {
                let usage = try await self.fetchUsage(url: url, authorization: "Bearer \(copilotSessionToken)")
                return try self.makeSnapshot(from: usage)
            } catch let error as CopilotUsageFetchError {
                attemptNotes.append("copilot-session: \(error.localizedDescription)")
                Self.log.warning("Copilot session-token flow failed: \(error.localizedDescription)")
            } catch {
                attemptNotes.append("copilot-session: \(error.localizedDescription)")
                Self.log.warning("Copilot session-token flow failed: \(error.localizedDescription)")
            }
        } else {
            attemptNotes.append("copilot-session: token exchange failed")
            Self.log.warning("Copilot session-token flow failed to exchange token.")
        }

        Self.log.error("Copilot fetch failed after attempts: \(attemptNotes.joined(separator: " | "))")
        throw CopilotUsageFetchError.allAttemptsFailed(details: attemptNotes)
    }

    private func fetchUsage(url: URL, authorization: String) async throws -> CopilotUsageResponse {
        var request = URLRequest(url: url)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        self.addCommonHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotUsageFetchError.invalidResponse(details: "missing HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = self.errorSnippet(from: data)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CopilotUsageFetchError.unauthorized(details: "HTTP \(httpResponse.statusCode). \(body)")
            }
            if httpResponse.statusCode == 404 {
                throw CopilotUsageFetchError.endpointUnavailable(
                    details: "HTTP 404. Copilot usage endpoint may have changed. \(body)")
            }
            throw CopilotUsageFetchError.invalidResponse(
                details: "HTTP \(httpResponse.statusCode). \(body)")
        }

        do {
            return try JSONDecoder().decode(CopilotUsageResponse.self, from: data)
        } catch {
            let body = self.errorSnippet(from: data)
            throw CopilotUsageFetchError.invalidResponse(
                details: "decode failed: \(error.localizedDescription). \(body)")
        }
    }

    private func exchangeCopilotSessionToken() async throws -> String {
        guard let url = URL(string: "https://api.github.com/copilot_internal/v2/token") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("token \(self.token)", forHTTPHeaderField: "Authorization")
        self.addCommonHeaders(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotUsageFetchError.invalidResponse(details: "token exchange missing HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = self.errorSnippet(from: data)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw CopilotUsageFetchError.unauthorized(details: "token exchange HTTP \(httpResponse.statusCode). \(body)")
            }
            throw CopilotUsageFetchError.invalidResponse(
                details: "token exchange HTTP \(httpResponse.statusCode). \(body)")
        }

        let decoded = try JSONDecoder().decode(CopilotSessionTokenResponse.self, from: data)
        let cleaned = decoded.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw CopilotUsageFetchError.invalidResponse(details: "token exchange returned empty token")
        }
        return cleaned
    }

    private func makeSnapshot(from usage: CopilotUsageResponse) throws -> UsageSnapshot {
        let resetDate = self.parseDate(usage.quotaResetDate)
        let orderedSnapshots = self.orderedQuotaSnapshots(usage.quotaSnapshots)
        guard !orderedSnapshots.isEmpty else {
            throw CopilotUsageFetchError.noQuotaData
        }
        let primary = self.makeRateWindow(from: orderedSnapshots.first, resetAt: resetDate)
        let secondary = self.makeRateWindow(
            from: orderedSnapshots.count > 1 ? orderedSnapshots[1] : nil,
            resetAt: resetDate)
        let tertiary = self.makeRateWindow(
            from: orderedSnapshots.count > 2 ? orderedSnapshots[2] : nil,
            resetAt: resetDate)

        let resolvedPrimary = primary ?? RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: resetDate,
            resetDescription: nil)

        let plan = usage.copilotPlan?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        let organization = usage.organizationList?.first?.login ??
            usage.organizationList?.first?.name ??
            usage.organizationLoginList?.first
        let identity = ProviderIdentitySnapshot(
            providerID: .copilot,
            accountEmail: nil,
            accountOrganization: organization,
            loginMethod: plan)
        return UsageSnapshot(
            primary: resolvedPrimary,
            secondary: secondary,
            tertiary: tertiary,
            providerCost: nil,
            updatedAt: Date(),
            identity: identity)
    }

    private func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
        request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")
    }

    private func makeRateWindow(
        from snapshot: CopilotUsageResponse.QuotaSnapshot?,
        resetAt: Date?) -> RateWindow?
    {
        guard let snapshot else { return nil }
        guard let percentRemaining = snapshot.normalizedPercentRemaining else { return nil }
        let usedPercent = max(0, min(100, 100 - percentRemaining))

        return RateWindow(
            usedPercent: usedPercent,
            windowMinutes: nil,
            resetsAt: resetAt,
            resetDescription: nil,
            label: self.quotaLabel(snapshot.quotaId))
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let parsed = try? Date(raw, strategy: .iso8601) {
            return parsed
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func quotaLabel(_ quotaID: String?) -> String? {
        guard let quotaID = quotaID?.trimmingCharacters(in: .whitespacesAndNewlines), !quotaID.isEmpty else {
            return nil
        }
        return quotaID
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private func orderedQuotaSnapshots(_ snapshots: CopilotUsageResponse.QuotaSnapshots?) -> [CopilotUsageResponse.QuotaSnapshot] {
        guard let snapshots else { return [] }
        let candidates = [snapshots.premiumInteractions, snapshots.completions, snapshots.chat]
        var ordered: [CopilotUsageResponse.QuotaSnapshot] = []
        var seen: Set<String> = []

        for candidate in candidates {
            guard let candidate else { continue }
            let fingerprint = self.quotaFingerprint(candidate)
            guard seen.insert(fingerprint).inserted else { continue }
            ordered.append(candidate)
        }
        return ordered
    }

    private func quotaFingerprint(_ snapshot: CopilotUsageResponse.QuotaSnapshot) -> String {
        if let quotaID = snapshot.quotaId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !quotaID.isEmpty
        {
            return "id:\(quotaID.lowercased())"
        }
        return "fallback:\(snapshot.entitlement ?? -1)|\(snapshot.normalizedRemaining ?? -1)|" +
            "\(snapshot.percentRemaining ?? -1)|\(snapshot.timestampUTC ?? "")"
    }

    private func errorSnippet(from data: Data) -> String {
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "<non-utf8>"
        if text.count <= 220 {
            return text
        }
        let end = text.index(text.startIndex, offsetBy: 220)
        return "\(text[..<end])…"
    }

}
