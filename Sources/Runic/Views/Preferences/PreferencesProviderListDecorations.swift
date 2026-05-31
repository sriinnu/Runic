import AppKit
import RunicCore
import SwiftUI

@MainActor
struct ProviderListBrandIcon: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        Group {
            if let brand = ProviderBrandIcon.image(for: self.provider, size: ProviderListMetrics.iconSize) {
                Image(nsImage: brand)
                    .resizable()
                    .scaledToFit()
                    .frame(width: ProviderListMetrics.iconSize, height: ProviderListMetrics.iconSize)
            } else {
                let descriptor = ProviderDescriptorRegistry.descriptor(for: self.provider)
                let initial = String(descriptor.metadata.displayName.prefix(1)).uppercased()
                let brandColor = Color(
                    red: Double(descriptor.branding.color.red),
                    green: Double(descriptor.branding.color.green),
                    blue: Double(descriptor.branding.color.blue))
                ZStack {
                    RoundedRectangle(
                        cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                        style: .continuous)
                        .fill(brandColor.opacity(0.18))
                    Text(initial)
                        .font(self.fonts.system(size: ProviderListMetrics.iconSize * 0.5, weight: .bold))
                        .foregroundStyle(brandColor)
                }
                .frame(width: ProviderListMetrics.iconSize, height: ProviderListMetrics.iconSize)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .accessibilityHidden(true)
    }
}

@MainActor
struct ProviderInsightsView: View {
    @Environment(\.runicFonts) private var fonts
    let lines: [ProviderInsightLine]
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: ProviderListMetrics.providerInsightsGridItemMinWidth),
                    spacing: ProviderListMetrics.providerInsightsChipSpacing),
            ],
            alignment: .leading,
            spacing: ProviderListMetrics.providerInsightsChipSpacing)
        {
            ForEach(self.lines) { line in
                ProviderInsightChip(line: line)
            }
        }
        .padding(ProviderListMetrics.insightsCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.providerInsightsCardCornerRadius,
                style: .continuous)
                .fill(self.runicTheme.menuSubtleFill))
        .overlay {
            RoundedRectangle(
                cornerRadius: ProviderListMetrics.providerInsightsCardCornerRadius,
                style: .continuous)
                .strokeBorder(self.runicTheme.menuSeparatorColor.opacity(0.44), lineWidth: 1)
        }
    }
}

private struct ProviderInsightChip: View {
    @Environment(\.runicFonts) private var fonts
    let line: ProviderInsightLine
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
            Text(self.line.label.uppercased())
                .font(self.fonts.caption2.weight(.semibold))
                .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
            Text(self.line.value)
                .font(self.fonts.caption)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .help(self.line.help ?? "")
        }
        .padding(ProviderListMetrics.providerInsightsChipPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerInsightsChipCornerRadius, style: .continuous)
                .fill(self.runicTheme.surface.opacity(self.runicTheme.isTerminalHUD ? 0.62 : 0.38)))
        .overlay(
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerInsightsChipCornerRadius, style: .continuous)
                .strokeBorder(self.runicTheme.menuSeparatorColor.opacity(0.34), lineWidth: 1))
        .help(self.line.help ?? "")
        .accessibilityLabel("\(self.line.label): \(self.line.value)")
        .accessibilityHint(self.line.help ?? "")
    }
}

@MainActor
private struct ProviderListSectionDividerView: View {
    @Environment(\.runicFonts) private var fonts

    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.5))
            .frame(height: 1)
            .padding(.leading, ProviderListMetrics.dividerLeadingInset)
            .padding(.trailing, ProviderListMetrics.dividerTrailingInset)
    }
}

extension View {
    func providerSectionDivider(isVisible: Bool) -> some View {
        overlay(alignment: .bottom) {
            if isVisible {
                ProviderListSectionDividerView()
            }
        }
    }
}
