import RunicCore
import SwiftUI

@MainActor
struct ProviderListProviderRowView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    @Bindable var store: UsageStore
    @Binding var isEnabled: Bool
    let subtitle: String
    let usageStatus: ProviderUsageStatus
    let sourceLabel: String
    let statusLabel: String
    let errorDisplay: ProviderErrorDisplay?
    @Binding var isErrorExpanded: Bool
    let onCopyError: (String) -> Void
    @State private var isHovering = false
    @FocusState private var isToggleFocused: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        let isRefreshing = self.store.refreshingProviders.contains(self.provider)
        let showReorderHandle = self.isHovering || self.isToggleFocused
        let metadata = self.store.metadata(for: self.provider)
        let insightLines = ProviderInsightsComposer.lines(for: self.provider, store: self.store, maxRows: 4)

        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.$isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }
                .focused(self.$isToggleFocused)

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                    HStack(alignment: .top, spacing: RunicSpacing.sm) {
                        ProviderListBrandIcon(provider: self.provider)
                        VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                            Text(metadata.displayName)
                                .font(self.fonts.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(self.subtitle)
                                .font(self.fonts.footnote)
                                .foregroundStyle(self.runicTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: RunicSpacing.xs)
                    }

                    HStack(alignment: .center, spacing: RunicSpacing.xs) {
                        self.sourceBadge
                        Text(self.statusLabel)
                            .font(self.fonts.caption2)
                            .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
                            .lineLimit(1)

                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                            Text("Refreshing…")
                                .font(self.fonts.caption2)
                                .foregroundStyle(self.runicTheme.secondaryText)
                        } else {
                            self.usageStatusBadge
                                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { self.isEnabled.toggle() }

                if !insightLines.isEmpty {
                    ProviderInsightsView(lines: insightLines)
                        .padding(.top, RunicSpacing.xxs)
                }

                if let errorDisplay {
                    ProviderErrorView(
                        title: "Last \(metadata.displayName) fetch failed:",
                        display: errorDisplay,
                        isExpanded: self.$isErrorExpanded,
                        onCopy: { self.onCopyError(errorDisplay.full) })
                        .padding(.top, RunicSpacing.xxs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.providerCardPadding)
        .background(self.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.cardBorderColor, lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            ProviderListReorderHandle(isVisible: showReorderHandle)
                .offset(
                    x: -(ProviderListMetrics.reorderHandleSize + RunicSpacing.xs),
                    y: RunicSpacing.sm)
        }
        .onHover { isHovering in
            self.isHovering = isHovering
        }
    }

    private var usageStatusBadge: some View {
        let (color, backgroundColor) = self.usageStatusColors

        return Text(self.usageStatus.text)
            .font(self.fonts.caption2.weight(.medium))
            .padding(.horizontal, ProviderListMetrics.statusBadgePaddingH)
            .padding(.vertical, ProviderListMetrics.statusBadgePaddingV)
            .background(Capsule(style: .continuous).fill(backgroundColor))
            .foregroundStyle(color)
    }

    private var sourceBadge: some View {
        Text(self.sourceLabel)
            .font(self.fonts.caption2.weight(.medium))
            .foregroundStyle(self.runicTheme.secondaryText)
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, RunicSpacing.xxxs)
            .background(
                Capsule(style: .continuous)
                    .fill(self.runicTheme.menuSubtleFill))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(self.runicTheme.menuSeparatorColor.opacity(0.42), lineWidth: 0.7))
    }

    private var usageStatusColors: (Color, Color) {
        switch self.usageStatus.style {
        case .success:
            (.green, Color.green.opacity(0.15))
        case .error:
            (.red, Color.red.opacity(0.15))
        case .neutral:
            (.secondary, self.runicTheme.menuSubtleFill)
        }
    }

    private var rowBackgroundColor: Color {
        if self.isHovering {
            return self.runicTheme.menuSubtleFill.opacity(0.92)
        } else if self.isEnabled {
            return self.runicTheme.menuSubtleFill.opacity(ProviderListMetrics.providerCardBackgroundOpacity + 0.22)
        }
        return self.runicTheme.menuSubtleFill.opacity(0.46)
    }

    private var cardBorderColor: Color {
        if self.isHovering {
            return Color.accentColor.opacity(0.35)
        }
        if self.isEnabled {
            return self.runicTheme.menuSeparatorColor.opacity(ProviderListMetrics.providerCardBorderOpacity + 0.14)
        }
        return self.runicTheme.menuSeparatorColor.opacity(0.18)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(self.rowBackgroundColor)
    }
}

@MainActor
private struct ProviderListReorderHandle: View {
    @Environment(\.runicFonts) private var fonts
    let isVisible: Bool
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(spacing: ProviderListMetrics.reorderDotSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: ProviderListMetrics.reorderDotSpacing) {
                    Circle()
                        .frame(
                            width: ProviderListMetrics.reorderDotSize,
                            height: ProviderListMetrics.reorderDotSize)
                    Circle()
                        .frame(
                            width: ProviderListMetrics.reorderDotSize,
                            height: ProviderListMetrics.reorderDotSize)
                }
            }
        }
        .frame(width: ProviderListMetrics.reorderHandleSize, height: ProviderListMetrics.reorderHandleSize)
        .foregroundStyle(self.runicTheme.secondaryText.opacity(0.7))
        .opacity(self.isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: self.isVisible)
        .help("Drag to reorder")
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
