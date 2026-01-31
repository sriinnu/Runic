import AppKit
import RunicCore
import SwiftUI

/// **Menu Card Layout Metrics**
/// Defines all spacing and padding constants for the menu card UI.
/// These values are carefully tuned for readability and visual hierarchy.
enum MenuCardMetrics {
    /// Horizontal padding on left/right edges of card content
    static let horizontalPadding: CGFloat = 12
    
    /// Top padding for the header section (provider name, email)
    static let headerTopPadding: CGFloat = 1
    
    /// Bottom padding for the header section
    static let headerBottomPadding: CGFloat = 1
    
    /// Top padding for content sections (usage, credits, cost)
    static let sectionTopPadding: CGFloat = 5
    
    /// Bottom padding for content sections
    static let sectionBottomPadding: CGFloat = 3
    
    /// Vertical spacing between major sections (e.g., Session vs Weekly)
    static let sectionSpacing: CGFloat = 8  // Increased from 7 for better breathing room
    
    /// Spacing between related blocks of content
    static let blockSpacing: CGFloat = 5
    
    /// Spacing between individual text lines within a section
    static let lineSpacing: CGFloat = 4  // Increased from 3 for improved readability
    
    /// Base padding for menu items
    static let menuItemBasePadding: CGFloat = 4
    
    /// Additional padding for text with descenders (y, g, p, q, j)
    static let menuItemDescenderPadding: CGFloat = 1
    
    /// Tail padding at the end of sections
    static let tailPadding: CGFloat = 2
}

/// SwiftUI card used inside the NSMenu to mirror Apple's rich menu panels.
struct UsageMenuCardView: View {
    struct Model {
        enum PercentStyle: String, Sendable {
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

        struct TokenUsageSection: Sendable {
            let sessionLine: String
            let monthLine: String
            let hintLine: String?
            let errorLine: String?
            let errorCopyText: String?
        }

        struct ProviderCostSection: Sendable {
            let title: String
            let percentUsed: Double
            let spendLine: String
        }

        struct InsightsSection: Sendable {
            let title: String
            let todayLine: String?
            let todayDetail: String?
            let blockLine: String?
            let blockDetail: String?
            let modelLine: String?
            let projectLine: String?
            let updatedLine: String?
            let errorLine: String?
        }

        let providerName: String
        let email: String
        let subtitleText: String
        let subtitleStyle: SubtitleStyle
        let planText: String?
        let topModelLine: String?
        let metrics: [Metric]
        let usageMetricDisplayMode: UsageMetricDisplayMode
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

