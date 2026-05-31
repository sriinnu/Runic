import RunicCore
import SwiftUI

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
