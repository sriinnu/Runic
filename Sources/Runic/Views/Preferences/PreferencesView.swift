import AppKit
import SwiftUI

@MainActor
struct PreferencesView: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore
    let updater: UpdaterProviding
    @Bindable var selection: PreferencesSelection

    @State private var providersSection: ProvidersSubSection = .builtIn

    enum ProvidersSubSection: String, CaseIterable, Identifiable {
        case builtIn
        case custom

        var id: String {
            self.rawValue
        }

        var label: String {
            switch self {
            case .builtIn: "Built-in"
            case .custom: "Custom"
            }
        }
    }

    var body: some View {
        let palette = self.settings.theme.palette
        HStack(spacing: 0) {
            self.sidebarRail(palette: palette)

            Rectangle()
                .fill(palette.menuSeparatorColor.opacity(0.65))
                .frame(width: 1)

            self.content(for: self.selection.tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .runicTypography()
        .environment(\.runicTheme, palette)
        .environment(\.runicSkin, RunicSkinRegistry.skin(for: palette))
        .runicColorScheme(palette)
        .foregroundStyle(palette.primaryText)
        .tint(palette.accent)
        .background {
            ZStack {
                palette.surface
                LiquidMeshBackground()
                    .opacity(self.meshBackgroundOpacity(for: palette))
                if palette.hasSurfaceTexture {
                    RunicSurfaceTextureOverlay()
                        .environment(\.runicTheme, palette)
                }
            }
            .ignoresSafeArea()
        }
        .frame(
            minWidth: 740,
            idealWidth: PreferencesTab.windowWidth,
            maxWidth: 1120,
            minHeight: 600,
            idealHeight: PreferencesTab.windowHeight,
            maxHeight: .infinity,
            alignment: .topLeading)
        .onAppear {
            self.ensureValidTabSelection()
            self.routeInitialProviderIfNeeded()
        }
        .onChange(of: self.selection.provider) { _, _ in
            self.routeInitialProviderIfNeeded()
        }
        .onChange(of: self.settings.debugMenuEnabled) { _, _ in
            self.ensureValidTabSelection()
        }
    }

    private var visibleTabs: [PreferencesTab] {
        PreferencesTab.allCases.filter { self.settings.debugMenuEnabled || $0 != .debug }
    }

    private func sidebarRail(palette: RunicThemePalette) -> some View {
        VStack(alignment: .leading, spacing: RunicSpacing.md) {
            HStack(spacing: RunicSpacing.xs) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(
                            cornerRadius: palette.shape.cornerRadius(6),
                            style: .continuous))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Runic")
                        .font(self.fonts.headline.weight(.bold))
                        .foregroundStyle(palette.primaryText)
                    Text("Settings")
                        .font(self.fonts.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .padding(.horizontal, RunicSpacing.sm)
            .padding(.top, RunicSpacing.md)

            VStack(alignment: .leading, spacing: RunicSpacing.xxxs) {
                ForEach(self.visibleTabs) { tab in
                    self.sidebarRow(tab, palette: palette)
                }
            }
            .padding(.horizontal, RunicSpacing.xs)

            Spacer(minLength: 0)
        }
        .frame(width: PreferencesLayoutMetrics.sidebarRailWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surfaceAlt.opacity(palette.isTerminalHUD ? 0.62 : 0.72))
    }

    private func sidebarRow(_ tab: PreferencesTab, palette: RunicThemePalette) -> some View {
        let isSelected = self.selection.tab == tab
        return Button {
            withAnimation(palette.motion.curve(reduceMotion: self.reduceMotion)) {
                self.selection.tab = tab
            }
        } label: {
            HStack(spacing: RunicSpacing.xs) {
                RunicThemedSystemIcon(
                    systemName: tab.symbolName,
                    intent: tab.iconIntent,
                    selected: isSelected,
                    font: self.fonts.callout.weight(isSelected ? .semibold : .medium),
                    width: 18)
                Text(tab.label)
                    .font(self.fonts.callout.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, RunicSpacing.xs)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
            .background(
                RoundedRectangle(cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                    .fill(isSelected ? palette.accent.opacity(palette.isTerminalHUD ? 0.22 : 0.14) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: palette.shape.cornerRadius(RunicCornerRadius.sm), style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.accent.opacity(0.48) : Color.clear,
                        lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func content(for tab: PreferencesTab) -> some View {
        switch tab {
        case .general:
            GeneralPane(settings: self.settings, store: self.store)
        case .appearance:
            AppearancePane(settings: self.settings, store: self.store)
        case .providers:
            VStack(spacing: 0) {
                HStack(spacing: RunicSpacing.xs) {
                    RunicSegmentedPicker(
                        selection: self.$providersSection,
                        cases: ProvidersSubSection.allCases,
                        label: \.label)

                    if self.providersSection == .builtIn {
                        RunicSegmentedPicker(
                            selection: self.$settings.providersPaneSidebar,
                            options: [(false, "List"), (true, "Sidebar")])
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, PreferencesLayoutMetrics.paneHorizontal)
                .padding(.top, RunicSpacing.md)
                .padding(.bottom, RunicSpacing.xs)

                switch self.providersSection {
                case .builtIn:
                    ProvidersPane(
                        settings: self.settings,
                        store: self.store,
                        initialProvider: self.selection.provider,
                        onConsumeInitialProvider: { self.selection.provider = nil })
                case .custom:
                    CustomProvidersPane(settings: self.settings, store: self.store)
                }
            }
        case .analytics:
            AnalyticsPane(settings: self.settings, store: self.store)
        case .sync:
            SyncPane(settings: self.settings, store: self.store)
        case .performance:
            PerformancePane(
                settings: self.settings,
                store: self.store,
                onSelectProvider: { provider in
                    self.selection.openProvider(provider)
                })
        case .about:
            AboutPane(settings: self.settings, updater: self.updater)
        case .debug:
            DebugPane(settings: self.settings, store: self.store)
        }
    }

    private func meshBackgroundOpacity(for palette: RunicThemePalette) -> Double {
        if palette.isTerminalHUD { return 0.9 }
        return palette.isCustom ? 0.28 : 0.10
    }

    private func routeInitialProviderIfNeeded() {
        guard self.selection.provider != nil else { return }
        self.providersSection = .builtIn
    }

    private func ensureValidTabSelection() {
        if !self.settings.debugMenuEnabled, self.selection.tab == .debug {
            self.selection.tab = .general
        }
    }
}

extension PreferencesTab {
    var label: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .providers: "Providers"
        case .analytics: "Insights & Budgets"
        case .sync: "Integrations"
        case .performance: "Storage & Health"
        case .about: "About"
        case .debug: "Debug"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush.pointed"
        case .providers: "cpu"
        case .analytics: "chart.bar.xaxis"
        case .sync: "link"
        case .performance: "internaldrive"
        case .about: "info.circle"
        case .debug: "ant"
        }
    }

    var iconIntent: RunicIconIntent {
        .navigation
    }
}
