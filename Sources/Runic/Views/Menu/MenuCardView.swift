import RunicCore
import SwiftUI

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
