import AppKit
import RunicCore
import SwiftUI

/// **Menu Card Layout Metrics**
/// Defines all spacing and padding constants for the menu card UI.
/// These values are carefully tuned for readability and visual hierarchy.
enum MenuCardMetrics {
    /// Horizontal padding on left/right edges of card content
    static let horizontalPadding: CGFloat = RunicSpacing.sm  // 12

    /// Top padding for the header section (provider name, email)
    static let headerTopPadding: CGFloat = RunicSpacing.xxs  // 4

    /// Bottom padding for the header section
    static let headerBottomPadding: CGFloat = RunicSpacing.xxs  // 4

    /// Top padding for content sections (usage, credits, cost)
    static let sectionTopPadding: CGFloat = RunicSpacing.xs  // 8

    /// Bottom padding for content sections
    static let sectionBottomPadding: CGFloat = RunicSpacing.xxs  // 4

    /// Vertical spacing between major sections (e.g., Session vs Weekly)
    static let sectionSpacing: CGFloat = RunicSpacing.xs  // 8

    /// Spacing between related blocks of content
    static let blockSpacing: CGFloat = RunicSpacing.xs  // 8

    /// Spacing between individual text lines within a section
    static let lineSpacing: CGFloat = RunicSpacing.xxs  // 4

    /// Base padding for menu items
    static let menuItemBasePadding: CGFloat = RunicSpacing.xxs  // 4

    /// Additional padding for text with descenders (y, g, p, q, j)
    static let menuItemDescenderPadding: CGFloat = RunicSpacing.xxxs  // 2

    /// Tail padding at the end of sections
    static let tailPadding: CGFloat = RunicSpacing.xxs  // 4
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
            let sessionDetailLine: String?
            let monthLine: String
            let monthDetailLine: String?
            let updatedLine: String
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
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            UsageMenuCardHeaderView(model: self.model)

