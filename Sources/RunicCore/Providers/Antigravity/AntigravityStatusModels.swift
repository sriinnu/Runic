import Foundation

public struct AntigravityModelQuota: Sendable {
    public let label: String
    public let modelId: String
    public let remainingFraction: Double?
    public let resetTime: Date?
    public let resetDescription: String?

    public var remainingPercent: Double {
        guard let remainingFraction else { return 0 }
        return max(0, min(100, remainingFraction * 100))
    }
}

public struct AntigravityStatusSnapshot: Sendable {
    public let modelQuotas: [AntigravityModelQuota]
    public let accountEmail: String?
    public let accountPlan: String?

    public func toUsageSnapshot() throws -> UsageSnapshot {
        // A quota with no reported remainingFraction is UNKNOWN, not depleted.
        // Emitting it would render as 0% remaining, fire a false "session
        // depleted" notification, and sort first as most-constrained — drop it.
        let known = self.modelQuotas.filter { $0.remainingFraction != nil }
        let ordered = Self.selectModels(known)
        guard let primaryQuota = ordered.first else {
            throw AntigravityStatusProbeError.parseFailed("No quota models available")
        }

        let primary = Self.rateWindow(for: primaryQuota)
        let secondary = ordered.count > 1 ? Self.rateWindow(for: ordered[1]) : nil
        let tertiary = ordered.count > 2 ? Self.rateWindow(for: ordered[2]) : nil

        let identity = ProviderIdentitySnapshot(
            providerID: .antigravity,
            accountEmail: self.accountEmail,
            accountOrganization: nil,
            loginMethod: self.accountPlan)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            updatedAt: Date(),
            identity: identity)
    }

    private static func rateWindow(for quota: AntigravityModelQuota) -> RateWindow {
        RateWindow(
            usedPercent: 100 - quota.remainingPercent,
            windowMinutes: nil,
            resetsAt: quota.resetTime,
            resetDescription: quota.resetDescription,
            label: self.formattedModelLabel(quota))
    }

    private static func selectModels(_ models: [AntigravityModelQuota]) -> [AntigravityModelQuota] {
        var ordered: [AntigravityModelQuota] = []
        if let claude = models.first(where: { Self.isClaudeWithoutThinking($0.label) }) {
            ordered.append(claude)
        }
        if let pro = models.first(where: { Self.isGeminiProLow($0.label) }),
           !ordered.contains(where: { $0.label == pro.label })
        {
            ordered.append(pro)
        }
        if let flash = models.first(where: { Self.isGeminiFlash($0.label) }),
           !ordered.contains(where: { $0.label == flash.label })
        {
            ordered.append(flash)
        }
        if ordered.isEmpty {
            ordered.append(contentsOf: models.sorted(by: { $0.remainingPercent < $1.remainingPercent }))
        }
        return ordered
    }

    private static func isClaudeWithoutThinking(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("claude") && !lower.contains("thinking")
    }

    private static func isGeminiProLow(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("pro") && lower.contains("low")
    }

    private static func isGeminiFlash(_ label: String) -> Bool {
        let lower = label.lowercased()
        return lower.contains("gemini") && lower.contains("flash")
    }

    private static func formattedModelLabel(_ quota: AntigravityModelQuota) -> String {
        let preferred = quota.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !preferred.isEmpty {
            return preferred
        }
        let fallback = quota.modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.isEmpty {
            return "Model"
        }
        return fallback
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}

public struct AntigravityPlanInfoSummary: Sendable, Codable, Equatable {
    public let planName: String?
    public let planDisplayName: String?
    public let displayName: String?
    public let productName: String?
    public let planShortName: String?
}

public enum AntigravityStatusProbeError: LocalizedError, Sendable, Equatable {
    case notRunning
    case missingCSRFToken
    case portDetectionFailed(String)
    case apiError(String)
    case parseFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            "Antigravity language server not detected. Launch Antigravity and retry."
        case .missingCSRFToken:
            "Antigravity CSRF token not found. Restart Antigravity and retry."
        case let .portDetectionFailed(message):
            Self.portDetectionDescription(message)
        case let .apiError(message):
            Self.apiErrorDescription(message)
        case let .parseFailed(message):
            "Could not parse Antigravity quota: \(message)"
        case .timedOut:
            "Antigravity quota request timed out."
        }
    }

    private static func portDetectionDescription(_ message: String) -> String {
        switch message {
        case "lsof not available":
            "Antigravity port detection needs lsof. Install it, then retry."
        case "no listening ports found":
            "Antigravity is running but not exposing ports yet. Try again in a few seconds."
        default:
            "Antigravity port detection failed: \(message)"
        }
    }

    private static func apiErrorDescription(_ message: String) -> String {
        if message.contains("HTTP 401") || message.contains("HTTP 403") {
            return "Antigravity session expired. Restart Antigravity and retry."
        }
        return "Antigravity API error: \(message)"
    }
}
