import Foundation

public struct GeminiModelQuota: Sendable {
    public let modelId: String
    public let percentLeft: Double
    public let resetTime: Date?
    public let resetDescription: String?
}

public struct GeminiStatusSnapshot: Sendable {
    public let modelQuotas: [GeminiModelQuota]
    public let rawText: String
    public let accountEmail: String?
    public let accountPlan: String?

    // Convenience: lowest quota across all models (for icon display)
    public var lowestPercentLeft: Double? {
        self.modelQuotas.min(by: { $0.percentLeft < $1.percentLeft })?.percentLeft
    }

    /// Legacy compatibility
    public var dailyPercentLeft: Double? {
        self.lowestPercentLeft
    }

    public var resetDescription: String? {
        self.modelQuotas.min(by: { $0.percentLeft < $1.percentLeft })?.resetDescription
    }

    /// Converts Gemini quotas to a unified UsageSnapshot.
    /// Prioritizes Pro and Flash tiers, then fills an optional tertiary slot with the next-most-constrained model.
    public func toUsageSnapshot() -> UsageSnapshot {
        let selected = Self.selectDisplayQuotas(self.modelQuotas)
        let primaryQuota = selected.first
        let secondaryQuota = selected.count > 1 ? selected[1] : nil
        let tertiaryQuota = selected.count > 2 ? selected[2] : nil

        let primary = Self.rateWindow(from: primaryQuota) ?? RateWindow(
            usedPercent: 0,
            windowMinutes: 1440,
            resetsAt: nil,
            resetDescription: nil,
            label: nil)
        let secondary = Self.rateWindow(from: secondaryQuota)
        let tertiary = Self.rateWindow(from: tertiaryQuota)

        let identity = ProviderIdentitySnapshot(
            providerID: .gemini,
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

    private static func selectDisplayQuotas(_ quotas: [GeminiModelQuota]) -> [GeminiModelQuota] {
        guard !quotas.isEmpty else { return [] }

        let normalized = quotas.map { (quota: $0, lowerModelID: $0.modelId.lowercased()) }
        let pro = normalized
            .filter { $0.lowerModelID.contains("pro") }
            .map(\.quota)
            .min(by: { $0.percentLeft < $1.percentLeft })
        let flash = normalized
            .filter { $0.lowerModelID.contains("flash") }
            .map(\.quota)
            .min(by: { $0.percentLeft < $1.percentLeft })

        var ordered: [GeminiModelQuota] = []
        if let pro {
            ordered.append(pro)
        }
        if let flash, !Self.containsModel(ordered, matching: flash) {
            ordered.append(flash)
        }

        for quota in quotas.sorted(by: { lhs, rhs in
            if lhs.percentLeft == rhs.percentLeft {
                return lhs.modelId.localizedCaseInsensitiveCompare(rhs.modelId) == .orderedAscending
            }
            return lhs.percentLeft < rhs.percentLeft
        }) where ordered.count < 3 {
            guard !Self.containsModel(ordered, matching: quota) else { continue }
            ordered.append(quota)
        }

        return Array(ordered.prefix(3))
    }

    private static func containsModel(_ quotas: [GeminiModelQuota], matching candidate: GeminiModelQuota) -> Bool {
        let normalized = candidate.modelId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return quotas.contains {
            $0.modelId
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == normalized
        }
    }

    private static func rateWindow(from quota: GeminiModelQuota?) -> RateWindow? {
        guard let quota else { return nil }
        return RateWindow(
            usedPercent: max(0, min(100, 100 - quota.percentLeft)),
            windowMinutes: 1440,
            resetsAt: quota.resetTime,
            resetDescription: quota.resetDescription,
            label: self.formattedModelLabel(quota.modelId))
    }

    private static func formattedModelLabel(_ modelID: String) -> String? {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lastPathComponent = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        let normalized = lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
