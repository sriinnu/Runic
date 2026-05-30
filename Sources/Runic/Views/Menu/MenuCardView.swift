import RunicCore
import SwiftUI

// Structural lint debt: menu card presentation needs more focused subviews/files.
/// **Menu Card Layout Metrics**
/// Defines all spacing and padding constants for the menu card UI.
/// These values are carefully tuned for readability and visual hierarchy.
enum MenuCardMetrics {
    /// Horizontal padding on left/right edges of card content
    static let horizontalPadding: CGFloat = RunicSpacing.sm // 12

    /// Top padding for the header section (provider name, email)
    static let headerTopPadding: CGFloat = RunicSpacing.xxs // 4

    /// Bottom padding for the header section
    static let headerBottomPadding: CGFloat = RunicSpacing.xxs // 4

    /// Top padding for content sections (usage, credits, cost)
    static let sectionTopPadding: CGFloat = RunicSpacing.xs // 8

    /// Bottom padding for content sections
    static let sectionBottomPadding: CGFloat = RunicSpacing.xxs // 4

    /// Vertical spacing between major sections (e.g., Session vs Weekly)
    static let sectionSpacing: CGFloat = RunicSpacing.xs // 8

    /// Spacing between related blocks of content
    static let blockSpacing: CGFloat = RunicSpacing.xs // 8

    /// Spacing between individual text lines within a section
    static let lineSpacing: CGFloat = RunicSpacing.xxs // 4

    /// Base padding for menu items
    static let menuItemBasePadding: CGFloat = RunicSpacing.xxs // 4

    /// Additional padding for text with descenders (y, g, p, q, j)
    static let menuItemDescenderPadding: CGFloat = RunicSpacing.xxxs // 2

    /// Tail padding at the end of sections
    static let tailPadding: CGFloat = RunicSpacing.xxs // 4
    static let metricCardPadding: CGFloat = RunicSpacing.xs // 8
    static let metricCardCornerRadius: CGFloat = RunicCornerRadius.sm
}

/// SwiftUI card used inside the NSMenu to mirror Apple's rich menu panels.
struct UsageMenuCardView: View {
    @Environment(\.runicFonts) private var fonts
    struct Model {
        enum PercentStyle: String {
            case left
            case used

            var labelSuffix: String {
                switch self {
                case .left: "left"
                case .used: "used"
                }
            }

            var accessibilityLabel: String {
                switch self {
                case .left: "Usage remaining"
                case .used: "Usage used"
                }
            }
        }

        struct Metric: Identifiable {
            let id: String
            let title: String
            let percent: Double
            let percentStyle: PercentStyle
            let resetText: String?
            let detailText: String?

            var percentLabel: String {
                String(format: "%.0f%% %@", self.percent, self.percentStyle.labelSuffix)
            }
        }

        enum SubtitleStyle {
            case info
            case loading
            case error
        }

        struct TokenUsageSection {
            let sessionLine: String
            let sessionDetailLine: String?
            let monthLine: String
            let monthDetailLine: String?
            let updatedLine: String
            let hintLine: String?
            let errorLine: String?
            let errorCopyText: String?
        }

        struct ProviderCostSection {
            let title: String
            let percentUsed: Double
            let spendLine: String
        }

        struct InsightsSection {
            let title: String
            let connectionLine: String?
            let connectionDetail: String?
            let contextLine: String?
            let contextDetail: String?
            let compactionLine: String?
            let compactionDetail: String?
            let todayLine: String?
            let todayDetail: String?
            let forecastLine: String?
            let blockLine: String?
            let blockDetail: String?
            let modelLine: String?
            let projectLine: String?
            let projectDetail: String?
            let anomalyLine: String?
            let anomalyDetail: String?
            let reliabilityLine: String?
            let reliabilityDetail: String?
            let routingLine: String?
            let routingDetail: String?
            let updatedLine: String?
            let errorLine: String?
        }

        enum HeaderBadgeStyle {
            case info
            case warning
            case error
        }

        struct HeaderBadge {
            let text: String
            let style: HeaderBadgeStyle
        }

