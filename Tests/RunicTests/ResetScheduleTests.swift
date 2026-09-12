import Foundation
import RunicCore
import Testing
@testable import Runic

struct ResetScheduleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func `relative reset phrases parse into dates`() {
        let base = self.now
        func parsed(_ text: String) -> Date? {
            UsageResetParsing.date(fromRelative: text, now: base)
        }
        #expect(parsed("resets in 3h 12m") == base.addingTimeInterval(3 * 3600 + 12 * 60))
        #expect(parsed("in 2d 4h") == base.addingTimeInterval(2 * 86400 + 4 * 3600))
        #expect(parsed("Resets in 45m") == base.addingTimeInterval(45 * 60))
        #expect(parsed("resets in 2 hours 5 minutes") == base.addingTimeInterval(2 * 3600 + 5 * 60))
    }

    @Test
    func `non reset phrases stay nil`() {
        #expect(UsageResetParsing.date(fromRelative: "Balance: $12.40 · Spent: $3.10", now: self.now) == nil)
        #expect(UsageResetParsing.date(fromRelative: "1,200 / 5,000 remaining", now: self.now) == nil)
        #expect(UsageResetParsing.date(fromRelative: "Monthly", now: self.now) == nil)
        #expect(UsageResetParsing.date(fromRelative: "Models: 12 (gpt-5, claude)", now: self.now) == nil)
        #expect(UsageResetParsing.date(fromRelative: nil, now: self.now) == nil)
        #expect(UsageResetParsing.date(fromRelative: "", now: self.now) == nil)
    }

    @Test
    func `expiry string picks today tomorrow weekday or date`() throws {
        let calendar = Calendar.current
        let today = try #require(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: self.now))
        let inTwoHours = today.addingTimeInterval(2 * 3600)
        #expect(!UsageFormatter.resetExpiryString(from: inTwoHours, now: today).contains("tomorrow"))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        #expect(UsageFormatter.resetExpiryString(from: tomorrow, now: today).hasPrefix("tomorrow "))
        let inThreeDays = try #require(calendar.date(byAdding: .day, value: 3, to: today))
        let weekday = inThreeDays.formatted(.dateTime.weekday(.abbreviated))
        #expect(UsageFormatter.resetExpiryString(from: inThreeDays, now: today).hasPrefix(weekday))
        let inTwoWeeks = try #require(calendar.date(byAdding: .day, value: 14, to: today))
        let dated = UsageFormatter.resetExpiryString(from: inTwoWeeks, now: today)
        #expect(!dated.hasPrefix("tomorrow"))
        #expect(dated.contains(inTwoWeeks.formatted(.dateTime.month(.abbreviated))))
    }

    @Test
    func `reset summary carries countdown and expiry`() {
        let window = RateWindow(
            usedPercent: 40,
            windowMinutes: 300,
            resetsAt: self.now.addingTimeInterval(2 * 3600 + 14 * 60),
            resetDescription: nil)
        let summary = UsageFormatter.resetSummary(for: window, now: self.now)
        #expect(summary?.hasPrefix("Resets in 2h 14m · ") == true)

        let phraseOnly = RateWindow(
            usedPercent: 10,
            windowMinutes: nil,
            resetsAt: nil,
            resetDescription: "resets in 30m")
        let phraseSummary = UsageFormatter.resetSummary(for: phraseOnly, now: self.now)
        #expect(phraseSummary?.hasPrefix("Resets in 30m · ") == true)

        let balance = RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: "Balance: $4.00")
        #expect(UsageFormatter.resetSummary(for: balance, now: self.now) == "Balance: $4.00")
    }

    @MainActor
    @Test
    func `schedule builder keeps reset shaped windows soonest first`() {
        let claudeMeta = ProviderDescriptorRegistry.descriptor(for: .claude).metadata
        let codexMeta = ProviderDescriptorRegistry.descriptor(for: .codex).metadata
        let xaiMeta = ProviderDescriptorRegistry.descriptor(for: .xai).metadata

        let claude = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 62,
                windowMinutes: 300,
                resetsAt: self.now.addingTimeInterval(3 * 3600),
                resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 20,
                windowMinutes: 10080,
                resetsAt: self.now.addingTimeInterval(3 * 86400),
                resetDescription: nil),
            updatedAt: self.now)
        let codex = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 100,
                windowMinutes: 300,
                resetsAt: self.now.addingTimeInterval(20 * 60),
                resetDescription: nil),
            secondary: nil,
            updatedAt: self.now)
        let xai = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Balance: $12.00",
                hasKnownLimit: false),
            secondary: nil,
            updatedAt: self.now)

        let entries = ResetScheduleBuilder.entries([
            .init(provider: .claude, metadata: claudeMeta, snapshot: claude),
            .init(provider: .codex, metadata: codexMeta, snapshot: codex),
            .init(provider: .xai, metadata: xaiMeta, snapshot: xai),
        ], now: self.now)

        #expect(entries.map(\.id) == ["codex-primary", "claude-primary", "claude-secondary"])
        #expect(entries.first?.isExhausted == true)
        #expect(entries[1].remainingPercent == 38)
        #expect(entries[1].windowTitle == claudeMeta.sessionLabel)
        #expect(entries[2].windowTitle == claudeMeta.weeklyLabel)

        let elapsed = entries[1].elapsedFraction(now: self.now)
        #expect(elapsed != nil)
        #expect(abs((elapsed ?? 0) - 0.4) < 0.001)
        #expect(entries[2].elapsedFraction(now: self.now).map { abs($0 - (4.0 / 7.0)) < 0.001 } == true)
    }

    @MainActor
    @Test
    func `schedule builder uses window labels and parses phrases`() {
        let geminiMeta = ProviderDescriptorRegistry.descriptor(for: .gemini).metadata
        let gemini = UsageSnapshot(
            primary: RateWindow(
                usedPercent: 30,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "resets in 1h 30m",
                label: "gemini-3-pro"),
            secondary: RateWindow(
                usedPercent: 5,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: "Monthly"),
            updatedAt: self.now)
        let entries = ResetScheduleBuilder.entries(
            [.init(provider: .gemini, metadata: geminiMeta, snapshot: gemini)],
            now: self.now)
        #expect(entries.count == 2)
        #expect(entries[0].resetsAt == self.now.addingTimeInterval(90 * 60))
        #expect(entries[0].windowTitle == UsageFormatter.modelDisplayName("gemini-3-pro"))
        #expect(entries[1].resetsAt == nil)
        #expect(entries[1].fallbackText == "Monthly")
    }

    @Test
    func `compact duration formats`() {
        #expect(ResetScheduleMenuView.compactDuration(90) == "2m")
        #expect(ResetScheduleMenuView.compactDuration(3600) == "1h")
        #expect(ResetScheduleMenuView.compactDuration(3600 * 2 + 60 * 14) == "2h 14m")
        #expect(ResetScheduleMenuView.compactDuration(86400 * 3 + 3600 * 5) == "3d 5h")
        #expect(ResetScheduleMenuView.compactDuration(86400 * 2) == "2d")
    }
}

