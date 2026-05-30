import AppKit
import RunicCore
import SwiftUI

@MainActor
struct ProviderListView: View {
    @Environment(\.runicFonts) private var fonts
    let providers: [UsageProvider]
    @Bindable var store: UsageStore
    let isEnabled: (UsageProvider) -> Binding<Bool>
    let subtitle: (UsageProvider) -> String
    let usageStatus: (UsageProvider) -> ProviderUsageStatus
    let sourceLabel: (UsageProvider) -> String
    let statusLabel: (UsageProvider) -> String
    let settingsToggles: (UsageProvider) -> [ProviderSettingsToggleDescriptor]
    let settingsFields: (UsageProvider) -> [ProviderSettingsFieldDescriptor]
    let errorDisplay: (UsageProvider) -> ProviderErrorDisplay?
    let isErrorExpanded: (UsageProvider) -> Binding<Bool>
    let onCopyError: (String) -> Void
    let moveProviders: (IndexSet, Int) -> Void

    var body: some View {
        List {
            ForEach(self.providers, id: \.self) { provider in
                let fields = self.settingsFields(provider)
                let toggles = self.settingsToggles(provider)
                let isEnabled = self.isEnabled(provider).wrappedValue
                let isFirstProvider = provider == self.providers.first
                let isLastProvider = provider == self.providers.last
                let shouldShowDivider = provider != self.providers.last
                let showDividerOnProviderRow = shouldShowDivider &&
                    (!isEnabled || (fields.isEmpty && toggles.isEmpty))
                let providerAddsBottomPadding = isLastProvider && (!isEnabled || (fields.isEmpty && toggles.isEmpty))

                ProviderListProviderRowView(
                    provider: provider,
                    store: self.store,
                    isEnabled: self.isEnabled(provider),
                    subtitle: self.subtitle(provider),
                    usageStatus: self.usageStatus(provider),
                    sourceLabel: self.sourceLabel(provider),
                    statusLabel: self.statusLabel(provider),
                    errorDisplay: self.isEnabled(provider).wrappedValue ? self.errorDisplay(provider) : nil,
                    isErrorExpanded: self.isErrorExpanded(provider),
                    onCopyError: self.onCopyError)
                    .padding(.bottom, showDividerOnProviderRow ? ProviderListMetrics.dividerBottomInset : 0)
                    .listRowInsets(self.rowInsets(
                        withDivider: showDividerOnProviderRow,
                        addTopPadding: isFirstProvider,
                        addBottomPadding: providerAddsBottomPadding))
                    .listRowSeparator(.hidden)
                    .providerSectionDivider(isVisible: showDividerOnProviderRow)

                if isEnabled {
                    let lastFieldID = fields.last?.id
                    ForEach(fields) { field in
                        let isLastField = field.id == lastFieldID
                        let showDivider = shouldShowDivider && toggles.isEmpty && isLastField
                        let fieldAddsBottomPadding = isLastProvider && toggles.isEmpty && isLastField

                        ProviderListFieldRowView(provider: provider, field: field)
                            .id(self.rowID(provider: provider, suffix: field.id))
                            .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                            .listRowInsets(self.rowInsets(
                                withDivider: showDivider,
                                addTopPadding: false,
                                addBottomPadding: fieldAddsBottomPadding))
                            .listRowSeparator(.hidden)
                            .providerSectionDivider(isVisible: showDivider)
                    }
                    let lastToggleID = toggles.last?.id
                    ForEach(toggles) { toggle in
                        let isLastToggle = toggle.id == lastToggleID
                        let showDivider = shouldShowDivider && isLastToggle
                        let toggleAddsBottomPadding = isLastProvider && isLastToggle

                        ProviderListToggleRowView(provider: provider, toggle: toggle)
                            .id(self.rowID(provider: provider, suffix: toggle.id))
                            .padding(.bottom, showDivider ? ProviderListMetrics.dividerBottomInset : 0)
                            .listRowInsets(self.rowInsets(
                                withDivider: showDivider,
                                addTopPadding: false,
                                addBottomPadding: toggleAddsBottomPadding))
                            .listRowSeparator(.hidden)
                            .providerSectionDivider(isVisible: showDivider)
                    }
                }
            }
            .onMove { fromOffsets, toOffset in
                self.moveProviders(fromOffsets, toOffset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ProviderListScrollInsetFixer())
    }

    private func rowInsets(withDivider: Bool, addTopPadding: Bool, addBottomPadding: Bool) -> EdgeInsets {
        let base = ProviderListMetrics.rowInsets
        let topInset = addTopPadding ? ProviderListMetrics.sectionEdgeInset : base.top
        let bottomInset = addBottomPadding
            ? ProviderListMetrics.sectionEdgeInset
            : (withDivider ? ProviderListMetrics.dividerBottomInset : base.bottom)
        return EdgeInsets(
            top: topInset,
            leading: base.leading,
            bottom: bottomInset,
            trailing: base.trailing)
    }

    private func rowID(provider: UsageProvider, suffix: String) -> String {
        "\(provider.rawValue)-\(suffix)"
    }
}

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
private struct ProviderListProviderRowView: View {
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
    fileprivate func providerSectionDivider(isVisible: Bool) -> some View {
        overlay(alignment: .bottom) {
            if isVisible {
                ProviderListSectionDividerView()
            }
        }
    }
}

@MainActor
private struct ProviderListToggleRowView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    let toggle: ProviderSettingsToggleDescriptor
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Toggle("", isOn: self.toggle.binding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.toggle.title)
                        .font(self.fonts.callout.weight(.semibold))
                    Text(self.toggle.subtitle)
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if self.toggle.binding.wrappedValue {
                    if let status = self.toggle.statusText?(), !status.isEmpty {
                        Text(status)
                            .font(self.fonts.caption)
                            .foregroundStyle(self.runicTheme.secondaryText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(RunicSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                                    style: .continuous)
                                    .fill(self.runicTheme.menuSubtleFill))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: self.runicTheme.shape.cornerRadius(RunicCornerRadius.sm),
                                    style: .continuous)
                                    .strokeBorder(self.runicTheme.menuSeparatorColor.opacity(0.38), lineWidth: 1)
                            }
                    }

