import AppKit
import RunicCore
import SwiftUI

struct UsageMenuCardHeaderView: View {
    @Environment(\.runicFonts) private var fonts
    let model: UsageMenuCardView.Model
    @Environment(\.menuItemHighlighted) private var isHighlighted
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .center, spacing: RunicSpacing.sm) {
                ProviderAvatarView(provider: self.model.provider)

                VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                    Text(self.model.providerName)
                        .font(self.providerTitleFont)
                    if !self.model.email.isEmpty {
                        if self.runicTheme.id == "retro" {
                            Text(self.model.email)
                                .font(self.fonts.caption)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .lineLimit(1)
                        } else {
                            ProfilePill(
                                text: self.model.email,
                                systemImage: "person.crop.circle",
                                tint: self.brandAccent)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: RunicSpacing.xxxs) {
                    if let badge = self.model.headerBadge {
                        MenuHeaderBadgeView(badge: badge, isHighlighted: self.isHighlighted)
                    }
                    if let plan = self.model.planText {
                        if self.runicTheme.id == "retro" {
                            RetroPlanTag(text: plan)
                        } else {
                            ProfilePill(
                                text: plan,
                                systemImage: "sparkles",
                                tint: self.brandAccent,
                                style: .plan)
                                .lineLimit(1)
                        }
                    }
                }
            }

            let subtitleAlignment: VerticalAlignment = self.model.subtitleStyle == .error ? .top : .firstTextBaseline
            HStack(alignment: subtitleAlignment) {
                Text(self.model.subtitleText)
                    .font(self.fonts.footnote.weight(.medium))
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
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, RunicSpacing.xs)
        .padding(.vertical, RunicSpacing.xs)
        .background(self.headerBackground)
        .overlay(self.headerBorder)
    }

    /// Terminal needs a visible title jump because monospaced weights read
    /// flatter at small sizes than proportional UI fonts.
    private var providerTitleFont: Font {
        self.runicTheme.isTerminalHUD ? self.fonts.title3.weight(.bold) : self.fonts.headline.weight(.semibold)
    }

    private var subtitleColor: Color {
        switch self.model.subtitleStyle {
        case .info: self.runicTheme.secondaryText
        case .loading: self.runicTheme.secondaryText
        case .error: MenuHighlightStyle.error(self.isHighlighted, theme: self.runicTheme)
        }
    }

    private var brandAccent: Color {
        let color = ProviderDescriptorRegistry.descriptor(for: self.model.provider).branding.color
        return Color(red: color.red, green: color.green, blue: color.blue)
    }

    private var headerBackground: some View {
        let base = self.brandNSColor
        let top = base.blended(withFraction: 0.35, of: .white) ?? base
        let accentTop = self.runicTheme.isTerminalHUD ? self.runicTheme.accent : Color(nsColor: top)
        let accentBase = self.runicTheme.isTerminalHUD ? self.runicTheme.tertiary : Color(nsColor: base)
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.lg)
        let isRetro = self.runicTheme.id == "retro"
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(self.runicTheme.cardBackgroundStyle)
            .overlay(
                ZStack {
                    // Brand-tinted gradient overlay washes the card with the
                    // provider's hue. On Retro this clashes with the
                    // parchment palette -- skip it entirely there.
                    if !isRetro {
                        LinearGradient(
                            colors: [
                                accentTop.opacity(self.runicTheme.isTerminalHUD ? 0.10 : 0.14),
                                accentBase.opacity(self.runicTheme.isTerminalHUD ? 0.04 : 0.04),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    }
                    if self.runicTheme.isTerminalHUD {
                        RunicTerminalScanlineOverlay(opacity: 0.55)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    @ViewBuilder
    private var headerBorder: some View {
        let radius = self.runicTheme.shape.cornerRadius(RunicCornerRadius.lg)
        if self.runicTheme.id == "retro" {
            // Retro: the outer MenuPopoverSurfaceCard bevel already frames
            // the whole provider hero. Drawing another inner frame around
            // just the email row produced nested-rectangle ugliness -- skip.
            EmptyView()
        } else {
            // Other themes: brand-colored stroke gives each card its own hue.
            let base = self.runicTheme.isTerminalHUD
                ? self.runicTheme.accent
                : Color(nsColor: self.brandNSColor)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(
                    base.opacity(self.isHighlighted ? 0.76 : 0.45),
                    lineWidth: self.runicTheme.isTerminalHUD ? 0.9 : 0.7)
        }
    }

    private var brandNSColor: NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: self.model.provider).branding.color
        return NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: 1)
    }
}

private struct ProviderAvatarView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider

    var body: some View {
        let size: CGFloat = 40
        ZStack {
            if let icon = ProviderBrandIcon.image(for: self.provider, size: 30) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .shadow(color: Color(nsColor: self.brandNSColor).opacity(0.28), radius: 4, x: 0, y: 2)
            } else {
                Text(self.fallbackInitials)
                    .font(self.fonts.caption.weight(.semibold))
                    .foregroundStyle(Color(nsColor: self.brandNSColor))
            }
        }
        .frame(width: size, height: size)
    }

    private var brandNSColor: NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: self.provider).branding.color
        return NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: 1)
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

