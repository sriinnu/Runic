import Foundation
import RunicCore
import SwiftUI

// MARK: - Model factory

extension UsageMenuCardView.Model {
    struct Input {
        let provider: UsageProvider
        let metadata: ProviderMetadata
        let snapshot: UsageSnapshot?
        let credits: CreditsSnapshot?
        let creditsError: String?
        let dashboard: OpenAIDashboardSnapshot?
        let dashboardError: String?
        let tokenSnapshot: CostUsageTokenSnapshot?
        let tokenError: String?
        let ledgerDaily: UsageLedgerDailySummary?
        let ledgerActiveBlock: UsageLedgerBlockSummary?
        let ledgerTopModel: UsageLedgerModelSummary?
        let ledgerTopModelContextLabel: String?
        let ledgerTopProject: UsageLedgerProjectSummary?
        let ledgerSpendForecast: UsageLedgerSpendForecast?
        let ledgerTopProjectSpendForecast: UsageLedgerSpendForecast?
        let ledgerAnomaly: UsageLedgerAnomalySummary?
        let ledgerCompaction: UsageLedgerCompactionSummary?
        let ledgerReliability: UsageLedgerReliabilityScore?
        let ledgerRouting: UsageLedgerRoutingRecommendation?
        let ledgerError: String?
        let ledgerUpdatedAt: Date?
        let providerContextStatus: ProviderContextWindowLabel?
        let account: AccountInfo
        let isRefreshing: Bool
        let lastError: String?
        let usageBarsShowUsed: Bool
        let usageMetricDisplayMode: UsageMetricDisplayMode
        let menuMode: MenuMode
        let tokenCostUsageEnabled: Bool
        let showOptionalCreditsAndExtraUsage: Bool
        let now: Date
    }

    static func make(_ input: Input) -> UsageMenuCardView.Model {
        let trimmedError = input.lastError?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedError = (trimmedError?.isEmpty ?? true) ? nil : trimmedError
        let email = Self.email(
            for: input.provider,
            snapshot: input.snapshot,
            account: input.account,
            metadata: input.metadata)
        let planText = Self.plan(
            for: input.provider,
            snapshot: input.snapshot,
            account: input.account,
            metadata: input.metadata)
        let metrics = Self.metrics(input: input)
        let creditsText: String? = if input.provider == .codex, !input.showOptionalCreditsAndExtraUsage {
            nil
        } else {
            Self.creditsLine(metadata: input.metadata, credits: input.credits, error: input.creditsError)
        }
        let creditsHintText = Self.dashboardHint(provider: input.provider, error: input.dashboardError)
        let providerCost: ProviderCostSection? = if input.provider == .claude, !input.showOptionalCreditsAndExtraUsage {
            nil
        } else {
            Self.providerCostSection(provider: input.provider, cost: input.snapshot?.providerCost)
        }
        let tokenUsage = Self.tokenUsageSection(
            provider: input.provider,
            enabled: input.tokenCostUsageEnabled,
            snapshot: input.tokenSnapshot,
            error: input.tokenError)
        let topModelLine = Self.topModelLine(input.ledgerTopModel, contextLabel: input.ledgerTopModelContextLabel)
        let insights = Self.removingModelLine(from: Self.insightsSection(input: input), when: topModelLine != nil)
        let subtitle = Self.subtitle(
            snapshot: input.snapshot,
            isRefreshing: input.isRefreshing,
            lastError: normalizedError)
        let headerBadge: HeaderBadge? = if input.isRefreshing {
            HeaderBadge(text: "Refreshing", style: .info)
        } else if normalizedError != nil {
            HeaderBadge(text: "Issue", style: .error)
        } else {
            nil
        }
        let placeholder = input.snapshot == nil && !input.isRefreshing && normalizedError == nil ? "No usage yet" : nil

        return UsageMenuCardView.Model(
            provider: input.provider,
            providerName: input.metadata.displayName,
            email: email,
            subtitleText: subtitle.text,
            subtitleStyle: subtitle.style,
            planText: planText,
            topModelLine: topModelLine,
            headerBadge: headerBadge,
            metrics: metrics,
            usageMetricDisplayMode: input.usageMetricDisplayMode,
            menuMode: input.menuMode,
            creditsText: creditsText,
            creditsRemaining: input.credits?.remaining,
            creditsHintText: creditsHintText,
            creditsHintCopyText: (input.dashboardError?.isEmpty ?? true) ? nil : input.dashboardError,
            providerCost: providerCost,
            tokenUsage: tokenUsage,
            insights: insights,
            placeholder: placeholder,
            progressColor: Self.progressColor(for: input.provider))
    }