struct ThemeMigrationTests {
    @Test
    func `retired themes land on their nearest living theme`() {
        #expect(Theme.migrated(fromRetired: "light") == .sumi)
        #expect(Theme.migrated(fromRetired: "daybreak") == .sumi)
        #expect(Theme.migrated(fromRetired: "nocturne") == .blueprint)
        #expect(Theme.migrated(fromRetired: "noir") == .blueprint)
        #expect(Theme.migrated(fromRetired: "prism") == .glass)
        #expect(Theme.migrated(fromRetired: "pine") == .default)
        for raw in Theme.retiredRawValues {
            #expect(Theme(rawValue: raw) == nil, "\(raw) must not still be a live theme")
        }
        #expect(Theme(rawValue: "sumi") == .sumi)
        #expect(Theme(rawValue: "blueprint") == .blueprint)
        #expect(Theme(rawValue: "relief") == .relief)
        let relief = Theme.relief.palette
        #expect(relief.isElevated)
        #expect(!Theme.dark.palette.isElevated)
        #expect(relief.style.effects.elevation == 1.0)
        #expect(relief.style.controls.progressStyle == .flatBar)
        #expect(relief.density.paddingMultiplier > 1)
    }

    @MainActor
    @Test
    func `sumi and blueprint carry their structural identity`() {
        let sumi = Theme.sumi.palette
        let blueprint = Theme.blueprint.palette

        #expect(sumi.shape.separator == .brush)
        #expect(sumi.style.effects.texture == .paper)
        #expect(sumi.hasSurfaceTexture)
        #expect(sumi.style.chrome.borderStyle == .ink)
        #expect(sumi.style.controls.progressStyle == .flatBar)
        #expect(sumi.prefersDarkAppearance == false)
        #expect(sumi.prefersRetroToggleChrome, "opinionated themes own their checkbox chrome")

        #expect(blueprint.style.effects.texture == .grid)
        #expect(blueprint.hasSurfaceTexture)
        #expect(blueprint.style.controls.progressStyle == .flatBar)
        #expect(blueprint.style.typography.numericFamily == RunicFontChoice.geistMono.id)
        #expect(blueprint.prefersDarkAppearance == true)
        let darkRadius = Theme.dark.palette.shape.cornerRadius(RunicCornerRadius.lg)
        #expect(blueprint.shape.cornerRadius(RunicCornerRadius.lg) < darkRadius)
    }

    @MainActor
    @Test
    func `kirigami carries its paper craft identity`() {
        let kirigami = Theme.kirigami.palette

        #expect(Theme(rawValue: "kirigami") == .kirigami)
        #expect(kirigami.isPaperCutout)
        #expect(kirigami.style.chrome.borderStyle == .cutout)
        #expect(kirigami.shape.separator == .stitch)
        #expect(kirigami.style.effects.texture == .hatch)
        #expect(kirigami.hasSurfaceTexture)
        #expect(kirigami.style.controls.progressStyle == .pipe)
        #expect(kirigami.wantsChartPipeLip)
        #expect(!Theme.sumi.palette.wantsChartPipeLip)
        #expect(kirigami.style.typography.displayFamily == RunicFontChoice.patrickHand.id)
        #expect(kirigami.style.typography.numericFamily == RunicFontChoice.geistMono.id)
        #expect(kirigami.prefersDarkAppearance == false)
        #expect(kirigami.prefersRetroToggleChrome, "paper pill switches are theme-owned")
        #expect(!kirigami.isElevated, "cut-out shadows are hard offsets, not the elevation system")
    }

