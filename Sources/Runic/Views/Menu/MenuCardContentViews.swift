import AppKit
import RunicCore
import SwiftUI

struct ProviderCostContent: View {
    @Environment(\.runicFonts) private var fonts
    let section: UsageMenuCardView.Model.ProviderCostSection
    let progressColor: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            Text(self.section.title)
                .font(self.fonts.body)
                .fontWeight(.medium)
            UsageProgressBar(
                percent: self.section.percentUsed,
                tint: self.progressColor,
                accessibilityLabel: "Extra usage spent")
            HStack(alignment: .firstTextBaseline) {
                Text(self.section.spendLine)
                    .font(self.fonts.footnote)
                Spacer()
                Text(String(format: "%.0f%% used", min(100, max(0, self.section.percentUsed))))
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
        }
    }
}

struct InsightsContent: View {
    @Environment(\.runicFonts) private var fonts
    let section: UsageMenuCardView.Model.InsightsSection
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            Text(self.section.title)
                .font(self.fonts.body)
                .fontWeight(.medium)
            if let connection = self.section.connectionLine {
                Text(connection)
                    .font(self.fonts.footnote)
            }
            if let detail = self.section.connectionDetail {
                Text(detail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let context = self.section.contextLine {
                Text(context)
                    .font(self.fonts.footnote)
            }
            if let detail = self.section.contextDetail {
                Text(detail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let compaction = self.section.compactionLine {
                Text(compaction)
                    .font(self.fonts.footnote)
            }
            if let detail = self.section.compactionDetail {
                Text(detail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let today = self.section.todayLine {
                Text(today)
                    .font(self.fonts.footnote)
            }
            if let detail = self.section.todayDetail {
                Text(detail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let forecastLine = self.section.forecastLine {
                Text(forecastLine)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let block = self.section.blockLine {
                Text(block)
                    .font(self.fonts.footnote)
            }
            if let blockDetail = self.section.blockDetail {
                Text(blockDetail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let modelLine = self.section.modelLine {
                Text(modelLine)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let projectLine = self.section.projectLine {
                Text(projectLine)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let projectDetail = self.section.projectDetail {
                Text(projectDetail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let anomalyLine = self.section.anomalyLine {
                Text(anomalyLine)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let anomalyDetail = self.section.anomalyDetail {
                Text(anomalyDetail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let reliabilityLine = self.section.reliabilityLine {
                Text(reliabilityLine)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let reliabilityDetail = self.section.reliabilityDetail {
                Text(reliabilityDetail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let routingLine = self.section.routingLine {
                Text(routingLine)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let routingDetail = self.section.routingDetail {
                Text(routingDetail)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let updated = self.section.updatedLine {
                Text(updated)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
            }
            if let error = self.section.errorLine {
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
            }
        }
    }
}

struct UsageMenuMetricCard: View {
    @Environment(\.runicFonts) private var fonts
    let metric: UsageMenuCardView.Model.Metric
    let displayMode: UsageMetricDisplayMode
    let tint: Color
    let isHighlighted: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
                Text(self.metric.title)
                    .font(self.titleFont)
                    .foregroundStyle(self.runicTheme.secondaryText)
                Spacer(minLength: RunicSpacing.xs)
                if let reset = self.metric.resetText {
                    Text(reset)
                        .font(self.fonts.caption2)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            }

            if self.displayMode.showsBars {
                UsageProgressBar(
                    percent: self.metric.percent,
                    tint: self.tint,
                    accessibilityLabel: self.metric.percentStyle.accessibilityLabel)
            }

            if self.displayMode.showsPercent {
                HStack(alignment: .firstTextBaseline, spacing: RunicSpacing.xs) {
                    Text(self.metric.percentLabel)
                        .font(self.percentFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                    Spacer()
                }
            }

            if let detail = self.metric.detailText {
                Text(detail)
                    .font(self.fonts.caption)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
                    .textCase(.none)
            }
        }
        .padding(MenuCardMetrics.metricCardPadding)
        .background(
            RoundedRectangle(
                cornerRadius: MenuCardMetrics.metricCardCornerRadius,
                style: .continuous)
                .fill(self.runicTheme.menuSubtleFill.opacity(self.isHighlighted ? 1.0 : 0.82)))
        .overlay(
            RoundedRectangle(
                cornerRadius: MenuCardMetrics.metricCardCornerRadius,
                style: .continuous)
                .strokeBorder(self.runicTheme.cardStroke.opacity(0.42), lineWidth: 1))
    }

    private var titleFont: Font {
        self.runicTheme.isTerminalHUD ? self.fonts.footnote.weight(.semibold) : self.fonts.caption.weight(.semibold)
    }

    private var percentFont: Font {
        self.runicTheme.isTerminalHUD ? self.fonts.numericHeadline : self.fonts.numericFootnote.weight(.semibold)
    }
}

struct CreditsBarContent: View {
    @Environment(\.runicFonts) private var fonts
    private static let fullScaleTokens: Double = 1000

    let creditsText: String
    let creditsRemaining: Double?
    let hintText: String?
    let hintCopyText: String?
    let progressColor: Color
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

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
                .font(self.fonts.body)
                .fontWeight(.medium)
            if let percentLeft {
                UsageProgressBar(
                    percent: percentLeft,
                    tint: self.progressColor,
                    accessibilityLabel: "Credits remaining")
                HStack(alignment: .firstTextBaseline) {
                    Text(self.creditsText)
                        .font(self.fonts.caption)
                    Spacer()
                    Text(self.scaleText)
                        .font(self.fonts.caption)
                        .foregroundStyle(self.runicTheme.secondaryText)
                }
            } else {
                Text(self.creditsText)
                    .font(self.fonts.caption)
            }
            if let hintText, !hintText.isEmpty {
                Text(hintText)
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay {
                        ClickToCopyOverlay(copyText: self.hintCopyText ?? hintText)
                    }
            }
        }
    }
}

struct ClickToCopyOverlay: NSViewRepresentable {
    let copyText: String

    func makeNSView(context: Context) -> ClickToCopyView {
        ClickToCopyView(copyText: self.copyText)
    }

    func updateNSView(_ nsView: ClickToCopyView, context: Context) {
        nsView.copyText = self.copyText
    }
}

final class ClickToCopyView: NSView {
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        _ = event
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(self.copyText, forType: .string)
    }
}