    init(model: Model, width: CGFloat) {
        self.model = model
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            UsageMenuCardHeaderView(model: self.model)

            if self.hasDetails {
                Divider()
            }

            if self.model.metrics.isEmpty {
                if let placeholder = self.model.placeholder {
                    Text(placeholder)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                        .font(.subheadline)
                }
            } else {
                let hasUsage = !self.model.metrics.isEmpty
                let hasCredits = self.model.creditsText != nil
                let hasExtraUsage = self.model.providerCost != nil
                let hasTokenCost = self.model.tokenUsage != nil
                let hasCost = hasExtraUsage || hasTokenCost
                let hasInsights = self.model.insights != nil

                VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
                    if hasUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
                            ForEach(self.model.metrics) { metric in
                                let displayMode = self.model.usageMetricDisplayMode
                                VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                                    Text(metric.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    if displayMode.showsBars {
                                        UsageProgressBar(
                                            percent: metric.percent,
                                            tint: self.model.progressColor,
                                            accessibilityLabel: metric.percentStyle.accessibilityLabel)
                                    }
                                    if displayMode.showsPercent || metric.resetText != nil {
                                        HStack(alignment: .firstTextBaseline) {
                                            if displayMode.showsPercent {
                                                Text(metric.percentLabel)
                                                    .font(.footnote)
                                            }
                                            if let reset = metric.resetText {
                                                if displayMode.showsPercent {
                                                    Spacer()
                                                }
                                                Text(reset)
                                                    .font(.footnote)
                                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                            }
                                        }
                                    }
                                    if let detail = metric.detailText {
                                        Text(detail)
                                            .font(.footnote)
                                            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    if hasUsage, hasCredits || hasCost || hasInsights {
                        Divider()
                    }
                    if let credits = self.model.creditsText {
                        CreditsBarContent(
                            creditsText: credits,
                            creditsRemaining: self.model.creditsRemaining,
                            hintText: self.model.creditsHintText,
                            hintCopyText: self.model.creditsHintCopyText,
                            progressColor: self.model.progressColor)
                    }
                    if hasCredits, hasCost || hasInsights {
                        Divider()
                    }
                    if let providerCost = self.model.providerCost {
                        ProviderCostContent(
                            section: providerCost,
                            progressColor: self.model.progressColor)
                    }
                    if hasExtraUsage, hasTokenCost || hasInsights {
                        Divider()
                    }
                    if let tokenUsage = self.model.tokenUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                            Text("Cost")
                                .font(.body)
                                .fontWeight(.medium)
                            Text(tokenUsage.sessionLine)
                                .font(.footnote)
                            Text(tokenUsage.monthLine)
                                .font(.footnote)
                            if let hint = tokenUsage.hintLine, !hint.isEmpty {
                                Text(hint)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let error = tokenUsage.errorLine, !error.isEmpty {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .overlay {
                                        ClickToCopyOverlay(copyText: tokenUsage.errorCopyText ?? error)
                                    }
                            }
                        }
                    }
                    if hasCost, hasInsights {
                        Divider()
                    }
                    if let insights = self.model.insights {
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
        !self.model.metrics.isEmpty || self.model.placeholder != nil || self.model.tokenUsage != nil ||
            self.model.providerCost != nil || self.model.insights != nil
    }
}

private struct UsageMenuCardHeaderView: View {
    let model: UsageMenuCardView.Model
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.model.providerName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(self.model.email)
                    .font(.subheadline)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            let subtitleAlignment: VerticalAlignment = self.model.subtitleStyle == .error ? .top : .firstTextBaseline
            HStack(alignment: subtitleAlignment) {
                Text(self.model.subtitleText)
                    .font(.footnote)
                    .foregroundStyle(self.subtitleColor)
                    .lineLimit(self.model.subtitleStyle == .error ? 4 : 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .padding(.bottom, self.model.subtitleStyle == .error ? 4 : 0)
                Spacer()
                if self.model.subtitleStyle == .error, !self.model.subtitleText.isEmpty {
                    CopyIconButton(copyText: self.model.subtitleText, isHighlighted: self.isHighlighted)
                }
                if let plan = self.model.planText {
                    Text(plan)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                        .lineLimit(1)
                }
            }
            if let topModelLine = self.model.topModelLine {
                Text(topModelLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    .lineLimit(1)
            }
        }
    }

    private var subtitleColor: Color {
        switch self.model.subtitleStyle {
        case .info: MenuHighlightStyle.secondary(self.isHighlighted)
        case .loading: MenuHighlightStyle.secondary(self.isHighlighted)
        case .error: MenuHighlightStyle.error(self.isHighlighted)
        }
    }
}

private struct CopyIconButtonStyle: ButtonStyle {
    let isHighlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(MenuHighlightStyle.secondary(self.isHighlighted).opacity(configuration.isPressed ? 0.18 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct CopyIconButton: View {
    let copyText: String
    let isHighlighted: Bool

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button {
            self.copyToPasteboard()
            withAnimation(.easeOut(duration: 0.12)) {
                self.didCopy = true
            }
            self.resetTask?.cancel()
            self.resetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeOut(duration: 0.2)) {
                    self.didCopy = false
                }
            }
        } label: {
            Image(systemName: self.didCopy ? "checkmark" : "doc.on.doc")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(CopyIconButtonStyle(isHighlighted: self.isHighlighted))
        .accessibilityLabel(self.didCopy ? "Copied" : "Copy error")
    }

    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(self.copyText, forType: .string)
    }
}

private struct ProviderCostContent: View {
    let section: UsageMenuCardView.Model.ProviderCostSection
    let progressColor: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            Text(self.section.title)
                .font(.body)
                .fontWeight(.medium)
            UsageProgressBar(
                percent: self.section.percentUsed,
                tint: self.progressColor,
                accessibilityLabel: "Extra usage spent")
            HStack(alignment: .firstTextBaseline) {
                Text(self.section.spendLine)
                    .font(.footnote)
                Spacer()
                Text(String(format: "%.0f%% used", min(100, max(0, self.section.percentUsed))))
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
        }
    }
}

private struct InsightsContent: View {
    let section: UsageMenuCardView.Model.InsightsSection
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            Text(self.section.title)
                .font(.body)
                .fontWeight(.medium)
            if let today = self.section.todayLine {
                Text(today)
                    .font(.footnote)
            }
            if let detail = self.section.todayDetail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let block = self.section.blockLine {
                Text(block)
                    .font(.footnote)
            }
            if let blockDetail = self.section.blockDetail {
                Text(blockDetail)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let modelLine = self.section.modelLine {
                Text(modelLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let projectLine = self.section.projectLine {
                Text(projectLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let updated = self.section.updatedLine {
                Text(updated)
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let error = self.section.errorLine {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct UsageMenuCardHeaderSectionView: View {
    let model: UsageMenuCardView.Model
    let showDivider: Bool
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            UsageMenuCardHeaderView(model: self.model)

            if self.showDivider {
                Divider()
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.top, MenuCardMetrics.headerTopPadding)
        .padding(.bottom, self.model.subtitleStyle == .error ? MenuCardMetrics.headerBottomPadding : 0)
        .frame(width: self.width, alignment: .leading)
    }
}

struct UsageMenuCardUsageSectionView: View {
    let model: UsageMenuCardView.Model
    let showBottomDivider: Bool
    let bottomPadding: CGFloat
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.sectionSpacing) {
            if self.model.metrics.isEmpty {
                if let placeholder = self.model.placeholder {
                    Text(placeholder)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                        .font(.subheadline)
                }
            } else {
                ForEach(self.model.metrics) { metric in
                    let displayMode = self.model.usageMetricDisplayMode
                    VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                        Text(metric.title)
                            .font(.body)
                            .fontWeight(.medium)
                        if displayMode.showsBars {
                            UsageProgressBar(
                                percent: metric.percent,
                                tint: self.model.progressColor,
                                accessibilityLabel: metric.percentStyle.accessibilityLabel)
                        }
                        if displayMode.showsPercent || metric.resetText != nil {
                            HStack(alignment: .firstTextBaseline) {
                                if displayMode.showsPercent {
                                    Text(metric.percentLabel)
                                        .font(.footnote)
                                }
                                if let reset = metric.resetText {
                                    if displayMode.showsPercent {
                                        Spacer()
                                    }
                                    Text(reset)
                                        .font(.footnote)
                                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                }
                            }
                        }
                        if let detail = metric.detailText {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                .lineLimit(1)
                        }
                    }
                }
            }
            if self.showBottomDivider {
                Divider()
            }
        }
        .padding(.horizontal, MenuCardMetrics.horizontalPadding)
        .padding(.top, MenuCardMetrics.sectionTopPadding)
        .padding(.bottom, self.bottomPadding)
        .frame(width: self.width, alignment: .leading)
    }
}

struct UsageMenuCardCreditsSectionView: View {
    let model: UsageMenuCardView.Model
    let showBottomDivider: Bool
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let width: CGFloat

    init(
        model: UsageMenuCardView.Model,
        showBottomDivider: Bool,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        width: CGFloat)
    {
        self.model = model
        self.showBottomDivider = showBottomDivider
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.width = width
    }

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
                    Divider()
                }
            }
            .padding(.horizontal, MenuCardMetrics.horizontalPadding)
            .padding(.top, self.topPadding)
            .padding(.bottom, self.bottomPadding)
            .frame(width: self.width, alignment: .leading)
        }
    }
}

private struct CreditsBarContent: View {
    private static let fullScaleTokens: Double = 1000

    let creditsText: String
    let creditsRemaining: Double?
    let hintText: String?
    let hintCopyText: String?
    let progressColor: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted

    private var percentLeft: Double? {
        guard let creditsRemaining else { return nil }
        let percent = (creditsRemaining / Self.fullScaleTokens) * 100
        return min(100, max(0, percent))
    }

    private var scaleText: String {
        let scale = UsageFormatter.tokenCountString(Int(Self.fullScaleTokens))
        return "\(scale) tokens"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            Text("Credits")
                .font(.body)
                .fontWeight(.medium)
            if let percentLeft {
                UsageProgressBar(
                    percent: percentLeft,
                    tint: self.progressColor,
                    accessibilityLabel: "Credits remaining")
                HStack(alignment: .firstTextBaseline) {
                    Text(self.creditsText)
                        .font(.caption)
                    Spacer()
                    Text(self.scaleText)
                        .font(.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            } else {
                Text(self.creditsText)
                    .font(.caption)
            }
            if let hintText, !hintText.isEmpty {
                Text(hintText)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay {
                        ClickToCopyOverlay(copyText: self.hintCopyText ?? hintText)
                    }
            }
        }
    }
}

struct UsageMenuCardInsightsSectionView: View {
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
    let model: UsageMenuCardView.Model
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let width: CGFloat
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        let hasTokenCost = self.model.tokenUsage != nil
        return Group {
            if hasTokenCost {
                VStack(alignment: .leading, spacing: MenuCardMetrics.blockSpacing) {
                    if let tokenUsage = self.model.tokenUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                            Text("Cost")
                                .font(.body)
                                .fontWeight(.medium)
                            Text(tokenUsage.sessionLine)
                                .font(.caption)
                            Text(tokenUsage.monthLine)
                                .font(.caption)
                            if let hint = tokenUsage.hintLine, !hint.isEmpty {
                                Text(hint)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let error = tokenUsage.errorLine, !error.isEmpty {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
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
        let ledgerTopProject: UsageLedgerProjectSummary?
        let ledgerError: String?
        let ledgerUpdatedAt: Date?
        let account: AccountInfo
        let isRefreshing: Bool
        let lastError: String?
        let usageBarsShowUsed: Bool
        let usageMetricDisplayMode: UsageMetricDisplayMode
        let tokenCostUsageEnabled: Bool
        let showOptionalCreditsAndExtraUsage: Bool
        let now: Date
    }

    static func make(_ input: Input) -> UsageMenuCardView.Model {
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
        let topModelLine = Self.topModelLine(input.ledgerTopModel)
        let insights = Self.removingModelLine(from: Self.insightsSection(input: input), when: topModelLine != nil)
        let subtitle = Self.subtitle(
            snapshot: input.snapshot,
            isRefreshing: input.isRefreshing,
            lastError: input.lastError)
        let placeholder = input.snapshot == nil && !input.isRefreshing && input.lastError == nil ? "No usage yet" : nil

        return UsageMenuCardView.Model(
            providerName: input.metadata.displayName,
            email: email,
            subtitleText: subtitle.text,
            subtitleStyle: subtitle.style,
            planText: planText,
            topModelLine: topModelLine,
            metrics: metrics,
            usageMetricDisplayMode: input.usageMetricDisplayMode,
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

    private static func topModelLine(_ summary: UsageLedgerModelSummary?) -> String? {
        guard let summary else { return nil }
        let modelName = UsageFormatter.modelDisplayName(summary.model)
        let tokens = UsageFormatter.tokenCountString(summary.totals.totalTokens)
        var parts = ["Top model: \(modelName)", "\(tokens) tokens"]
        if let cost = summary.totals.costUSD {
            parts.append(UsageFormatter.usdString(cost))
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
            todayLine: section.todayLine,
            todayDetail: section.todayDetail,
            blockLine: section.blockLine,
            blockDetail: section.blockDetail,
            modelLine: nil,
            projectLine: section.projectLine,
            updatedLine: section.updatedLine,
            errorLine: section.errorLine)
    }

    private static func email(
        for provider: UsageProvider,
        snapshot: UsageSnapshot?,
        account: AccountInfo,
        metadata: ProviderMetadata) -> String
    {
        if let email = snapshot?.accountEmail(for: provider), !email.isEmpty { return email }
        if metadata.usesAccountFallback,
           let email = account.email, !email.isEmpty
        {
            return email
        }
        return ""
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

        let sessionCost = snapshot.sessionCostUSD.map { UsageFormatter.usdString($0) } ?? "—"
        let sessionTokens = snapshot.sessionTokens.map { UsageFormatter.tokenCountString($0) }
        let sessionLine: String = {
            if let sessionTokens {
                return "Today: \(sessionCost) · \(sessionTokens) tokens"
            }
            return "Today: \(sessionCost)"
        }()

        let monthCost = snapshot.last30DaysCostUSD.map { UsageFormatter.usdString($0) } ?? "—"
        let fallbackTokens = snapshot.daily.compactMap(\.totalTokens).reduce(0, +)
        let monthTokensValue = snapshot.last30DaysTokens ?? (fallbackTokens > 0 ? fallbackTokens : nil)
        let monthTokens = monthTokensValue.map { UsageFormatter.tokenCountString($0) }
        let monthLine: String = {
            if let monthTokens {
                return "Last 30 days: \(monthCost) · \(monthTokens) tokens"
            }
            return "Last 30 days: \(monthCost)"
        }()
        let err = (error?.isEmpty ?? true) ? nil : error
        let hintLine = err == nil ? "Token totals are estimates and may lag provider dashboards." : nil
        return TokenUsageSection(
            sessionLine: sessionLine,
            monthLine: monthLine,
            hintLine: hintLine,
            errorLine: err,
            errorCopyText: (error?.isEmpty ?? true) ? nil : error)
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
        let hasData = daily != nil || block != nil || topModel != nil || topProject != nil
        if !hasData && (error?.isEmpty ?? true) {
            return nil
        }

        var todayLine: String?
        var todayDetail: String?
        if let daily {
            let tokens = UsageFormatter.tokenCountString(daily.totals.totalTokens)
            todayLine = "Today: \(tokens) tokens"
            var details: [String] = []
            if let cost = daily.totals.costUSD {
                details.append("Spend \(UsageFormatter.usdString(cost))")
            }
            let cacheTotal = daily.totals.cacheCreationTokens + daily.totals.cacheReadTokens
            if cacheTotal > 0 {
                details.append("Cache \(UsageFormatter.tokenCountString(cacheTotal))")
            }
            if !details.isEmpty {
                todayDetail = details.joined(separator: ", ")
            }
        }

        var blockLine: String?
        var blockDetail: String?
        if let block, block.isActive {
            let tokens = UsageFormatter.tokenCountString(block.totals.totalTokens)
            blockLine = "Active block: \(tokens) tokens"
            var details: [String] = []
            details.append("Ends \(UsageFormatter.resetCountdownDescription(from: block.end, now: input.now))")
            if let rate = block.tokensPerMinute {
                let rateText = UsageFormatter.tokenCountString(Int(rate.rounded()))
                details.append("\(rateText) tok/min")
            }
            if let projected = block.projectedTotalTokens {
                details.append("Proj \(UsageFormatter.tokenCountString(projected))")
            }
            blockDetail = details.joined(separator: ", ")
        }

        var modelLine: String?
        if let topModel {
            let tokens = UsageFormatter.tokenCountString(topModel.totals.totalTokens)
            var parts = ["Top model: \(topModel.model) · \(tokens) tokens"]
            if let cost = topModel.totals.costUSD {
                parts.append(UsageFormatter.usdString(cost))
            }
            modelLine = parts.joined(separator: " · ")
        }

        var projectLine: String?
        if let topProject {
            let name = topProject.projectID ?? "Unknown project"
            let tokens = UsageFormatter.tokenCountString(topProject.totals.totalTokens)
            var parts = ["Top project: \(name) · \(tokens) tokens"]
            if let cost = topProject.totals.costUSD {
                parts.append(UsageFormatter.usdString(cost))
            }
            projectLine = parts.joined(separator: " · ")
        }

        let updatedLine = input.ledgerUpdatedAt.map { UsageFormatter.updatedString(from: $0, now: input.now) }

        return InsightsSection(
            title: "Insights",
            todayLine: todayLine,
            todayDetail: todayDetail,
            blockLine: blockLine,
            blockDetail: blockDetail,
            modelLine: modelLine,
            projectLine: projectLine,
            updatedLine: updatedLine,
            errorLine: (error?.isEmpty ?? true) ? nil : error)
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

// MARK: - Copy-on-click overlay

private struct ClickToCopyOverlay: NSViewRepresentable {
    let copyText: String

    func makeNSView(context: Context) -> ClickToCopyView {
        ClickToCopyView(copyText: self.copyText)
    }

    func updateNSView(_ nsView: ClickToCopyView, context: Context) {
        nsView.copyText = self.copyText
    }
}

private final class ClickToCopyView: NSView {
    var copyText: String

    init(copyText: String) {
        self.copyText = copyText
        super.init(frame: .zero)
        self.wantsLayer = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        _ = event
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(self.copyText, forType: .string)
    }
}