    @MainActor
    @Test
    func `display face resolves for kirigami and stays out of the body picker`() {
        let store = RunicFontStore()
        store.applyTheme(Theme.kirigami.palette)
        #expect(store.hasDisplayFace, "Patrick Hand is bundled, so the display face must resolve")
        #expect(store.themeDisplayFamilyOverride == RunicFontChoice.patrickHand.id)
        #expect(store.themeFamilyOverride == RunicFontChoice.nunito.id, "Kirigami locks its rounded body face")
        #expect(RunicFontChoice.availableChoices().contains { $0.id == RunicFontChoice.nunito.id })
        #expect(store.themeNumericFamilyOverride == RunicFontChoice.geistMono.id)
        #expect(!RunicFontChoice.availableChoices().contains { $0.id == RunicFontChoice.patrickHand.id })

        store.applyTheme(Theme.sumi.palette)
        #expect(!store.hasDisplayFace)
        #expect(RunicFontChoice.resolvedDisplayFamily("No Such Family 123") == nil)
    }

    @MainActor
    @Test
    func `theme JSON decodes paper craft tokens`() throws {
        let json = """
        {
          "id": "probe2", "displayName": "Probe", "tagline": "t", "symbolName": "circle",
          "isCustom": true, "prefersDarkAppearance": false,
          "colors": {
            "primary": "#000000", "secondary": "#000000", "accent": "#FF0000", "highlight": "#FFFF00",
            "warm": "#FF0000", "tertiary": "#333333", "surface": "#FFFFFF", "surfaceAlt": "#EEEEEE",
            "cardFill": "#FFFFFF", "cardStroke": "#000000", "primaryText": "#000000", "secondaryText": "#333333"
          },
          "fonts": { "body": "system", "numeric": "mono" },
          "shape": { "cornerMultiplier": 1.1, "separator": "stitch" },
          "motion": { "preset": "snappy" },
          "density": { "preset": "normal" },
          "style": {
            "typography": { "displayFamily": "Patrick Hand" },
            "chrome": { "borderStyle": "cutout" },
            "effects": { "texture": "hatch", "textureOpacity": 0.5 },
            "controls": { "progressStyle": "pipe" }
          }
        }
        """
        let palette = try JSONDecoder().decode(RunicThemeJSON.self, from: Data(json.utf8)).toPalette()
        #expect(palette.shape.separator == .stitch)
        #expect(palette.style.chrome.borderStyle == .cutout)
        #expect(palette.style.effects.texture == .hatch)
        #expect(palette.style.controls.progressStyle == .pipe)
        #expect(palette.style.typography.displayFamily == "Patrick Hand")
        #expect(palette.isPaperCutout)
        #expect(Theme.dark.palette.style.typography.displayFamily == nil)
    }

    @MainActor
    @Test
    func `theme JSON decodes texture separator and chart series tokens`() throws {
        let json = """
        {
          "id": "probe", "displayName": "Probe", "tagline": "t", "symbolName": "circle",
          "isCustom": true, "prefersDarkAppearance": true,
          "colors": {
            "primary": "#FFFFFF", "secondary": "#FFFFFF", "accent": "#FF0000", "highlight": "#FFFF00",
            "warm": "#FF0000", "tertiary": "#CCCCCC", "surface": "#000000", "surfaceAlt": "#111111",
            "cardFill": "#FFFFFF10", "cardStroke": "#FFFFFF80", "primaryText": "#FFFFFF", "secondaryText": "#CCCCCC"
          },
          "fonts": { "body": "system", "numeric": "tabular" },
          "shape": { "cornerMultiplier": 0.2, "separator": "rule" },
          "motion": { "preset": "standard" },
          "density": { "preset": "normal" },
          "style": {
            "chrome": { "borderStyle": "block" },
            "effects": { "texture": "grain", "textureOpacity": 0.4 },
            "controls": { "progressStyle": "flatBar", "chartSeries": "monochrome" }
          }
        }
        """
        let palette = try JSONDecoder().decode(RunicThemeJSON.self, from: Data(json.utf8)).toPalette()
        #expect(palette.shape.separator == .rule)
        #expect(palette.style.chrome.borderStyle == .block)
        #expect(palette.style.effects.texture == .grain)
        #expect(palette.style.effects.textureOpacity == 0.4)
        #expect(palette.style.controls.progressStyle == .flatBar)
        #expect(palette.style.controls.chartSeries == .monochrome)
        // Defaults survive when the keys are absent.
        #expect(Theme.dark.palette.style.effects.texture == .none)
        #expect(Theme.dark.palette.style.controls.chartSeries == .themed)
        #expect(!Theme.dark.palette.hasSurfaceTexture)
    }
}
