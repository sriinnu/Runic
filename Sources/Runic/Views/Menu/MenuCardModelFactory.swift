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
        var quotaWindows: [RateWindow]?
        /// False when no live fetch strategy could run (no credential resolved).
        /// Nil/true means a strategy ran — or the provider was never refreshed.
        var liveFetchWasAvailable: Bool = true
        /// Spend and runway derived from recorded balance readings.
        var balanceSpend: BalanceSpendSummary?
        var numberStyle: UsageFormatter.NumberStyle = .abbreviated
        var dateStyle: UsageFormatter.DateStyle = .relative
    }

    static func make(_ input: Input) -> UsageMenuCardView.Model {
        let trimmedError = input.lastError?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedError = (trimmedError?.isEmpty ?? true) ? nil : trimmedError
        // A provider whose usage is attributed out of coding-tool logs (qwen/glm/
        // kimi calls routed through Claude Code) is healthy even with no live
        // credential of its own — "no strategy available" is not actionable when
        // there's real ledger usage to show. Only that case is suppressed: a
        // configured credential that then fails (expired OAuth, rejected key) is
        // a real issue and stays visible even alongside ledger data.
        let hasLedgerData = input.ledgerTopModel != nil || input.ledgerDaily != nil
        let effectiveError = hasLedgerData && !input.liveFetchWasAvailable ? nil : normalizedError
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
        } else if input.provider != .codex, input.snapshot?.balance != nil {
            // The Balance row already shows this number, with its currency.
            nil
        } else {
            Self.creditsLine(metadata: input.metadata, credits: input.credits, error: input.creditsError)
        }
        let creditsHintText = Self.dashboardHint(provider: input.provider, error: input.dashboardError)
        let providerCost: ProviderCostSection? = if !input.showOptionalCreditsAndExtraUsage {
            nil
        } else {
            Self.providerCostSection(provider: input.provider, cost: input.snapshot?.providerCost)
        }
        let tokenUsage = Self.tokenUsageSection(
            provider: input.provider,
            enabled: input.tokenCostUsageEnabled,
            snapshot: input.tokenSnapshot,
            error: input.tokenError,
            numberStyle: input.numberStyle,
            dateStyle: input.dateStyle)
        let topModelLine = Self.topModelLine(
            input.ledgerTopModel,
            contextLabel: input.ledgerTopModelContextLabel,
            numberStyle: input.numberStyle)
        let insights = Self.removingModelLine(from: Self.insightsSection(input: input), when: topModelLine != nil)
        let subtitle = Self.subtitle(
            snapshot: input.snapshot,
            isRefreshing: input.isRefreshing,
            lastError: effectiveError,
            ledgerUpdatedAt: input.ledgerUpdatedAt,
            dateStyle: input.dateStyle)
        let headerBadge: HeaderBadge? = if input.isRefreshing {
            HeaderBadge(text: "Refreshing", style: .info)
        } else if effectiveError != nil {
            HeaderBadge(text: "Issue", style: .error)
        } else {
            Self.balanceBadge(balance: input.snapshot?.balance, spend: input.balanceSpend)
        }
        let placeholder = input.snapshot == nil && !input.isRefreshing && effectiveError == nil && !hasLedgerData
            ? "No usage yet" : nil

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
            // The credits gauge reads "remaining of 1,000 credits" — a
            // codex-specific scale. Other providers' CreditsSnapshots carry
            // currency-like balances with no unit or denominator information,
            // so they render as a text line only (no bar against an invented
            // 1K-credit scale).
            creditsRemaining: input.provider == .codex ? input.credits?.remaining : nil,
            creditsHintText: creditsHintText,
            creditsHintCopyText: (input.dashboardError?.isEmpty ?? true) ? nil : input.dashboardError,
            providerCost: providerCost,
            tokenUsage: tokenUsage,
            insights: insights,
            placeholder: placeholder,
            progressColor: Self.progressColor(for: input.provider),
            needsCredentials: !input.liveFetchWasAvailable)
    }

    private static func topModelLine(
        _ summary: UsageLedgerModelSummary?,
        contextLabel: String?,
        numberStyle: UsageFormatter.NumberStyle = .abbreviated) -> String?
    {
        guard let summary else { return nil }
        let modelName = UsageFormatter.modelDisplayName(summary.model)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens, style: numberStyle)
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
        lastError: String?,
        ledgerUpdatedAt: Date? = nil,
        dateStyle: UsageFormatter.DateStyle = .relative) -> (text: String, style: SubtitleStyle)
    {
        if let lastError, !lastError.isEmpty {
            return (lastError.trimmingCharacters(in: .whitespacesAndNewlines), .error)
        }

        if isRefreshing, snapshot == nil {
            return ("Refreshing...", .loading)
        }

        if let updated = snapshot?.updatedAt {
            return (UsageFormatter.updatedString(from: updated, style: dateStyle), .info)
        }

        if let ledgerUpdated = ledgerUpdatedAt {
            return (UsageFormatter.updatedString(from: ledgerUpdated, style: dateStyle), .info)
        }

        return ("Not fetched yet", .info)
    }

    private static func metrics(input: Input) -> [Metric] {
        let percentStyle: PercentStyle = input.usageBarsShowUsed ? .used : .left
        // A configured rolling-window quota (e.g. a DashScope Token Plan request
        // budget) overrides the live gauge: the provider's own API may expose no
        // denominator, but Runic reconstructs one from log-derived usage.
        if let quota = input.quotaWindows, !quota.isEmpty {
            return quota.prefix(3).enumerated().map { idx, window in
                Metric(
                    id: "quota-\(idx)",
                    title: Self.quotaWindowLabel(window),
                    percent: Self.clamped(window.usedPercent),
                    percentStyle: percentStyle,
                    resetText: nil,
                    detailText: window.resetDescription)
            }
        }
        guard let snapshot = input.snapshot else { return [] }
        var metrics: [Metric] = []
        let zaiUsage = input.provider == .zai ? snapshot.zaiUsage : nil
        let zaiTokenDetail = Self.zaiLimitDetailText(limit: zaiUsage?.tokenLimit, numberStyle: input.numberStyle)
        let zaiTimeDetail = Self.zaiLimitDetailText(limit: zaiUsage?.timeLimit, numberStyle: input.numberStyle)
        // Banked resets ride on the primary window's detail line: that is the
        // window the user will spend one on.
        let bankedResets = snapshot.resetCredits.flatMap { ResetCreditEntry.summaryLine(for: $0, now: input.now) }
        // Kimi keys are either Open Platform (a balance, titled by metadata) or a
        // Kimi Code subscription (5h / weekly windows that name themselves).
        let windowsNameThemselves = input.provider.brandRoot == .kimi
        func title(_ window: RateWindow, fallback: String) -> String {
            guard windowsNameThemselves || fallback.isEmpty,
                  let own = window.label?.trimmingCharacters(in: .whitespacesAndNewlines), !own.isEmpty
            else { return fallback }
            return own
        }
        if let balance = snapshot.balance, snapshot.primary.hasKnownLimit == false {
            // A plain prepaid balance: the amount, and what it's made of.
            metrics.append(Metric(
                id: "primary",
                title: "Balance",
                percent: nil,
                percentStyle: percentStyle,
                resetText: BalanceFormatter.amount(balance.available, currency: balance.currency),
                detailText: balance.blocksAPICalls
                    ? "API calls blocked · top up to resume"
                    : Self.balanceComponentsText(balance)))
        } else {
            metrics.append(Metric(
                id: "primary",
                title: title(snapshot.primary, fallback: input.metadata.sessionLabel),
                percent: Self.metricPercent(for: snapshot.primary, showUsed: input.usageBarsShowUsed),
                percentStyle: percentStyle,
                resetText: Self.resetText(for: snapshot.primary, prefersCountdown: true),
                detailText: input.provider == .zai ? zaiTokenDetail : bankedResets))
        }
        if snapshot.balance != nil {
            // Without two readings there is nothing to diff yet; say so rather
            // than hiding the row, so a balance-only card never looks final.
            metrics.append(Metric(
                id: "balance-spend",
                title: "Spend",
                percent: nil,
                percentStyle: percentStyle,
                resetText: input.balanceSpend.map(Self.balanceSpendText) ?? Self.balanceSpendPendingText,
                detailText: input.balanceSpend.map { Self.balanceRunwayText($0, now: input.now) }
                    ?? Self.balanceSpendPendingDetail))
        }
        if let weekly = snapshot.secondary {
            let paceText = UsagePaceText.weekly(provider: input.provider, window: weekly, now: input.now)
            metrics.append(Metric(
                id: "secondary",
                title: title(weekly, fallback: input.metadata.weeklyLabel),
                percent: Self.metricPercent(for: weekly, showUsed: input.usageBarsShowUsed),
                percentStyle: percentStyle,
                resetText: Self.resetText(for: weekly, prefersCountdown: true),
                detailText: input.provider == .zai ? zaiTimeDetail : paceText))
        }
        if let tertiary = snapshot.tertiary {
            // Render the tertiary window whenever the snapshot has one (Copilot
            // Chat, Gemini's third model, a Codex extra limit, a Claude
            // model-scoped weekly...). A window that names itself wins;
            // opus-style providers keep their metadata label otherwise.
            let fallbackTitle = input.metadata.opusLabel ?? "Sonnet"
            let ownLabel = tertiary.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = ownLabel.isEmpty ? fallbackTitle : ownLabel
            metrics.append(Metric(
                id: "tertiary",
                title: title,
                percent: Self.metricPercent(for: tertiary, showUsed: input.usageBarsShowUsed),
                percentStyle: percentStyle,
                resetText: Self.resetText(for: tertiary, prefersCountdown: true),
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

    /// Percent for a metric gauge, honoring the used/left toggle.
    /// Returns `nil` for informational windows without a real limit so the
    /// card shows their text (balance, counters) instead of a fake 0% bar.
    private static func metricPercent(for window: RateWindow, showUsed: Bool) -> Double? {
        guard window.hasKnownLimit != false else { return nil }
        return self.clamped(showUsed ? window.usedPercent : window.remainingPercent)
    }

    /// Under a day of runway at the recent burn rate.
    static let lowBalanceRunwayDays = 1.0

    /// "Top up" when calls are already failing, "Low balance" when the recent
    /// burn rate empties it within a day. Errors and refreshes take precedence.
    static func balanceBadge(balance: ProviderBalance?, spend: BalanceSpendSummary?) -> HeaderBadge? {
        guard let balance else { return nil }
        if balance.blocksAPICalls { return HeaderBadge(text: "Top up", style: .error) }
        if let runway = spend?.runwayDays, runway < Self.lowBalanceRunwayDays {
            return HeaderBadge(text: "Low balance", style: .warning)
        }
        return nil
    }

    static func balanceComponentsText(_ balance: ProviderBalance) -> String? {
        let parts = balance.components
            .filter { $0.amount > 0.000_001 }
            .map { "\(BalanceFormatter.amount($0.amount, currency: balance.currency)) \($0.label.lowercased())" }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static let balanceSpendPendingText = "Measuring…"
    static let balanceSpendPendingDetail =
        "This provider only reports a balance; spend appears after the next reading (every 20 min)"

    /// "¥89.14 today · ¥120.30 this month".
    /// A period with no reading yet reads "—", never a made-up zero.
    static func balanceSpendText(_ spend: BalanceSpendSummary) -> String {
        let today = spend.todayKnown ? BalanceFormatter.amount(spend.spentToday, currency: spend.currency) : "—"
        let month = spend.monthKnown
            ? BalanceFormatter.amount(spend.spentThisMonth, currency: spend.currency)
            : "—"
        return "\(today) today · \(month) this month"
    }

    /// "~1.2 days left at ¥89.14/day · tracked since 4:10 PM". Totals only cover
    /// time Runic was recording, so a partial period says when that began.
    static func balanceRunwayText(_ spend: BalanceSpendSummary, now: Date, calendar: Calendar = .current) -> String {
        // Where the number comes from: the provider's own totals, or the
        // difference between balance readings Runic took.
        var parts: [String] = [spend.isEstimated ? "Estimated" : "Official"]
        if let rate = spend.dailyBurnRate, let runway = spend.runwayDays {
            let perDay = BalanceFormatter.amount(rate, currency: spend.currency)
            parts.append("\(Self.runwayPhrase(days: runway)) at \(perDay)/day")
        }
        if let scope = spend.scope {
            parts.append(scope)
        }
        if spend.monthIsPartial {
            let sinceToday = calendar.isDate(spend.trackedSince, inSameDayAs: now)
            let since = sinceToday
                ? spend.trackedSince.formatted(date: .omitted, time: .shortened)
                : spend.trackedSince.formatted(.dateTime.month(.abbreviated).day())
            parts.append("tracked since \(since)")
        }
        return parts.joined(separator: " · ")
    }

    static func runwayPhrase(days: Double) -> String {
        if days < 1 { return "~\(max(1, Int((days * 24).rounded())))h left" }
        if days < 10 { return String(format: "~%.1f days left", days) }
        if days > 365 { return "over a year left" }
        return "~\(Int(days.rounded())) days left"
    }

    /// Compact label for a quota window, derived from its length in minutes.
    private static func quotaWindowLabel(_ window: RateWindow) -> String {
        if let label = window.label { return label }
        guard let minutes = window.windowMinutes else { return "Quota" }
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 { return "\(minutes / 60)h" }
        return "\(minutes / 1440)d"
    }

    private static func zaiLimitDetailText(
        limit: ZaiLimitEntry?,
        numberStyle: UsageFormatter.NumberStyle = .abbreviated) -> String?
    {
        guard let limit else { return nil }
        let currentStr = UsageFormatter.tokenCountString(limit.currentValue, style: numberStyle)
        let usageStr = UsageFormatter.tokenCountString(limit.usage, style: numberStyle)
        let remainingStr = UsageFormatter.tokenCountString(limit.remaining, style: numberStyle)
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
        error: String?,
        numberStyle: UsageFormatter.NumberStyle = .abbreviated,
        dateStyle: UsageFormatter.DateStyle = .relative) -> TokenUsageSection?
    {
        guard provider == .codex || provider == .claude else { return nil }
        guard enabled else { return nil }
        guard let snapshot else { return nil }

        let sessionCostValue = snapshot.sessionCostUSD
        let sessionCost = sessionCostValue.map { UsageFormatter.usdString($0) } ?? "—"
        let sessionTokens = snapshot.sessionTokens.map { UsageFormatter.tokenCountString($0, style: numberStyle) }
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
        let monthTokens = monthTokensValue.map { UsageFormatter.tokenCountString($0, style: numberStyle) }
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
                parts.append("Avg \(UsageFormatter.tokenCountString(avgTokensPerDay, style: numberStyle)) tok/day")
            }

            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }()
        let updatedLine = UsageFormatter.updatedString(from: snapshot.updatedAt, style: dateStyle)
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
        guard provider == .claude || provider == .cursor else { return nil }
        guard let cost else { return nil }
        let title = provider == .cursor ? "On-demand usage" : "Extra usage"
        let used = UsageFormatter.currencyString(cost.used, currencyCode: cost.currencyCode)

        guard cost.limit > 0 else {
            // Cursor reports on-demand spend without a limit when the plan is
            // unlimited — show the spend without a fabricated gauge. Claude
            // keeps requiring a limit, matching its previous behavior.
            guard provider == .cursor, cost.used > 0 else { return nil }
            return ProviderCostSection(
                title: title,
                percentUsed: nil,
                spendLine: "This month: \(used)")
        }

        let limit = UsageFormatter.currencyString(cost.limit, currencyCode: cost.currencyCode)
        let percentUsed = Self.clamped((cost.used / cost.limit) * 100)

        return ProviderCostSection(
            title: title,
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
        // Both halves of the story: how long until the window flips, and the
        // wall-clock moment it happens. Providers that only hand us a phrase
        // ("resets in 3h") get the phrase parsed into a real date.
        if let date = window.resetsAt ?? UsageResetParsing.date(fromRelative: window.resetDescription) {
            let expiry = UsageFormatter.resetExpiryString(from: date)
            if prefersCountdown {
                return "Resets \(UsageFormatter.resetCountdownDescription(from: date)) · \(expiry)"
            }
            return "Resets \(expiry)"
        }

        if let desc = window.resetDescription, !desc.isEmpty {
            return desc
        }
        return nil
    }
}