private struct RetroPlanTag: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    let text: String

    var body: some View {
        Text(self.text.uppercased())
            .font(self.fonts.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(self.runicTheme.cardStroke)
            .lineLimit(1)
            .padding(.horizontal, RunicSpacing.compact)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(self.runicTheme.surfaceAlt))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(self.runicTheme.cardStroke, lineWidth: 0.8))
    }
}

private struct ProfilePill: View {
    @Environment(\.runicFonts) private var fonts
    enum Style { case email, plan }

    let text: String
    let systemImage: String
    let tint: Color
    var style: Style = .email
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: RunicSpacing.xxxs) {
            Image(systemName: self.systemImage)
                .font(self.fonts.caption2.weight(.semibold))
            Text(self.text)
                .font(self.fonts.caption.weight(.medium))
        }
        .padding(.horizontal, RunicSpacing.compact)
        .padding(.vertical, RunicSpacing.xxxs)
        .foregroundStyle(self.foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.backgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.borderColor, lineWidth: 0.5))
    }

    private var foregroundColor: Color {
        switch self.style {
        case .email:
            self.runicTheme.secondaryText
        case .plan:
            self.tint.opacity(RunicColors.Opacity.vivid)
        }
    }

    private var backgroundColor: Color {
        switch self.style {
        case .email:
            self.runicTheme.menuSubtleFill
        case .plan:
            self.tint.opacity(RunicColors.Opacity.light)
        }
    }

    private var borderColor: Color {
        switch self.style {
        case .email:
            self.runicTheme.cardStroke.opacity(RunicColors.Opacity.strong)
        case .plan:
            self.tint.opacity(RunicColors.Opacity.medium)
        }
    }
}

private struct MenuHeaderBadgeView: View {
    @Environment(\.runicFonts) private var fonts
    let badge: UsageMenuCardView.Model.HeaderBadge
    let isHighlighted: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(spacing: RunicSpacing.xxs) {
            if self.badge.style == .info {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
                    .frame(width: 10, height: 10)
            } else {
                Image(systemName: self.badgeIcon)
                    .font(self.fonts.caption2.weight(.semibold))
            }
            Text(self.badge.text)
                .font(self.fonts.caption2.weight(.semibold))
        }
        .padding(.horizontal, RunicSpacing.compact)
        .padding(.vertical, RunicSpacing.xxxs)
        .foregroundStyle(self.foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .fill(self.backgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                .stroke(self.borderColor, lineWidth: 0.5))
    }

    private var badgeIcon: String {
        switch self.badge.style {
        case .info: "arrow.triangle.2.circlepath"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch self.badge.style {
        case .info:
            self.runicTheme.accent.opacity(self.isHighlighted ? 0.25 : 0.12)
        case .warning:
            self.runicTheme.highlight.opacity(self.isHighlighted ? 0.35 : 0.15)
        case .error:
            RunicColors.error.opacity(self.isHighlighted ? 0.35 : 0.15)
        }
    }

    private var foregroundColor: Color {
        switch self.badge.style {
        case .info:
            self.runicTheme.accent.opacity(RunicColors.Opacity.vivid)
        case .warning:
            self.runicTheme.highlight
        case .error:
            RunicColors.error
        }
    }

    private var borderColor: Color {
        switch self.badge.style {
        case .info:
            self.runicTheme.accent.opacity(RunicColors.Opacity.medium)
        case .warning:
            self.runicTheme.highlight.opacity(RunicColors.Opacity.strong)
        case .error:
            RunicColors.error.opacity(RunicColors.Opacity.strong)
        }
    }
}

struct MenuEmptyStateView: View {
    @Environment(\.runicFonts) private var fonts
    let providerName: String
    let placeholder: String
    let isHighlighted: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
            HStack(spacing: RunicSpacing.xxs) {
                Image(systemName: "sparkles")
                    .font(self.fonts.caption.weight(.semibold))
                Text("Connect \(self.providerName)")
                    .font(self.fonts.subheadline.weight(.semibold))
            }
            Text(self.placeholder)
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.secondaryText)
            Text("Open Settings → Providers, add credentials, then refresh.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CopyIconButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    @Environment(\.runicTheme) private var runicTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(RunicSpacing.xxs)
            .background {
                RoundedRectangle(
                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.xs),
                    style: .continuous)
                    .fill(self.runicTheme.secondaryText.opacity(configuration.isPressed ? 0.18 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(self.runicTheme.motion.curve, value: configuration.isPressed)
    }
}

private struct CopyIconButton: View {
    @Environment(\.runicFonts) private var fonts
    let copyText: String
    let isHighlighted: Bool

    @State private var didCopy = false
    @State private var resetTask: Task<Void, Never>?
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Button {
            self.copyToPasteboard()
            withAnimation(self.runicTheme.motion.curve) {
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
                .font(self.fonts.caption2.weight(.semibold))
                .foregroundStyle(self.runicTheme.secondaryText)
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