    private static func topModelLine(_ summary: UsageLedgerModelSummary?, contextLabel: String?) -> String? {
        guard let summary else { return nil }
        let modelName = UsageFormatter.modelDisplayName(summary.model)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        var parts = ["Top model: \(modelName)", "\(tokens) tokens", "\(summary.entryCount) req"]
        if let contextLabel {
            parts.append(contextLabel)
        }
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
            if let per1K = UsageFormatter.usdPer1KTokensString(
                costUSD: cost,
                tokenCount: summary.totals.totalTokens)
            {
                parts.append(per1K)
            }
        }
        return parts.joined(separator: " · ")
    }

    private static func removingModelLine(
        from section: InsightsSection?,
        when remove: Bool) -> InsightsSection?
    {
        guard remove, let section else { return section }
        return InsightsSection(
            title: section.title,
            connectionLine: section.connectionLine,
            connectionDetail: section.connectionDetail,
            contextLine: section.contextLine,
            contextDetail: section.contextDetail,
            compactionLine: section.compactionLine,
            compactionDetail: section.compactionDetail,
            todayLine: section.todayLine,
            todayDetail: section.todayDetail,
            forecastLine: section.forecastLine,
            blockLine: section.blockLine,
            blockDetail: section.blockDetail,
            modelLine: nil,
            projectLine: section.projectLine,
            projectDetail: section.projectDetail,
            anomalyLine: section.anomalyLine,
            anomalyDetail: section.anomalyDetail,
            reliabilityLine: section.reliabilityLine,
            reliabilityDetail: section.reliabilityDetail,
            routingLine: section.routingLine,
            routingDetail: section.routingDetail,
            updatedLine: section.updatedLine,
            errorLine: section.errorLine)
    }

    static func email(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        account: AccountInfo,
        metadata: ProviderMetadata) -> String
    {
        let resolved: String = {
            if let email = snapshot?.accountEmail(for: provider), !email.isEmpty { return email }
            if metadata.usesAccountFallback,
               let email = account.email, !email.isEmpty
            {
                return email
            }
            return ""
        }()
        return RunicScreenshotMode.sanitize(email: resolved) ?? resolved
    }

    private static func plan(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        account: AccountInfo,
        metadata: ProviderMetadata) -> String?
    {
        if let plan = snapshot?.loginMethod(for: provider), !plan.isEmpty {
            return self.planDisplay(plan)
        }
        if metadata.usesAccountFallback,
           let plan = account.plan, !plan.isEmpty
        {
            return Self.planDisplay(plan)
        }
        return nil
    }

    private static func planDisplay(_ text: String) -> String {
        let cleaned = UsageFormatter.cleanPlanName(text)
        return cleaned.isEmpty ? text : cleaned
    }

    private static func subtitle(
        snapshot: UsageSnapshot?,
        isRefreshing: Bool,
        lastError: String?) -> (text: String, style: SubtitleStyle)
    {
        if let lastError, !lastError.isEmpty {
            return (lastError.trimmingCharacters(in: .whitespacesAndNewlines), .error)
        }

        if isRefreshing, snapshot == nil {
            return ("Refreshing...", .loading)
        }

        if let updated = snapshot?.updatedAt {
            return (UsageFormatter.updatedString(from: updated), .info)
        }

        return ("Not fetched yet", .info)
    }

    private static func metrics(input: Input) -> [Metric] {
        guard let snapshot = input.snapshot else { return [] }
        var metrics: [Metric] = []
        let percentStyle: PercentStyle = input.usageBarsShowUsed ? .used : .left
        let zaiUsage = input.provider == .zai ? snapshot.zaiUsage : nil
        let zaiTokenDetail = Self.zaiLimitDetailText(limit: zaiUsage?.tokenLimit)
        let zaiTimeDetail = Self.zaiLimitDetailText(limit: zaiUsage?.timeLimit)
        metrics.append(Metric(
            id: "primary",
            title: input.metadata.sessionLabel,
            percent: Self.clamped(
                input.usageBarsShowUsed ? snapshot.primary.usedPercent : snapshot.primary.remainingPercent),
            percentStyle: percentStyle,
            resetText: Self.resetText(for: snapshot.primary, prefersCountdown: true),
            detailText: input.provider == .zai ? zaiTokenDetail : nil))
        if let weekly = snapshot.secondary {
            let paceText = UsagePaceText.weekly(provider: input.provider, window: weekly, now: input.now)
            metrics.append(Metric(
                id: "secondary",
                title: input.metadata.weeklyLabel,
                percent: Self.clamped(input.usageBarsShowUsed ? weekly.usedPercent : weekly.remainingPercent),
                percentStyle: percentStyle,
                resetText: Self.resetText(for: weekly, prefersCountdown: true),
                detailText: input.provider == .zai ? zaiTimeDetail : paceText))
        }
        if input.metadata.supportsOpus, let opus = snapshot.tertiary {
            metrics.append(Metric(
                id: "tertiary",
                title: input.metadata.opusLabel ?? "Sonnet",
                percent: Self.clamped(input.usageBarsShowUsed ? opus.usedPercent : opus.remainingPercent),
                percentStyle: percentStyle,
                resetText: Self.resetText(for: opus, prefersCountdown: true),
                detailText: nil))
        }

        if input.provider == .codex, let remaining = input.dashboard?.codeReviewRemainingPercent {
            let percent = input.usageBarsShowUsed ? (100 - remaining) : remaining
            metrics.append(Metric(
                id: "code-review",
                title: "Code review",
                percent: Self.clamped(percent),
                percentStyle: percentStyle,
                resetText: nil,
                detailText: nil))
        }
        return metrics
    }

    private static func zaiLimitDetailText(limit: ZaiLimitEntry?) -> String? {
        guard let limit else { return nil }
        let currentStr = UsageFormatter.tokenCountString(limit.currentValue)
        let usageStr = UsageFormatter.tokenCountString(limit.usage)
        let remainingStr = UsageFormatter.tokenCountString(limit.remaining)
        return "\(currentStr) / \(usageStr) (\(remainingStr) remaining)"
    }

    private static func creditsLine(
        metadata: ProviderMetadata,
        credits: CreditsSnapshot?,
        error: String?) -> String?
    {
        guard metadata.supportsCredits else { return nil }
        if let credits {
            return UsageFormatter.creditsString(from: credits.remaining)
        }
        if let error, !error.isEmpty {
            return error.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return metadata.creditsHint
    }

    private static func dashboardHint(provider: UsageProvider, error: String?) -> String? {
        guard provider == .codex else { return nil }
        guard let error, !error.isEmpty else { return nil }
        return error
    }

    private static func tokenUsageSection(
        provider: UsageProvider,
        enabled: Bool,
        snapshot: CostUsageTokenSnapshot?,
        error: String?) -> TokenUsageSection?
    {
        guard provider == .codex || provider == .claude else { return nil }
        guard enabled else { return nil }
        guard let snapshot else { return nil }

        let sessionCostValue = snapshot.sessionCostUSD
        let sessionCost = sessionCostValue.map { UsageFormatter.usdString($0) } ?? "—"
        let sessionTokens = snapshot.sessionTokens.map { UsageFormatter.tokenCountString($0) }
        let sessionLine: String = {
            if let sessionTokens {
                return "Today: \(sessionCost) · \(sessionTokens) tokens"
            }
            return "Today: \(sessionCost)"
        }()
        let sessionDetailLine: String? = {
            guard let cost = sessionCostValue,
                  let tokens = snapshot.sessionTokens,
                  let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: tokens)
            else {
                return nil
            }
            return "Today efficiency: \(per1K)"
        }()

        let fallbackCost = snapshot.daily.compactMap(\.costUSD).reduce(0, +)
        let monthCostValue = snapshot.last30DaysCostUSD ?? (fallbackCost > 0 ? fallbackCost : nil)
        let monthCost = monthCostValue.map { UsageFormatter.usdString($0) } ?? "—"
        let fallbackTokens = snapshot.daily.compactMap(\.totalTokens).reduce(0, +)
        let monthTokensValue = snapshot.last30DaysTokens ?? (fallbackTokens > 0 ? fallbackTokens : nil)
        let monthTokens = monthTokensValue.map { UsageFormatter.tokenCountString($0) }
        let monthLine: String = {
            if let monthTokens {
                return "Last 30 days: \(monthCost) · \(monthTokens) tokens"
            }
            return "Last 30 days: \(monthCost)"
        }()
        let monthDetailLine: String? = {
            var parts: [String] = []
            if let cost = monthCostValue,
               let tokens = monthTokensValue,
               let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: tokens)
            {
                parts.append(per1K)
            }

            if let cost = monthCostValue, let tokens = monthTokensValue, tokens > 0 {
                let days = Self.observedUsageDays(snapshot)
                let avgCostPerDay = cost / Double(days)
                let avgTokensPerDay = Int((Double(tokens) / Double(days)).rounded())
                parts.append("Avg \(UsageFormatter.usdRateString(avgCostPerDay))/day")
                parts.append("Avg \(UsageFormatter.tokenCountString(avgTokensPerDay)) tok/day")
            }

            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }()
        let updatedLine = UsageFormatter.updatedString(from: snapshot.updatedAt)
        let err = (error?.isEmpty ?? true) ? nil : error
        let hintLine = err == nil ? "Token totals are estimates and may lag provider dashboards." : nil
        return TokenUsageSection(
            sessionLine: sessionLine,
            sessionDetailLine: sessionDetailLine,
            monthLine: monthLine,
            monthDetailLine: monthDetailLine,
            updatedLine: updatedLine,
            hintLine: hintLine,
            errorLine: err,
            errorCopyText: (error?.isEmpty ?? true) ? nil : error)
    }

    private static func observedUsageDays(_ snapshot: CostUsageTokenSnapshot) -> Int {
        let nonEmptyDays = snapshot.daily.count(where: { entry in
            (entry.totalTokens ?? 0) > 0 || (entry.costUSD ?? 0) > 0
        })
        if nonEmptyDays > 0 {
            return min(30, nonEmptyDays)
        }
        if !snapshot.daily.isEmpty {
            return min(30, snapshot.daily.count)
        }
        return 30
    }

    private static func providerCostSection(
        provider: UsageProvider,
        cost: ProviderCostSnapshot?) -> ProviderCostSection?
    {
        guard provider == .claude else { return nil }
        guard let cost else { return nil }
        guard cost.limit > 0 else { return nil }

        let used = UsageFormatter.currencyString(cost.used, currencyCode: cost.currencyCode)
        let limit = UsageFormatter.currencyString(cost.limit, currencyCode: cost.currencyCode)
        let percentUsed = Self.clamped((cost.used / cost.limit) * 100)

        return ProviderCostSection(
            title: "Extra usage",
            percentUsed: percentUsed,
            spendLine: "This month: \(used) / \(limit)")
    }

    private static func clamped(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private static func progressColor(for provider: UsageProvider) -> Color {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private static func resetText(for window: RateWindow, prefersCountdown: Bool) -> String? {
        if let date = window.resetsAt {
            if prefersCountdown {
                return "Resets \(UsageFormatter.resetCountdownDescription(from: date))"
            }
            return "Resets \(UsageFormatter.resetDescription(from: date))"
        }

        if let desc = window.resetDescription, !desc.isEmpty {
            return desc
        }
        return nil
    }
}
