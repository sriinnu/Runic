import Foundation

public struct AntigravityModelQuota: Sendable {
    public let label: String
    public let modelId: String
    public let remainingFraction: Double?
    public let resetTime: Date?
    public let resetDescription: String?
    public let windowMinutes: Int?

    public init(
        label: String,
        modelId: String,
        remainingFraction: Double?,
        resetTime: Date?,
        resetDescription: String?,
        windowMinutes: Int? = nil)
    {
        self.label = label
        self.modelId = modelId
        self.remainingFraction = remainingFraction
        self.resetTime = resetTime
        self.resetDescription = resetDescription
        self.windowMinutes = windowMinutes
    }

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
        let primary = ordered.first.map { Self.rateWindow(for: $0) } ?? .noLimitsReported
        let secondary = ordered.count > 1 ? Self.rateWindow(for: ordered[1]) : nil
        let tertiary = ordered.count > 2 ? Self.rateWindow(for: ordered[2]) : nil
        let additional = ordered.count > 3 ? ordered.dropFirst(3).map { Self.rateWindow(for: $0) } : nil

        let identity = ProviderIdentitySnapshot(
            providerID: .antigravity,
            accountEmail: self.accountEmail,
            accountOrganization: nil,
            loginMethod: self.accountPlan)
        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            additionalWindows: additional,
            updatedAt: Date(),
            identity: identity)
    }

    private static func rateWindow(for quota: AntigravityModelQuota) -> RateWindow {
        RateWindow(
            usedPercent: 100 - quota.remainingPercent,
            windowMinutes: quota.windowMinutes,
            resetsAt: quota.resetTime,
            resetDescription: quota.resetDescription,
            label: self.formattedModelLabel(quota))
    }

    private static func groupRank(_ quota: AntigravityModelQuota) -> Int {
        let model = quota.modelId.lowercased()
        let label = quota.label.lowercased()
        if model.contains("gemini") || label.contains("gemini") { return 0 }
        if model.contains("claude") || model.contains("gpt") || label.contains("claude") || label.contains("gpt") {
            return 1
        }
        return 2
    }

    /// Deterministic ordering: Antigravity's native Gemini group leads so external
    /// model groups (e.g. Claude & GPT Weekly) never hijack the primary slot or
    /// menubar percentage, followed by shortest reset window (5h ahead of Weekly),
    /// then most-constrained remaining headroom within the same group and span.
    private static func selectModels(_ models: [AntigravityModelQuota]) -> [AntigravityModelQuota] {
        models.sorted { lhs, rhs in
            let lhsGroup = Self.groupRank(lhs)
            let rhsGroup = Self.groupRank(rhs)
            if lhsGroup != rhsGroup {
                return lhsGroup < rhsGroup
            }
            let lhsMinutes = lhs.windowMinutes ?? Int.max
            let rhsMinutes = rhs.windowMinutes ?? Int.max
            if lhsMinutes != rhsMinutes {
                return lhsMinutes < rhsMinutes
            }
            if lhs.remainingPercent != rhs.remainingPercent {
                return lhs.remainingPercent < rhs.remainingPercent
            }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
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
    case standaloneTokenUnavailable(version: String?)
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
        case let .standaloneTokenUnavailable(version):
            if let version, !version.isEmpty {
                "Antigravity \(version) hides its local token. Install Antigravity CLI (agy) to read live quota."
            } else {
                "Antigravity 2.x hides its local token. Install Antigravity CLI (agy) to read live quota."
            }
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