        let provider: UsageProvider
        let providerName: String
        let email: String
        let subtitleText: String
        let subtitleStyle: SubtitleStyle
        let planText: String?
        let topModelLine: String?
        let headerBadge: HeaderBadge?
        let metrics: [Metric]
        let usageMetricDisplayMode: UsageMetricDisplayMode
        let menuMode: MenuMode
        let creditsText: String?
        let creditsRemaining: Double?
        let creditsHintText: String?
        let creditsHintCopyText: String?
        let providerCost: ProviderCostSection?
        let tokenUsage: TokenUsageSection?
        let insights: InsightsSection?
        let placeholder: String?
        let progressColor: Color
    }

    let model: Model
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            UsageMenuCardHeaderView(model: self.model)

            if self.hasDetails {
                RunicDivider()
                    .padding(.vertical, RunicSpacing.xxs)
            }

            if self.model.metrics.isEmpty {
                if let placeholder = self.model.placeholder {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        isHighlighted: self.isHighlighted)
                }
            } else {
                let hasUsage = !self.model.metrics.isEmpty
                let includeSummarySections = self.model.menuMode != .glance
                let includeInsightSections = self.model.menuMode == .operator
                let hasCredits = includeSummarySections && self.model.creditsText != nil
                let hasExtraUsage = includeSummarySections && self.model.providerCost != nil
                let hasTokenCost = includeSummarySections && self.model.tokenUsage != nil
                let hasCost = hasExtraUsage || hasTokenCost
                let hasInsights = includeInsightSections && self.model.insights != nil

                VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
                    if hasUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
                            ForEach(self.model.metrics) { metric in
                                let displayMode = self.model.usageMetricDisplayMode
                                UsageMenuMetricCard(
                                    metric: metric,
                                    displayMode: displayMode,
                                    tint: self.model.progressColor,
                                    isHighlighted: self.isHighlighted)
                            }
                        }
                    }
                    if hasUsage, hasCredits || hasCost || hasInsights {
                        RunicDivider()
                            .padding(.vertical, RunicSpacing.xxs)
                    }
                    if hasCredits, let credits = self.model.creditsText {
                        CreditsBarContent(
                            creditsText: credits,
                            creditsRemaining: self.model.creditsRemaining,
                            hintText: self.model.creditsHintText,
                            hintCopyText: self.model.creditsHintCopyText,
                            progressColor: self.model.progressColor)
                    }
                    if hasCredits, hasCost || hasInsights {
                        RunicDivider()
                            .padding(.vertical, RunicSpacing.xxs)
                    }
                    if hasExtraUsage, let providerCost = self.model.providerCost {
                        ProviderCostContent(
                            section: providerCost,
                            progressColor: self.model.progressColor)
                    }
                    if hasExtraUsage, hasTokenCost || hasInsights {
                        RunicDivider()
                            .padding(.vertical, RunicSpacing.xxs)
                    }
                    if hasTokenCost, let tokenUsage = self.model.tokenUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                            Text("Cost")
                                .font(self.fonts.body)
                                .fontWeight(.medium)
                            Text(tokenUsage.sessionLine)
                                .font(self.fonts.footnote)
                            if let sessionDetail = tokenUsage.sessionDetailLine {
                                Text(sessionDetail)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Text(tokenUsage.monthLine)
                                .font(self.fonts.footnote)
                            if let monthDetail = tokenUsage.monthDetailLine {
                                Text(monthDetail)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Text(tokenUsage.updatedLine)
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                            if let hint = tokenUsage.hintLine, !hint.isEmpty {
                                Text(hint)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let error = tokenUsage.errorLine, !error.isEmpty {
                                HStack(alignment: .top, spacing: RunicSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(self.fonts.footnote)
                                        .foregroundStyle(RunicColors.error)
                                    Text(error)
                                        .font(self.fonts.footnote)
                                        .foregroundStyle(MenuHighlightStyle.error(
                                            self.isHighlighted,
                                            theme: self.runicTheme))
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(RunicSpacing.xs)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                                        style: .continuous)
                                        .fill(RunicColors.error.opacity(RunicColors.Opacity.subtle)))
                                .overlay {
                                    ClickToCopyOverlay(copyText: tokenUsage.errorCopyText ?? error)
                                }
                            }
                        }
                    }
                    if hasCost, hasInsights {
                        RunicDivider()
                            .padding(.vertical, RunicSpacing.xxs)
                    }
                    if hasInsights, let insights = self.model.insights {
                        InsightsContent(section: insights)
                    }
                }
                .padding(.bottom, self.model.creditsText == nil ? MenuCardMetrics.tailPadding : 0)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.top, MenuCardMetrics.headerTopPadding)
        .padding(.bottom, MenuCardMetrics.headerBottomPadding)
        .frame(width: self.width, alignment: .leading)
    }

    private var hasDetails: Bool {
        let includeSummarySections = self.model.menuMode != .glance
        let includeInsightSections = self.model.menuMode == .operator
        return !self.model.metrics.isEmpty || self.model.placeholder != nil || (includeSummarySections && (
            self.model.tokenUsage != nil || self.model.providerCost != nil)) || (includeInsightSections &&
            self.model.insights != nil)
    }
}

