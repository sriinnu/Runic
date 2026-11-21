import RunicCore
import SwiftUI

@MainActor
struct AppearancePane: View {
    @Environment(\.runicFonts) private var fonts
    @Environment(\.runicTheme) private var runicTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    private let themeColumns = [
        GridItem(.flexible(), spacing: RunicSpacing.xs),
        GridItem(.flexible(), spacing: RunicSpacing.xs),
        GridItem(.flexible(), spacing: RunicSpacing.xs),
    ]

    var body: some View {
        LiquidPreferencesPane {
            SettingsGroupCard(
                title: "Theme",
                caption: "Custom skins re-compose Runic's menu popover and settings panels; System/Dark follow macOS.")
            {
                AppearancePreviewCard(
                    theme: self.settings.theme,
                    fontFamily: self.settings.selectedFontFamily,
                    providers: Array(self.store.enabledProviders().prefix(4)))

                let systemThemes = Theme.allCases.filter { !$0.palette.isCustom }
                let customThemes = Theme.allCases.filter(\.palette.isCustom)

                if !systemThemes.isEmpty {
                    Text("Adaptive & System")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    LazyVGrid(columns: self.themeColumns, alignment: .leading, spacing: RunicSpacing.xs) {
                        ForEach(systemThemes) { theme in
                            ThemeChoiceButton(theme: theme, isSelected: self.settings.theme == theme) {
                                withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                                    self.settings.theme = theme
                                }
                            }
                        }
                    }
                }

                if !customThemes.isEmpty {
                    Text("Skins & Instruments")
                        .font(self.fonts.caption.weight(.semibold))
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                        .padding(.top, RunicSpacing.xxs)
                    LazyVGrid(columns: self.themeColumns, alignment: .leading, spacing: RunicSpacing.xs) {
                        ForEach(customThemes) { theme in
                            ThemeChoiceButton(theme: theme, isSelected: self.settings.theme == theme) {
                                withAnimation(self.runicTheme.motion.curve(reduceMotion: self.reduceMotion)) {
                                    self.settings.theme = theme
                                }
                            }
                        }
                    }
                }
            }

            SettingsGroupCard(title: "Typography") {
                let themeFont = RunicFontChoice.resolvedThemeFamily(
                    self.settings.theme.palette.style.typography.bodyFamily)
                let followsTheme = self.settings.selectedFontFamily == RunicFontChoice.themeDefaultID

                HStack {
                    Text("Font family")
                        .font(self.fonts.callout.weight(.medium))
                    Spacer()
                    Picker("", selection: self.$settings.selectedFontFamily) {
                        ForEach(RunicFontChoice.availableChoices()) { choice in
                            Text(choice.displayName)
                                .font(choice.previewFont)
                                .tag(choice.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 260)
                }

                Text(
                    "\"Theme default\" follows each skin's curated face; pick any bundled or " +
                        "curated system family above to override it.")
                    .font(self.fonts.footnote)
                    .foregroundStyle(self.runicTheme.subduedSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if followsTheme, let themeFont {
                    Text("\(self.settings.theme.label) uses \(RunicFontChoice.displayName(for: themeFont)).")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }

                TypographyRulesPreview(
                    fontFamily: self.settings.selectedFontFamily,
                    theme: self.settings.theme)
            }

            SettingsGroupCard(title: "Menu Bar & Popover Display") {
                self.menuModePicker
                self.usageMetricsPicker

                PreferenceToggleRow(
                    title: "Show usage as used",
                    subtitle: "Progress bars fill as you consume quota (instead of showing remaining).",
                    binding: self.$settings.usageBarsShowUsed)

                PreferenceToggleRow(
                    title: "Show credit + extra usage sections",
                    subtitle: "Show detailed credit and extra-usage sections in every menu mode. " +
                        "Balances and on-demand spend stay in usage.",
                    binding: self.$settings.showOptionalCreditsAndExtraUsage)

                PreferenceToggleRow(
                    title: "Merge Icons",
                    subtitle: "Use a single menu bar icon with a provider switcher.",
                    binding: self.$settings.mergeIcons)

                self.providerSwitcherLayoutPicker
                self.providerSwitcherIconSizePicker

                PreferenceToggleRow(
                    title: "Switcher shows icons",
                    subtitle: "Show provider icons in the switcher (otherwise show a weekly progress line).",
                    binding: self.$settings.switcherShowsIcons)
                    .disabled(!self.settings.mergeIcons || self.settings.providerSwitcherLayout == .sidebar)
                    .opacity(self.settings.mergeIcons && self.settings.providerSwitcherLayout != .sidebar ? 1 : 0.5)

                PreferenceToggleRow(
                    title: "Menu bar shows percent",
                    subtitle: "Replace critter bars with provider branding icons and a percentage.",
                    binding: self.$settings.menuBarShowsBrandIconWithPercent)

                PreferenceToggleRow(
                    title: "Vibrant menu bar icon",
                    subtitle: "Shows usage pressure in the menu bar.",
                    binding: self.$settings.menuBarVibrantIconEnabled)

                PreferenceToggleRow(
                    title: "Surprise me",
                    subtitle: "Check if you like your agents having some fun up there.",
                    binding: self.$settings.randomBlinkEnabled)
            }

            SettingsGroupCard(title: "Charts & Formats") {
                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Chart style")
                        .font(self.fonts.callout.weight(.medium))
                    RunicSegmentedPicker(
                        selection: self.$settings.chartStyle,
                        options: [(ChartStyle.line, "Line"), (ChartStyle.area, "Area"), (ChartStyle.bar, "Bar")])
                        .frame(maxWidth: 320)
                    Text("Timeline charts can render as a line, filled area, or bars.")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Number format")
                        .font(self.fonts.callout.weight(.medium))
                    RunicSegmentedPicker(
                        selection: self.$settings.numberFormat,
                        options: [
                            (NumberFormat.abbreviated, "Abbreviated"),
                            (NumberFormat.full, "Full"),
                        ])
                        .frame(maxWidth: 320)
                    Text("Example: Abbreviated (45.2K) vs Full (45,234).")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }

                VStack(alignment: .leading, spacing: RunicSpacing.xs) {
                    Text("Date format")
                        .font(self.fonts.callout.weight(.medium))
                    RunicSegmentedPicker(
                        selection: self.$settings.dateFormat,
                        options: [
                            (DateFormat.relative, "Relative"),
                            (DateFormat.absolute, "Absolute"),
                        ])
                        .frame(maxWidth: 320)
                    Text("Example: Relative (2h ago) vs Absolute (Jan 31, 2:30 PM).")
                        .font(self.fonts.footnote)
                        .foregroundStyle(self.runicTheme.subduedSecondaryText)
                }
            }
        }
    }

    private var usageMetricsPicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Usage metrics")
                .font(self.fonts.callout.weight(.medium))
            RunicSegmentedPicker(
                selection: self.$settings.usageMetricDisplayMode,
                cases: UsageMetricDisplayMode.allCases,
                label: \.label)
            Text("Pick bars, percent, or both in the menu card.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var menuModePicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Menu mode")
                .font(self.fonts.callout.weight(.medium))
            RunicSegmentedPicker(selection: self.$settings.menuMode, cases: MenuMode.allCases, label: \.label)
            Text(
                "Glance: usage and optional credits/extra usage. " +
                    "Analyst: adds token cost. Operator: insights and actions.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var providerSwitcherLayoutPicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Provider switcher layout")
                .font(self.fonts.callout.weight(.medium))
            RunicSegmentedPicker(
                selection: self.$settings.providerSwitcherLayout,
                cases: ProviderSwitcherLayout.allCases,
                label: \.label)
                .disabled(!self.settings.mergeIcons)
                .opacity(self.settings.mergeIcons ? 1 : 0.5)
            Text("Choose whether providers appear on top or in a left sidebar.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var providerSwitcherIconSizePicker: some View {
        VStack(alignment: .leading, spacing: RunicSpacing.xs) {
            Text("Switcher icon size")
                .font(self.fonts.callout.weight(.medium))
            RunicSegmentedPicker(
                selection: self.$settings.providerSwitcherIconSize,
                cases: ProviderSwitcherIconSize.allCases,
                label: \.label)
                .disabled(!self.settings.mergeIcons)
                .opacity(self.settings.mergeIcons ? 1 : 0.5)
            Text("Small or medium icons for the provider switcher.")
                .font(self.fonts.footnote)
                .foregroundStyle(self.runicTheme.subduedSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