                    let actions = self.toggle.actions.filter { $0.isVisible?() ?? true }
                    if !actions.isEmpty {
                        HStack(spacing: RunicSpacing.xs) {
                            ForEach(actions) { action in
                                Button(action.title) {
                                    Task { @MainActor in
                                        await action.perform()
                                    }
                                }
                                .applyProviderSettingsButtonStyle(action.style)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .padding(.leading, ProviderListMetrics.iconSize + RunicSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.supplementalCardPadding)
        .background(self.supplementalCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.supplementalCardBorderColor, lineWidth: 1)
        }
        .onChange(of: self.toggle.binding.wrappedValue) { _, enabled in
            guard let onChange = self.toggle.onChange else { return }
            Task { @MainActor in
                await onChange(enabled)
            }
        }
        .task(id: self.toggle.binding.wrappedValue) {
            guard self.toggle.binding.wrappedValue else { return }
            guard let onAppear = self.toggle.onAppearWhenEnabled else { return }
            await onAppear()
        }
    }

    private var supplementalCardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(self.runicTheme.menuSubtleFill.opacity(ProviderListMetrics.supplementalCardBackgroundOpacity + 0.20))
    }

    private var supplementalCardBorderColor: Color {
        self.runicTheme.menuSeparatorColor.opacity(ProviderListMetrics.supplementalCardBorderOpacity + 0.10)
    }
}