            if self.hasDetails {
                Divider()
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
                                                    .font(.system(.footnote, design: .rounded))
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
                            .padding(.vertical, RunicSpacing.xxs)
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
                            .padding(.vertical, RunicSpacing.xxs)
                    }
                    if let providerCost = self.model.providerCost {
                        ProviderCostContent(
                            section: providerCost,
                            progressColor: self.model.progressColor)
                    }
                    if hasExtraUsage, hasTokenCost || hasInsights {
                        Divider()
                            .padding(.vertical, RunicSpacing.xxs)
                    }
                    if let tokenUsage = self.model.tokenUsage {
                        VStack(alignment: .leading, spacing: MenuCardMetrics.lineSpacing) {
                            Text("Cost")
                                .font(.body)
                                .fontWeight(.medium)
                            Text(tokenUsage.sessionLine)
                                .font(.footnote)
                            if let sessionDetail = tokenUsage.sessionDetailLine {
                                Text(sessionDetail)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            }
                            Text(tokenUsage.monthLine)
                                .font(.footnote)
                            if let monthDetail = tokenUsage.monthDetailLine {
                                Text(monthDetail)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            }
                            Text(tokenUsage.updatedLine)
                                .font(.caption)
                                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            if let hint = tokenUsage.hintLine, !hint.isEmpty {
                                Text(hint)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let error = tokenUsage.errorLine, !error.isEmpty {
                                HStack(alignment: .top, spacing: RunicSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.footnote)
                                        .foregroundStyle(RunicColors.error)
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(RunicSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                                        .fill(RunicColors.error.opacity(RunicColors.Opacity.subtle)))
                                .overlay {
                                    ClickToCopyOverlay(copyText: tokenUsage.errorCopyText ?? error)
                                }
                            }
                        }
                    }
                    if hasCost, hasInsights {
                        Divider()
                            .padding(.vertical, RunicSpacing.xxs)
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
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .center, spacing: RunicSpacing.sm) {
                ProviderAvatarView(provider: self.model.provider)

                VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                    Text(self.model.providerName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    if !self.model.email.isEmpty {
                        ProfilePill(
                            text: self.model.email,
                            systemImage: "person.crop.circle",
                            tint: self.brandAccent)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RunicSpacing.xxxs) {
                    if let badge = self.model.headerBadge {
                        MenuHeaderBadgeView(badge: badge, isHighlighted: self.isHighlighted)
                    }
                    if let plan = self.model.planText {
                        ProfilePill(
                            text: plan,
                            systemImage: "sparkles",
                            tint: self.brandAccent,
                            style: .plan)
                            .lineLimit(1)
                    }
                }
            }

            let subtitleAlignment: VerticalAlignment = self.model.subtitleStyle == .error ? .top : .firstTextBaseline
            HStack(alignment: subtitleAlignment) {
                Text(self.model.subtitleText)
                    .font(.footnote.weight(.medium))
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
            }

            if let topModelLine = self.model.topModelLine {
                Text(topModelLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xs)
        .background(self.headerBackground)
        .overlay(self.headerBorder)
    }

    private var subtitleColor: Color {
        switch self.model.subtitleStyle {
        case .info: MenuHighlightStyle.secondary(self.isHighlighted)
        case .loading: MenuHighlightStyle.secondary(self.isHighlighted)
        case .error: MenuHighlightStyle.error(self.isHighlighted)
        }
    }

    private var brandAccent: Color {
        let color = ProviderDescriptorRegistry.descriptor(for: self.model.provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private var headerBackground: some View {
        let base = self.brandNSColor
        let top = base.blended(withFraction: 0.35, of: .white) ?? base
        let bottom = base.blended(withFraction: 0.25, of: .black) ?? base
        let start = Color(nsColor: top).opacity(RunicColors.Opacity.medium)
        let end = Color(nsColor: bottom).opacity(RunicColors.Opacity.light)
        return RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
            .fill(LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var headerBorder: some View {
        return RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
            .stroke(Color.white.opacity(RunicColors.Opacity.medium), lineWidth: 0.7)
    }

    private var brandNSColor: NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: self.model.provider).branding.color
        return NSColor(calibratedRed: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1)
    }
}

private struct ProviderAvatarView: View {
    let provider: UsageProvider

    var body: some View {
        let size: CGFloat = 40
        let base = self.brandNSColor
        let top = base.blended(withFraction: 0.35, of: .white) ?? base
        let mid = base.blended(withFraction: 0.15, of: .black) ?? base
        let bottom = base.blended(withFraction: 0.35, of: .black) ?? base

        let coreGradient = LinearGradient(
            colors: [Color(nsColor: top), Color(nsColor: mid), Color(nsColor: bottom)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)

        let ringGradient = AngularGradient(
            colors: [
                Color.white.opacity(RunicColors.Opacity.vivid),
                Color(nsColor: top).opacity(RunicColors.Opacity.emphasis),
                Color.white.opacity(RunicColors.Opacity.medium),
                Color(nsColor: bottom).opacity(RunicColors.Opacity.prominent),
                Color.white.opacity(RunicColors.Opacity.vivid),
            ],
            center: .center)

        ZStack {
            RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                .fill(coreGradient)
                .shadow(color: Color(nsColor: base).opacity(0.25), radius: 6, x: 0, y: 4)

            RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                .stroke(ringGradient, lineWidth: 1.2)

            RoundedRectangle(cornerRadius: RunicCornerRadius.lg - 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .padding(RunicSpacing.xxxs)
                .blendMode(.screen)

            if let icon = ProviderBrandIcon.templateImage(for: self.provider, size: 18) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.white.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
            } else {
                Text(self.fallbackInitials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.lg, style: .continuous)
                .stroke(Color.white.opacity(RunicColors.Opacity.medium), lineWidth: 0.6))
    }

    private var brandNSColor: NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: self.provider).branding.color
        return NSColor(calibratedRed: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1)
    }

    private var fallbackInitials: String {
        let name = ProviderDescriptorRegistry.descriptor(for: self.provider).metadata.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }
}

private struct ProfilePill: View {
    enum Style { case email, plan }

    let text: String
    let systemImage: String
    let tint: Color
    var style: Style = .email

    var body: some View {
        HStack(spacing: RunicSpacing.xxxs) {
            Image(systemName: self.systemImage)
                .font(.caption2.weight(.semibold))
            Text(self.text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, RunicSpacing.compact)
        .padding(.vertical, RunicSpacing.xxxs)
        .foregroundStyle(self.foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .fill(self.backgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .stroke(self.borderColor, lineWidth: 0.5))
    }

    private var foregroundColor: Color {
        switch self.style {
        case .email:
            return .secondary
        case .plan:
            return self.tint.opacity(RunicColors.Opacity.vivid)
        }
    }

    private var backgroundColor: Color {
        switch self.style {
        case .email:
            return Color(nsColor: .quaternaryLabelColor).opacity(RunicColors.Opacity.emphasis)
        case .plan:
            return self.tint.opacity(RunicColors.Opacity.light)
        }
    }

    private var borderColor: Color {
        switch self.style {
        case .email:
            return Color(nsColor: .separatorColor).opacity(RunicColors.Opacity.strong)
        case .plan:
            return self.tint.opacity(RunicColors.Opacity.medium)
        }
    }
}


private struct MenuHeaderBadgeView: View {
    let badge: UsageMenuCardView.Model.HeaderBadge
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: RunicSpacing.xxs) {
            if self.badge.style == .info {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
                    .frame(width: 10, height: 10)
            } else {
                Image(systemName: self.badgeIcon)
                    .font(.caption2.weight(.semibold))
            }
            Text(self.badge.text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, RunicSpacing.compact)
        .padding(.vertical, RunicSpacing.xxxs)
        .foregroundStyle(self.foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .fill(self.backgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                .stroke(self.borderColor, lineWidth: 0.5))
    }

    private var badgeIcon: String {
        switch self.badge.style {
        case .info: return "arrow.triangle.2.circlepath"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch self.badge.style {
        case .info:
            return Color(nsColor: .systemBlue).opacity(self.isHighlighted ? 0.25 : 0.12)
        case .warning:
            return Color(nsColor: .systemOrange).opacity(self.isHighlighted ? 0.35 : 0.15)
        case .error:
            return Color(nsColor: .systemRed).opacity(self.isHighlighted ? 0.35 : 0.15)
        }
    }

    private var foregroundColor: Color {
        switch self.badge.style {
        case .info:
            return Color(nsColor: .systemBlue).opacity(RunicColors.Opacity.vivid)
        case .warning:
            return Color(nsColor: .systemOrange)
        case .error:
            return Color(nsColor: .systemRed)
        }
    }

    private var borderColor: Color {
        switch self.badge.style {
        case .info:
            return Color(nsColor: .systemBlue).opacity(RunicColors.Opacity.medium)
        case .warning:
            return Color(nsColor: .systemOrange).opacity(RunicColors.Opacity.strong)
        case .error:
            return Color(nsColor: .systemRed).opacity(RunicColors.Opacity.strong)
        }
    }
}

private struct MenuEmptyStateView: View {
    let providerName: String
    let placeholder: String
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack(spacing: RunicSpacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                Text("Connect \(self.providerName)")
                    .font(.subheadline.weight(.semibold))
            }
            Text(self.placeholder)
                .font(.footnote)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            Text("Open Settings → Providers, add credentials, then refresh.")
                .font(.footnote)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CopyIconButtonStyle: ButtonStyle {
    let isHighlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(RunicSpacing.xxs)
            .background {
                RoundedRectangle(cornerRadius: RunicCornerRadius.xs, style: .continuous)
                    .fill(MenuHighlightStyle.secondary(self.isHighlighted).opacity(configuration.isPressed ? 0.18 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(RunicAnimation.highlight, value: configuration.isPressed)
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
            withAnimation(RunicAnimation.highlight) {
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
                    .font(.system(.footnote, design: .rounded))
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
            if let forecastLine = self.section.forecastLine {
                Text(forecastLine)
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
            if let projectDetail = self.section.projectDetail {
                Text(projectDetail)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let anomalyLine = self.section.anomalyLine {
                Text(anomalyLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let anomalyDetail = self.section.anomalyDetail {
                Text(anomalyDetail)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let reliabilityLine = self.section.reliabilityLine {
                Text(reliabilityLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let reliabilityDetail = self.section.reliabilityDetail {
                Text(reliabilityDetail)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let routingLine = self.section.routingLine {
                Text(routingLine)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let routingDetail = self.section.routingDetail {
                Text(routingDetail)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let updated = self.section.updatedLine {
                Text(updated)
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            }
            if let error = self.section.errorLine {
                HStack(alignment: .top, spacing: RunicSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(RunicColors.error)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(RunicSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
                        .fill(RunicColors.error.opacity(RunicColors.Opacity.subtle)))
            }
        }
    }
}

struct UsageMenuCardHeaderSectionView: View {
    let model: UsageMenuCardView.Model
    let showDivider: Bool
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            UsageMenuCardHeaderView(model: self.model)

            if self.showDivider {
                Divider()
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
                                        .font(.system(.footnote, design: .rounded))
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
                        .font(.system(.caption, design: .rounded))
                    Spacer()
                    Text(self.scaleText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                }
            } else {
                Text(self.creditsText)
                    .font(.system(.caption, design: .rounded))
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
                                .font(.system(.caption, design: .rounded))
                            if let sessionDetail = tokenUsage.sessionDetailLine {
                                Text(sessionDetail)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            }
                            Text(tokenUsage.monthLine)
                                .font(.system(.caption, design: .rounded))
                            if let monthDetail = tokenUsage.monthDetailLine {
                                Text(monthDetail)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            }
                            Text(tokenUsage.updatedLine)
                                .font(.caption)
                                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                            if let hint = tokenUsage.hintLine, !hint.isEmpty {
                                Text(hint)
                                    .font(.footnote)
                                    .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
                                    .lineLimit(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let error = tokenUsage.errorLine, !error.isEmpty {
                                HStack(alignment: .top, spacing: RunicSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.footnote)
                                        .foregroundStyle(RunicColors.error)
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
                                        .lineLimit(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(RunicSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: RunicCornerRadius.sm, style: .continuous)
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
        let ledgerTopProject: UsageLedgerProjectSummary?
        let ledgerSpendForecast: UsageLedgerSpendForecast?
        let ledgerTopProjectSpendForecast: UsageLedgerSpendForecast?
        let ledgerAnomaly: UsageLedgerAnomalySummary?
        let ledgerReliability: UsageLedgerReliabilityScore?
        let ledgerRouting: UsageLedgerRoutingRecommendation?
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
        let topModelLine = Self.topModelLine(input.ledgerTopModel)
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
        var parts = ["Top model: \(modelName)", "\(tokens) tokens", "\(summary.entryCount) req"]
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
        let nonEmptyDays = snapshot.daily.filter { entry in
            (entry.totalTokens ?? 0) > 0 || (entry.costUSD ?? 0) > 0
        }.count
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
        let hasData = daily != nil || block != nil || topModel != nil || topProject != nil || spendForecast != nil || anomaly != nil
        if !hasData && (error?.isEmpty ?? true) {
            return nil
        }

        var todayLine: String?
        var todayDetail: String?
        if let daily {
            let tokens = UsageFormatter.tokenCountString(daily.totals.totalTokens)
            todayLine = "Today: \(tokens) tokens"
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
                var spendParts = ["Spend \(UsageFormatter.usdString(cost))"]
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: daily.totals.totalTokens)
                {
                    spendParts.append(per1K)
                }
                details.append(spendParts.joined(separator: " · "))
            }
            if !details.isEmpty {
                todayDetail = details.joined(separator: "\n")
            }
        }

        var forecastLine: String?
        if let spendForecast {
            let projected = UsageFormatter.usdString(spendForecast.projected30DayCostUSD)
            let observedDayLabel = spendForecast.observedDays == 1 ? "day" : "days"
            forecastLine = "Month-end forecast: \(projected) · \(spendForecast.observedDays) observed \(observedDayLabel)"
        }

        var blockLine: String?
        var blockDetail: String?
        if let block, block.isActive {
            let tokens = UsageFormatter.tokenCountString(block.totals.totalTokens)
            blockLine = "Active block: \(tokens) tokens · \(block.entryCount) req"
            var details: [String] = []
            details.append("Ends \(UsageFormatter.resetCountdownDescription(from: block.end, now: input.now))")
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
                var spendParts = ["Spend \(UsageFormatter.usdString(cost))"]
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: block.totals.totalTokens)
                {
                    spendParts.append(per1K)
                }
                if let perRequest = UsageFormatter.usdPerRequestString(
                    costUSD: cost,
                    requestCount: block.entryCount)
                {
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
            blockDetail = details.joined(separator: "\n")
        }

        var modelLine: String?
        if let topModel {
            let tokens = UsageFormatter.tokenCountString(topModel.totals.totalTokens)
            let modelName = UsageFormatter.modelDisplayName(topModel.model)
            var parts = ["Top model: \(modelName) · \(tokens) tokens · \(topModel.entryCount) req"]
            if let cost = topModel.totals.costUSD {
                parts.append(UsageFormatter.usdString(cost))
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: topModel.totals.totalTokens)
                {
                    parts.append(per1K)
                }
            }
            modelLine = parts.joined(separator: " · ")
        }

        var projectLine: String?
        var projectDetail: String?
        if let topProject {
            let name = Self.insightsProjectDisplayName(topProject)
            let tokens = UsageFormatter.tokenCountString(topProject.totals.totalTokens)
            var parts = ["Top project: \(name) · \(tokens) tokens · \(topProject.entryCount) req"]
            if let cost = topProject.totals.costUSD {
                parts.append(UsageFormatter.usdString(cost))
                if let per1K = UsageFormatter.usdPer1KTokensString(
                    costUSD: cost,
                    tokenCount: topProject.totals.totalTokens)
                {
                    parts.append(per1K)
                }
            }
            projectLine = parts.joined(separator: " · ")

            if let projectForecast = topProjectSpendForecast {
                var detailParts = ["30d forecast \(UsageFormatter.usdString(projectForecast.projected30DayCostUSD))"]
                if let budgetLimit = projectForecast.budgetLimitUSD {
                    detailParts.append("Budget \(UsageFormatter.usdString(budgetLimit))")
                    if let budgetETAInDays = projectForecast.budgetETAInDays {
                        detailParts.append(Self.budgetBreachETAText(days: budgetETAInDays, now: input.now))
                    } else if !projectForecast.budgetWillBreach {
                        detailParts.append("No breach at current pace")
                    }
                }
                projectDetail = detailParts.joined(separator: " · ")
            }
        }

        var anomalyLine: String?
        var anomalyDetail: String?
        if let anomaly, let primary = anomaly.primaryAnomaly {
            anomalyLine = "Anomaly: \(primary.severity.label) \(primary.metric.label) spike"
            var details = [Self.anomalyMetricDetail(primary, baselineDays: anomaly.baselineDays)]
            if let secondary = anomaly.secondaryAnomaly(excluding: primary.metric) {
                details.append(Self.anomalyMetricDetail(secondary, baselineDays: anomaly.baselineDays))
            }
            anomalyDetail = details.joined(separator: "\n")
        }

        var reliabilityLine: String?
        var reliabilityDetail: String?
        if let reliability = input.ledgerReliability {
            reliabilityLine = "Reliability: \(reliability.score)/100 · \(reliability.grade)"
            reliabilityDetail = reliability.primarySignal ?? reliability.summary
        }

        var routingLine: String?
        var routingDetail: String?
        if let routing = input.ledgerRouting {
            let from = UsageFormatter.modelDisplayName(routing.fromModel)
            let to = UsageFormatter.modelDisplayName(routing.toModel)
            routingLine = "Routing advisor: shift \(routing.shiftPercent)% \(from) -> \(to)"
            let confidenceText = "\(Int((routing.confidence * 100).rounded()))%"
            routingDetail = "Estimated savings: \(UsageFormatter.usdString(routing.estimatedSavingsUSD)) · confidence \(confidenceText)"
        }

        let updatedLine = input.ledgerUpdatedAt.map { UsageFormatter.updatedString(from: $0, now: input.now) }

        return InsightsSection(
            title: "Insights",
            todayLine: todayLine,
            todayDetail: todayDetail,
            forecastLine: forecastLine,
            blockLine: blockLine,
            blockDetail: blockDetail,
            modelLine: modelLine,
            projectLine: projectLine,
            projectDetail: projectDetail,
            anomalyLine: anomalyLine,
            anomalyDetail: anomalyDetail,
            reliabilityLine: reliabilityLine,
            reliabilityDetail: reliabilityDetail,
            routingLine: routingLine,
            routingDetail: routingDetail,
            updatedLine: updatedLine,
            errorLine: (error?.isEmpty ?? true) ? nil : error)
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

    private static func insightsProjectDisplayName(_ summary: UsageLedgerProjectSummary) -> String {
        let displayName = summary.displayProjectName
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
        let isUnknown = displayName == "Unknown project"
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

        var hash: UInt64 = 0xcbf29ce484222325
        for byte in projectID.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
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