struct UsageMenuCardHeaderSectionView: View {
    @Environment(\.runicFonts) private var fonts
    let model: UsageMenuCardView.Model
    let showDivider: Bool
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            UsageMenuCardHeaderView(model: self.model)

            if self.showDivider {
                RunicDivider()
                    .padding(.vertical, RunicSpacing.xxs)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.top, MenuCardMetrics.headerTopPadding)
        .padding(.bottom, self.model.subtitleStyle == .error ? MenuCardMetrics.headerBottomPadding : 0)
        .frame(width: self.width, alignment: .leading)
    }
}

struct UsageMenuCardUsageSectionView: View {
    @Environment(\.runicFonts) private var fonts
    let model: UsageMenuCardView.Model
    let showBottomDivider: Bool
    let bottomPadding: CGFloat
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
            if self.model.metrics.isEmpty {
                if let placeholder = self.model.placeholder {
                    MenuEmptyStateView(
                        providerName: self.model.providerName,
                        placeholder: placeholder,
                        isHighlighted: self.isHighlighted)
                }
            } else {
                ForEach(self.model.metrics) { metric in
                    let displayMode = self.model.usageMetricDisplayMode
                    UsageMenuMetricCard(
                        metric: metric,
                        displayMode: displayMode,
                        tint: self.model.progressColor,
                        isHighlighted: self.isHighlighted)
                }
            }
            if self.showBottomDivider {
                RunicDivider()
                    .padding(.vertical, RunicSpacing.xxs)
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.top, MenuCardMetrics.sectionTopPadding)
        .padding(.bottom, self.bottomPadding)
        .frame(width: self.width, alignment: .leading)
    }
}

struct UsageMenuCardCreditsSectionView: View {
    @Environment(\.runicFonts) private var fonts
    let model: UsageMenuCardView.Model
    let showBottomDivider: Bool
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let width: CGFloat

    var body: some View {
        if let credits = self.model.creditsText {
            VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                CreditsBarContent(
                    creditsText: credits,
                    creditsRemaining: self.model.creditsRemaining,
                    hintText: self.model.creditsHintText,
                    hintCopyText: self.model.creditsHintCopyText,
                    progressColor: self.model.progressColor)
                if self.showBottomDivider {
                    RunicDivider()
                        .padding(.vertical, RunicSpacing.xxs)
                }
            }
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.top, self.topPadding)
            .padding(.bottom, self.bottomPadding)
            .frame(width: self.width, alignment: .leading)
        }
    }
}

struct UsageMenuCardInsightsSectionView: View {
    @Environment(\.runicFonts) private var fonts
    let model: UsageMenuCardView.Model
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let width: CGFloat

    var body: some View {
        if let insights = self.model.insights {
            InsightsContent(section: insights)
                .padding(.horizontal, MenuCardMetrics.horizontalPadding)
                .padding(.top, self.topPadding)
                .padding(.bottom, self.bottomPadding)
                .frame(width: self.width, alignment: .leading)
        }
    }
}