@MainActor
private struct ProviderListFieldRowView: View {
    @Environment(\.runicFonts) private var fonts
    let provider: UsageProvider
    let field: ProviderSettingsFieldDescriptor
    @Environment(\.runicTheme) private var runicTheme
    var body: some View {
        HStack(alignment: .top, spacing: ProviderListMetrics.rowSpacing) {
            Color.clear
                .frame(width: ProviderListMetrics.checkboxSize, height: ProviderListMetrics.checkboxSize)
                .alignmentGuide(.top) { d in d[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: RunicSpacing.sm) {
                VStack(alignment: .leading, spacing: RunicSpacing.xxs) {
                    Text(self.field.title)
                        .font(self.fonts.callout.weight(.semibold))
                    Text(self.field.subtitle)
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch self.field.kind {
                case .plain:
                    TextField(self.field.placeholder ?? "", text: self.field.binding)
                        .textFieldStyle(.roundedBorder)
                        .font(self.fonts.callout)
                        .frame(maxWidth: ProviderListMetrics.fieldMaxWidth, alignment: .leading)
                case .secure:
                    SecureField(self.field.placeholder ?? "", text: self.field.binding)
                        .textFieldStyle(.roundedBorder)
                        .font(self.fonts.callout)
                        .frame(maxWidth: ProviderListMetrics.fieldMaxWidth, alignment: .leading)
                }

                let actions = self.field.actions.filter { $0.isVisible?() ?? true }
                if !actions.isEmpty {
                    HStack(spacing: RunicSpacing.xs) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                Task { @MainActor in
                                    await action.perform()
                                }
                            }
                            .applyProviderSettingsButtonStyle(action.style)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .padding(.leading, ProviderListMetrics.iconSize + RunicSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ProviderListMetrics.supplementalCardPadding)
        .background(self.supplementalCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
                .strokeBorder(self.supplementalCardBorderColor, lineWidth: 1)
        }
    }

    private var supplementalCardBackground: some View {
        RoundedRectangle(cornerRadius: ProviderListMetrics.providerCardCornerRadius, style: .continuous)
            .fill(self.runicTheme.menuSubtleFill.opacity(ProviderListMetrics.supplementalCardBackgroundOpacity + 0.20))
    }

    private var supplementalCardBorderColor: Color {
        self.runicTheme.menuSeparatorColor.opacity(0.26)
    }
}

extension View {
    @ViewBuilder
    func applyProviderSettingsButtonStyle(_ style: ProviderSettingsActionDescriptor.Style) -> some View {
        switch style {
        case .bordered:
            self.buttonStyle(.bordered)
        case .link:
            self.buttonStyle(.link)
        }
    }
}

struct ProviderErrorDisplay {
    let preview: String
    let full: String
}

@MainActor
private struct ProviderListScrollInsetFixer: NSViewRepresentable {
    private final class HitTestIgnoringView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    func makeNSView(context: Context) -> NSView {
        HitTestIgnoringView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let scrollView = Self.findScrollView(from: nsView) else { return }
            if scrollView.automaticallyAdjustsContentInsets {
                scrollView.automaticallyAdjustsContentInsets = false
            }
            let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            let currentContentInsets = scrollView.contentInsets
            if currentContentInsets.top != 0 || currentContentInsets.left != 0 ||
                currentContentInsets.bottom != 0 || currentContentInsets.right != 0
            {
                scrollView.contentInsets = zeroInsets
            }
            let currentScrollerInsets = scrollView.scrollerInsets
            if currentScrollerInsets.top != 0 || currentScrollerInsets.left != 0 ||
                currentScrollerInsets.bottom != 0 || currentScrollerInsets.right != 0
            {
                scrollView.scrollerInsets = zeroInsets
            }
        }
    }

    private static func findScrollView(from view: NSView) -> NSScrollView? {
        var current: NSView? = view
        while let candidate = current {
            if let scroll = candidate as? NSScrollView { return scroll }
            if let found = candidate.subviews.compactMap({ $0 as? NSScrollView }).first {
                return found
            }
            current = candidate.superview
        }
        return nil
    }
}

@MainActor
struct ProviderErrorView: View {
    @Environment(\.runicFonts) private var fonts
    let title: String
    let display: ProviderErrorDisplay
    @Binding var isExpanded: Bool
    let onCopy: () -> Void
    @Environment(\.runicTheme) private var runicTheme

    var body: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            HStack(alignment: .center, spacing: RunicSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(self.fonts.caption)
                    .foregroundStyle(.orange)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                Text(self.title)
                    .font(self.fonts.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    self.onCopy()
                } label: {
                    HStack(alignment: .center, spacing: RunicSpacing.xxs) {
                        Image(systemName: "doc.on.doc")
                            .font(self.fonts.caption)
                        Text("Copy")
                            .font(self.fonts.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Copy error to clipboard")
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
            }

            Text(self.display.preview)
                .font(self.fonts.callout)
                .foregroundStyle(self.runicTheme.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(RunicSpacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color.orange.opacity(0.08)))

            if self.display.preview != self.display.full {
                Button(self.isExpanded ? "Hide details" : "Show details") { self.isExpanded.toggle() }
                    .buttonStyle(.link)
                    .font(self.fonts.callout)
            }

            if self.isExpanded {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(self.display.full)
                        .font(self.fonts.caption)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(ProviderListMetrics.errorCardPadding)
                }
                .frame(maxHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(ProviderListMetrics.errorCardPadding)
        .background(
            RoundedRectangle(cornerRadius: ProviderListMetrics.errorCardCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.03)))
    }
}