struct UsageMenuCardCostSectionView: View {
    @Environment(\.runicFonts) private var fonts
    let model: UsageMenuCardView.Model
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let hasTokenCost = self.model.tokenUsage != nil
        return Group {
            if hasTokenCost {
                VStack(alignment: .leading, spacing: MenuCardMetrics.blockSpacing) {
                    if let tokenUsage = self.model.tokenUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                            Text("Cost")
                                .font(self.fonts.body)
                                .fontWeight(.medium)
                            Text(tokenUsage.sessionLine)
                                .font(self.fonts.caption)
                            if let sessionDetail = tokenUsage.sessionDetailLine {
                                Text(sessionDetail)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Text(tokenUsage.monthLine)
                                .font(self.fonts.caption)
                            if let monthDetail = tokenUsage.monthDetailLine {
                                Text(monthDetail)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                            }
                            Text(tokenUsage.updatedLine)
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                            if let hint = tokenUsage.hintLine, !hint.isEmpty {
                                Text(hint)
                                    .font(self.fonts.footnote)
                                    .foregroundStyle(self.runicTheme.secondaryText)
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let error = tokenUsage.errorLine, !error.isEmpty {
                                HStack(alignment: .top, spacing: RunicSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(self.fonts.footnote)
                                        .foregroundStyle(RunicColors.error)
                                    Text(error)
                                        .font(self.fonts.footnote)
                                        .foregroundStyle(MenuHighlightStyle.error(
                                            self.isHighlighted,
                                            theme: self.runicTheme))
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(RunicSpacing.xs)
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                                        style: .continuous)
                                        .fill(RunicColors.error.opacity(RunicColors.Opacity.subtle)))
                                .overlay {
                                    ClickToCopyOverlay(copyText: tokenUsage.errorCopyText ?? error)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, MenuCardMetrics.horizontalPadding)
                .padding(.top, self.topPadding)
                .padding(.bottom, self.bottomPadding)
                .frame(width: self.width, alignment: .leading)
            }
        }
    }
}

struct UsageMenuCardExtraUsageSectionView: View {
    let model: UsageMenuCardView.Model
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let width: CGFloat

    var body: some View {
        Group {
            if let providerCost = self.model.providerCost {
                ProviderCostContent(
                    section: providerCost,
                    progressColor: self.model.progressColor)
                    .padding(.horizontal, MenuCardMetrics.horizontalPadding)
                    .padding(.top, self.topPadding)
                    .padding(.bottom, self.bottomPadding)
                    .frame(width: self.width, alignment: .leading)
            }
        }
    }
}

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

    private static func email(
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

    private static func insightsSection(input: Input) -> InsightsSection? {
        let error = input.ledgerError?.trimmingCharacters(in: .whitespacesAndNewlines)
        let daily = input.ledgerDaily?.provider == input.provider ? input.ledgerDaily : nil
        let block = input.ledgerActiveBlock?.provider == input.provider ? input.ledgerActiveBlock : nil
        let topModel = input.ledgerTopModel?.provider == input.provider ? input.ledgerTopModel : nil
        let topProject = input.ledgerTopProject?.provider == input.provider ? input.ledgerTopProject : nil
        let spendForecast = input.ledgerSpendForecast?.provider == input.provider ? input.ledgerSpendForecast : nil
        let topProjectSpendForecast = input.ledgerTopProjectSpendForecast?.provider == input.provider
            ? input.ledgerTopProjectSpendForecast
            : nil
        let anomaly = input.ledgerAnomaly?.provider == input.provider ? input.ledgerAnomaly : nil
        let compaction = input.ledgerCompaction?.provider == input.provider ? input.ledgerCompaction : nil
        let connection = Self.connectionLines(input: input)
        let context = Self.contextHealthLines(input: input, daily: daily, block: block, topModel: topModel)
        let compactionLines = Self.compactionLines(compaction)
        let hasData = connection.line != nil || context.line != nil || compactionLines.line != nil || daily != nil ||
            block != nil || topModel != nil || topProject != nil || spendForecast != nil || anomaly != nil
        if !hasData, error?.isEmpty ?? true {
            return nil
        }

        let today = Self.todayInsightLines(daily)
        let forecastLine = Self.forecastInsightLine(spendForecast)
        let activeBlock = Self.activeBlockInsightLines(block, now: input.now)
        let modelLine = Self.modelInsightLine(topModel, contextLabel: input.ledgerTopModelContextLabel)
        let project = Self.projectInsightLines(topProject, forecast: topProjectSpendForecast, now: input.now)
        let anomalyLines = Self.anomalyInsightLines(anomaly)
        let reliability = Self.reliabilityInsightLines(input.ledgerReliability)
        let routing = Self.routingInsightLines(input.ledgerRouting)
        let updatedLine = input.ledgerUpdatedAt.map { UsageFormatter.updatedString(from: $0, now: input.now) }

        return InsightsSection(
            title: "Insights",
            connectionLine: connection.line,
            connectionDetail: connection.detail,
            contextLine: context.line,
            contextDetail: context.detail,
            compactionLine: compactionLines.line,
            compactionDetail: compactionLines.detail,
            todayLine: today.line,
            todayDetail: today.detail,
            forecastLine: forecastLine,
            blockLine: activeBlock.line,
            blockDetail: activeBlock.detail,
            modelLine: modelLine,
            projectLine: project.line,
            projectDetail: project.detail,
            anomalyLine: anomalyLines.line,
            anomalyDetail: anomalyLines.detail,
            reliabilityLine: reliability.line,
            reliabilityDetail: reliability.detail,
            routingLine: routing.line,
            routingDetail: routing.detail,
            updatedLine: updatedLine,
            errorLine: (error?.isEmpty ?? true) ? nil : error)
    }

    private static func todayInsightLines(_ daily: UsageLedgerDailySummary?) -> (line: String?, detail: String?) {
        guard let daily else { return (nil, nil) }
        let tokens = UsageFormatter.tokenCountString(daily.totals.totalTokens)
        let line = "Today: \(tokens) tokens"
        var details: [String] = []
        let input = UsageFormatter.tokenCountString(daily.totals.inputTokens)
        let output = UsageFormatter.tokenCountString(daily.totals.outputTokens)
        var flowParts = ["In \(input)", "Out \(output)"]
        if daily.totals.cacheReadTokens > 0 {
            let cacheRead = UsageFormatter.tokenCountString(daily.totals.cacheReadTokens)
            flowParts.append("Cache read \(cacheRead)")
        }
        if daily.totals.cacheCreationTokens > 0 {
            let cacheWrite = UsageFormatter.tokenCountString(daily.totals.cacheCreationTokens)
            flowParts.append("Cache write \(cacheWrite)")
        }
        details.append(flowParts.joined(separator: " · "))
        if let cost = daily.totals.costUSD {
            details.append(Self.spendDetailLine(cost: cost, tokens: daily.totals.totalTokens))
        }
        return (line, details.isEmpty ? nil : details.joined(separator: "\n"))
    }

    private static func forecastInsightLine(_ forecast: UsageLedgerSpendForecast?) -> String? {
        guard let forecast else { return nil }
        let projected = UsageFormatter.usdString(forecast.projected30DayCostUSD)
        let observedDayLabel = forecast.observedDays == 1 ? "day" : "days"
        var parts = ["Month-end forecast: \(projected)"]
        if let p50 = forecast.projectedCostP50USD,
           let p80 = forecast.projectedCostP80USD,
           let p95 = forecast.projectedCostP95USD
        {
            let p50Text = UsageFormatter.usdString(p50)
            let p80Text = UsageFormatter.usdString(p80)
            let p95Text = UsageFormatter.usdString(p95)
            parts.append("p50 \(p50Text) · p80 \(p80Text) · p95 \(p95Text)")
        }
        parts.append("\(forecast.observedDays) observed \(observedDayLabel)")
        return parts.joined(separator: " · ")
    }

    private static func activeBlockInsightLines(
        _ block: UsageLedgerBlockSummary?,
        now: Date) -> (line: String?, detail: String?)
    {
        guard let block, block.isActive else { return (nil, nil) }
        let tokens = UsageFormatter.tokenCountString(block.totals.totalTokens)
        let line = "Active block: \(tokens) tokens · \(block.entryCount) req"
        var details: [String] = []
        details.append("Ends \(UsageFormatter.resetCountdownDescription(from: block.end, now: now))")
        if let rate = block.tokensPerMinute {
            let rateText = UsageFormatter.tokenCountString(Int(rate.rounded()))
            details.append("\(rateText) tok/min")
        }
        if let projected = block.projectedTotalTokens {
            details.append("Proj \(UsageFormatter.tokenCountString(projected))")
        }
        let inputTokens = UsageFormatter.tokenCountString(block.totals.inputTokens)
        let outputTokens = UsageFormatter.tokenCountString(block.totals.outputTokens)
        details.append("In \(inputTokens) · Out \(outputTokens)")
        if let cost = block.totals.costUSD {
            var spendParts = Self.spendDetailParts(cost: cost, tokens: block.totals.totalTokens)
            if let perRequest = UsageFormatter.usdPerRequestString(costUSD: cost, requestCount: block.entryCount) {
                spendParts.append(perRequest)
            }
            if let burnPerHour = UsageFormatter.usdPerHourFromTokensString(
                costUSD: cost,
                tokenCount: block.totals.totalTokens,
                tokensPerMinute: block.tokensPerMinute)
            {
                spendParts.append("Burn \(burnPerHour)")
            }
            details.append(spendParts.joined(separator: " · "))
        }
        return (line, details.joined(separator: "\n"))
    }

    private static func modelInsightLine(
        _ summary: UsageLedgerModelSummary?,
        contextLabel: String?) -> String?
    {
        guard let summary else { return nil }
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let modelName = UsageFormatter.modelDisplayName(summary.model)
        var parts = ["Top model: \(modelName) · \(tokens) tokens · \(summary.entryCount) req"]
        if let contextLabel {
            parts.append(contextLabel)
        }
        if let cost = summary.totals.costUSD {
            parts.append(contentsOf: Self.costInsightParts(cost: cost, tokens: summary.totals.totalTokens))
        }
        return parts.joined(separator: " · ")
    }

    private static func projectInsightLines(
        _ summary: UsageLedgerProjectSummary?,
        forecast: UsageLedgerSpendForecast?,
        now: Date) -> (line: String?, detail: String?)
    {
        guard let summary else { return (nil, nil) }
        let name = Self.insightsProjectDisplayName(summary)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        var parts = ["Top project: \(name) · \(tokens) tokens · \(summary.entryCount) req"]
        if let cost = summary.totals.costUSD {
            parts.append(contentsOf: Self.costInsightParts(cost: cost, tokens: summary.totals.totalTokens))
        }
        let detail = forecast.flatMap { Self.projectForecastDetail($0, now: now) }
        return (parts.joined(separator: " · "), detail)
    }

    private static func projectForecastDetail(_ forecast: UsageLedgerSpendForecast, now: Date) -> String {
        var parts = ["30d forecast \(UsageFormatter.usdString(forecast.projected30DayCostUSD))"]
        if let budgetLimit = forecast.budgetLimitUSD {
            parts.append("Budget \(UsageFormatter.usdString(budgetLimit))")
            if let budgetETAInDays = forecast.budgetETAInDays {
                parts.append(Self.budgetBreachETAText(days: budgetETAInDays, now: now))
            } else if !forecast.budgetWillBreach {
                parts.append("No breach at current pace")
            }
        }
        return parts.joined(separator: " · ")
    }

    private static func anomalyInsightLines(
        _ anomaly: UsageLedgerAnomalySummary?) -> (line: String?, detail: String?)
    {
        guard let anomaly, let primary = anomaly.primaryAnomaly else { return (nil, nil) }
        let line = "Anomaly: \(primary.severity.label) \(primary.metric.label) spike"
        var details = [Self.anomalyMetricDetail(primary, baselineDays: anomaly.baselineDays)]
        if let secondary = anomaly.secondaryAnomaly(excluding: primary.metric) {
            details.append(Self.anomalyMetricDetail(secondary, baselineDays: anomaly.baselineDays))
        }
        return (line, details.joined(separator: "\n"))
    }

    private static func reliabilityInsightLines(
        _ reliability: UsageLedgerReliabilityScore?) -> (line: String?, detail: String?)
    {
        guard let reliability else { return (nil, nil) }
        let line = "Reliability: \(reliability.score)/100 · \(reliability.grade)"
        return (line, reliability.primarySignal ?? reliability.summary)
    }

    private static func routingInsightLines(
        _ routing: UsageLedgerRoutingRecommendation?) -> (line: String?, detail: String?)
    {
        guard let routing else { return (nil, nil) }
        let from = UsageFormatter.modelDisplayName(routing.fromModel)
        let to = UsageFormatter.modelDisplayName(routing.toModel)
        let line = "Routing advisor: shift \(routing.shiftPercent)% \(from) -> \(to)"
        let confidenceText = "\(Int((routing.confidence * 100).rounded()))%"
        let savings = UsageFormatter.usdString(routing.estimatedSavingsUSD)
        return (line, "Estimated savings: \(savings) · confidence \(confidenceText)")
    }

    private static func spendDetailLine(cost: Double, tokens: Int) -> String {
        Self.spendDetailParts(cost: cost, tokens: tokens).joined(separator: " · ")
    }

    private static func spendDetailParts(cost: Double, tokens: Int) -> [String] {
        var parts = ["Spend \(UsageFormatter.usdString(cost))"]
        if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: tokens) {
            parts.append(per1K)
        }
        return parts
    }

    private static func costInsightParts(cost: Double, tokens: Int) -> [String] {
        var parts = [UsageFormatter.usdString(cost)]
        if let per1K = UsageFormatter.usdPer1KTokensString(costUSD: cost, tokenCount: tokens) {
            parts.append(per1K)
        }
        return parts
    }

    private static func anomalyMetricDetail(
        _ anomaly: UsageLedgerAnomalySummary.MetricAnomaly,
        baselineDays: Int) -> String
    {
        let percentText = "\(Int((anomaly.percentIncrease * 100).rounded()))%"
        let baselineLabel = "\(baselineDays)d avg"
        switch anomaly.metric {
        case .tokens:
            let todayTokens = UsageFormatter.tokenCountString(Int(anomaly.todayValue.rounded()))
            let baselineTokens = UsageFormatter.tokenCountString(Int(anomaly.baselineAverage.rounded()))
            return "Tokens \(todayTokens) today · +\(percentText) vs \(baselineLabel) \(baselineTokens)"
        case .spend:
            let todaySpend = UsageFormatter.usdString(anomaly.todayValue)
            let baselineSpend = UsageFormatter.usdString(anomaly.baselineAverage)
            return "Spend \(todaySpend) today · +\(percentText) vs \(baselineLabel) \(baselineSpend)"
        }
    }

    private static func connectionLines(input: Input) -> (line: String?, detail: String?) {
        let status: String = if input.isRefreshing {
            "refreshing"
        } else if let lastError = input.lastError?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !lastError.isEmpty
        {
            "issue"
        } else if input.snapshot != nil {
            "connected"
        } else {
            "waiting for first fetch"
        }

        var detailParts: [String] = []
        let email = Self.email(
            for: input.provider,
            snapshot: input.snapshot,
            account: input.account,
            metadata: input.metadata)
        if !email.isEmpty {
            detailParts.append("Account \(email)")
        }
        if let updatedAt = input.snapshot?.updatedAt {
            detailParts.append("Last fetch \(UsageFormatter.updatedString(from: updatedAt, now: input.now))")
        } else if let ledgerUpdatedAt = input.ledgerUpdatedAt {
            detailParts.append("Ledger \(UsageFormatter.updatedString(from: ledgerUpdatedAt, now: input.now))")
        }
        if let coverage = input.metadata.usageCoverage.summaryLabel {
            detailParts.append(coverage)
        }
        let detail = detailParts.isEmpty ? nil : detailParts.joined(separator: " · ")
        return ("Connection: \(status)", detail)
    }

    private static func contextHealthLines(
        input: Input,
        daily: UsageLedgerDailySummary?,
        block: UsageLedgerBlockSummary?,
        topModel: UsageLedgerModelSummary?) -> (line: String?, detail: String?)
    {
        guard input.providerContextStatus != nil || topModel != nil || daily != nil || block != nil else {
            return (nil, nil)
        }

        let status = input.providerContextStatus
        let maxContext = status?.text ?? "unknown"
        let observedTokens = block?.totals.totalTokens ?? daily?.totals.totalTokens ?? topModel?.totals.totalTokens ?? 0
        let observed = observedTokens > 0 ? UsageFormatter.tokenCountString(observedTokens) : "no observed tokens"
        var parts: [String] = []
        if let block, block.isActive,
           let maxTokens = status?.maxTokens,
           maxTokens > 0
        {
            parts.append(Self.contextPressureText(observed: block.totals.totalTokens, maxTokens: maxTokens))
        }
        parts.append("max \(maxContext)")
        parts.append("observed \(observed)")
        let line = "Context health: \(parts.joined(separator: " · "))"

        var details: [String] = []
        if let status {
            let staleText = status.isStale ? " (stale)" : ""
            details.append("Capability source: \(Self.contextSourceText(status.source))\(staleText)")
        } else {
            details.append("Capability source: unavailable")
        }
        if let model = topModel?.model {
            details.append("Model \(UsageFormatter.modelDisplayName(model))")
        }
        if block?.isActive == true {
            details.append("Pressure uses active block token volume, not semantic retention.")
        } else {
            details.append("Observed tokens are usage volume, not active retained context.")
        }
        details.append("Effective retained context after compaction is not inferred.")
        return (line, details.joined(separator: " · "))
    }

    private static func contextPressureText(observed: Int, maxTokens: Int) -> String {
        guard observed > 0, maxTokens > 0 else { return "unknown pressure" }
        let ratio = Double(observed) / Double(maxTokens)
        let percent = Int((ratio * 100).rounded())
        switch ratio {
        case ..<0.35:
            return "low pressure \(percent)%"
        case ..<0.70:
            return "medium pressure \(percent)%"
        case ..<1.0:
            return "high pressure \(percent)%"
        default:
            return "over-window volume \(percent)%"
        }
    }

    private static func compactionLines(
        _ summary: UsageLedgerCompactionSummary?) -> (line: String?, detail: String?)
    {
        guard let summary else {
            return (nil, nil)
        }

        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        let eventLabel = summary.eventCount == 1 ? "event" : "events"
        let line = "Compaction tax: \(tokens) tokens · \(summary.eventCount) \(eventLabel)"

        var details: [String] = []
        if let cost = summary.totals.costUSD {
            details.append("Spend \(UsageFormatter.usdString(cost))")
        }
        if let provenance = summary.totals.tokenProvenance {
            details.append(provenance.displayText)
        } else {
            details.append("Source: observed compaction entries")
        }
        details.append("Last \(UsageFormatter.updatedString(from: summary.lastEventAt))")
        return (line, details.joined(separator: " · "))
    }

    private static func contextSourceText(_ source: ProviderContextWindowLabel.Source) -> String {
        switch source {
        case .kosha: "Kosha TTL registry"
        case .modelHeuristic: "model heuristic"
        case .staticFallback: "built-in fallback"
        }
    }

    private static func insightsProjectDisplayName(_ summary: UsageLedgerProjectSummary) -> String {
        let displayName = RunicProjectDisplay.name(for: summary)
        guard let annotation = self.projectIdentityAnnotation(
            displayName: displayName,
            projectID: summary.projectID,
            confidence: summary.projectNameConfidence,
            source: summary.projectNameSource)
        else {
            return displayName
        }
        return "\(displayName) [\(annotation)]"
    }

    private static func projectIdentityAnnotation(
        displayName: String,
        projectID: String?,
        confidence: UsageLedgerProjectNameConfidence?,
        source: UsageLedgerProjectNameSource?) -> String?
    {
        let normalizedSource = source ?? .unknown
        let normalizedConfidence = confidence ?? .none

        let shouldAnnotateSource = normalizedSource != .projectName && normalizedSource != .budgetOverride
        let shouldAnnotateConfidence = normalizedConfidence != .high
        let isUnknown = RunicProjectDisplay.isUnattributed(displayName)
        guard shouldAnnotateSource || shouldAnnotateConfidence || isUnknown else { return nil }

        var parts: [String] = []
        if shouldAnnotateSource {
            parts.append("source \(self.projectSourceLabel(normalizedSource))")
        }
        if shouldAnnotateConfidence {
            parts.append("confidence \(self.projectConfidenceLabel(normalizedConfidence))")
        }
        if isUnknown, let fingerprint = self.projectIDFingerprint(projectID) {
            parts.append("id \(fingerprint)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func projectSourceLabel(_ source: UsageLedgerProjectNameSource) -> String {
        switch source {
        case .projectName: "project name"
        case .projectID: "project id"
        case .inferredFromPath: "path-derived"
        case .inferredFromName: "name-derived"
        case .budgetOverride: "budget override"
        case .unknown: "unknown"
        }
    }

    private static func projectConfidenceLabel(_ confidence: UsageLedgerProjectNameConfidence) -> String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        case .none: "none"
        }
    }

    private static func projectIDFingerprint(_ projectID: String?) -> String? {
        guard let projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines), !projectID.isEmpty else {
            return nil
        }

        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01B3
        }
        return String(format: "%08llx", hash)
    }

    private static func budgetBreachETAText(days: Double, now: Date) -> String {
        guard days.isFinite else { return "Breach ETA unavailable" }
        if days <= 0 { return "Breach now" }
        let etaDate = now.addingTimeInterval(days * 24 * 60 * 60)
        let countdown = UsageFormatter.resetCountdownDescription(from: etaDate, now: now)
        if countdown == "now" { return "Breach now" }
        return "Breach \(countdown)"
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
