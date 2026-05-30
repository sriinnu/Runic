import AppKit
import Foundation
import RunicCore
import SwiftUI
import Testing
@testable import Runic

struct RunicTests {
    @Test
    func `icon renderer produces template image`() {
        let image = IconRenderer.makeIcon(
            primaryRemaining: 50,
            weeklyRemaining: 75,
            creditsRemaining: 500,
            stale: false,
            style: .codex)
        #expect(image.isTemplate)
        #expect(image.size.width > 0)
    }

    @Test
    func `timeline ranges expose matching scan horizons`() {
        #expect(UsageTimelineChartMenuView.TimeRange.threeDays.days == 3)
        #expect(UsageTimelineChartMenuView.TimeRange.sevenDays.days == 7)
        #expect(UsageTimelineChartMenuView.TimeRange.thirtyDays.days == 30)
        #expect(UsageTimelineChartMenuView.TimeRange.quarter.days == 90)
        #expect(UsageTimelineChartMenuView.TimeRange.year.days == 365)
    }

    @Test
    func `icon renderer renders at pixel aligned size`() {
        let image = IconRenderer.makeIcon(
            primaryRemaining: 50,
            weeklyRemaining: 75,
            creditsRemaining: 500,
            stale: false,
            style: .claude)
        let bitmapReps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        #expect(!bitmapReps.isEmpty)
        #expect(bitmapReps.contains { rep in rep.pixelsWide > 0 && rep.pixelsHigh > 0 })
    }

    @Test
    func `icon renderer caches static icons`() {
        let first = IconRenderer.makeIcon(
            primaryRemaining: 42,
            weeklyRemaining: 17,
            creditsRemaining: 250,
            stale: false,
            style: .codex)
        let second = IconRenderer.makeIcon(
            primaryRemaining: 42,
            weeklyRemaining: 17,
            creditsRemaining: 250,
            stale: false,
            style: .codex)
        #expect(first === second)
    }

    @Test
    func `icon renderer codex eyes punch through when unknown`() {
        // Regression guard: icon should preserve transparent + opaque pixels.
        let image = IconRenderer.makeIcon(
            primaryRemaining: nil,
            weeklyRemaining: 1,
            creditsRemaining: nil,
            stale: false,
            style: .codex)

        let bitmapReps = image.representations.compactMap { $0 as? NSBitmapImageRep }
        let rep = bitmapReps.max { lhs, rhs in lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh }
        #expect(rep != nil)
        guard let rep else { return }

        func alphaAt(px x: Int, _ y: Int) -> CGFloat {
            (rep.colorAt(x: x, y: y) ?? .clear).alphaComponent
        }

        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        var transparentPixels = 0
        for y in 0..<h {
            for x in 0..<w where alphaAt(px: x, y) < 0.05 {
                transparentPixels += 1
            }
        }

        #expect(w > 0 && h > 0)
        #expect(transparentPixels > 0)
    }

    @MainActor
    @Test
    func `provider brand icons render as colorful plain marks`() {
        for provider in UsageProvider.allCases {
            let image = ProviderBrandIcon.image(for: provider, size: 20)

            #expect(image != nil, "Missing brand icon for \(provider.rawValue)")
            #expect(image?.isTemplate == false, "Brand icon must not be template-rendered for \(provider.rawValue)")
            #expect(image?.size == NSSize(width: 20, height: 20))
        }
    }

    @MainActor
    @Test
    func `preference tab icons stay navigation until selected`() {
        for tab in PreferencesTab.allCases {
            #expect(tab.iconIntent == .navigation, "\(tab.rawValue) should not receive semantic color while idle")
        }
    }

    @MainActor
    @Test
    func `menu action icon intents stay semantic`() {
        #expect(MenuDescriptor.MenuAction.dashboard.iconIntent == .data)
        #expect(MenuDescriptor.MenuAction.statusPage.iconIntent == .info)
        #expect(MenuDescriptor.MenuAction.about.iconIntent == .info)
        #expect(MenuDescriptor.MenuAction.quit.iconIntent == .destructive)
        #expect(MenuDescriptor.MenuAction.copyError("boom").iconIntent == .statusWarning)
        #expect(MenuDescriptor.MenuAction.installUpdate.iconIntent == .action)
        #expect(MenuDescriptor.MenuAction.refresh.iconIntent == .action)
        #expect(MenuDescriptor.MenuAction.settings.iconIntent == .action)
        #expect(MenuDescriptor.MenuAction.switchAccount(.codex).iconIntent == .action)
    }

    @MainActor
    @Test
    func `popover insight panel icons stay navigation`() {
        for panel in PopoverInsightPanel.allCases {
            #expect(panel.iconIntent == .navigation, "\(panel.rawValue) should scan like navigation")
        }
    }

    @MainActor
    @Test
    func `semantic icon colors keep non text contrast on themed surfaces`() {
        let semanticIntents: [RunicIconIntent] = [.data, .destructive, .info, .statusGood, .statusWarning]

        for theme in Theme.allCases {
            let palette = theme.palette
            for intent in semanticIntents {
                let color = palette.iconColor(for: intent)
                #expect(
                    self.contrast(color, against: palette.surface, palette: palette) >= 3.0,
                    "\(theme.rawValue) \(intent) should read on surface")
                #expect(
                    self.contrast(color, against: palette.menuSubtleFill, palette: palette) >= 3.0,
                    "\(theme.rawValue) \(intent) should read on subtle panel fill")
            }
        }
    }

    @MainActor
    @Test
    func `selected icon colors keep contrast against selected fills`() {
        for theme in Theme.allCases {
            let palette = theme.palette
            let selectedFill = self.selectedFill(for: palette)
            let selectedColor = palette.iconColor(for: .navigation, selected: true)
            #expect(
                self.contrast(selectedColor, against: selectedFill, palette: palette) >= 3.0,
                "\(theme.rawValue) selected icon should read over selected fill")
        }
    }

    @MainActor
    @Test
    func `icon colors keep contrast on actual menu control fills`() {
        for theme in Theme.allCases {
            let palette = theme.palette
            let selectedIcon = palette.iconColor(for: .navigation, selected: true)
            let hoveredIcon = palette.iconColor(for: .navigation, hovered: true)

            #expect(
                self.contrast(selectedIcon, against: self.providerTabSelectedFill(for: palette), palette: palette) >= 3.0,
                "\(theme.rawValue) selected provider tab icon should read over selected tab fill")
            #expect(
                self.contrast(hoveredIcon, against: self.popoverChipHoverFill(for: palette), palette: palette) >= 3.0,
                "\(theme.rawValue) hovered chip icon should read over chip hover fill")
            #expect(
                self.contrast(hoveredIcon, against: self.popoverActionHoverFill(for: palette), palette: palette) >= 3.0,
                "\(theme.rawValue) hovered action icon should read over action hover fill")
        }
    }

    private func selectedFill(for palette: RunicThemePalette) -> Color {
        switch palette.style.controls.selectedFillStyle {
        case .accentSolid, .terminalSolid:
            palette.accent.opacity(palette.isTerminalHUD ? 0.28 : 0.22)
        case .neutralSoft:
            palette.menuSubtleFill
        case .accentSoft:
            palette.accent.opacity(0.18)
        }
    }

    private func providerTabSelectedFill(for palette: RunicThemePalette) -> Color {
        if palette.isTerminalHUD {
            return palette.accent.opacity(0.22)
        }
        if palette.shape.separator == .glow {
            return palette.accent.opacity(0.30)
        }
        return palette.accent.opacity(RunicColors.Opacity.medium)
    }

    private func popoverChipHoverFill(for palette: RunicThemePalette) -> Color {
        if palette.isTerminalHUD {
            return palette.accent.opacity(0.16)
        }
        if palette.shape.separator == .glow {
            return palette.accent.opacity(0.24)
        }
        return palette.accent.opacity(0.14)
    }

    private func popoverActionHoverFill(for palette: RunicThemePalette) -> Color {
        if palette.isTerminalHUD {
            return palette.accent.opacity(0.16)
        }
        if palette.shape.separator == .glow {
            return palette.accent.opacity(0.22)
        }
        return palette.menuHoverFill
    }

    private func contrast(_ foreground: Color, against background: Color, palette: RunicThemePalette) -> Double {
        let surface = self.opaqueRGB(palette.nsColor(palette.surface, fallback: .windowBackgroundColor))
        let resolvedBackground = self.composite(
            self.rgba(palette.nsColor(background, fallback: .windowBackgroundColor)),
            over: surface)
        let resolvedForeground = self.composite(
            self.rgba(palette.nsColor(foreground, fallback: .controlAccentColor)),
            over: resolvedBackground)
        return self.contrast(resolvedForeground, resolvedBackground)
    }

    private func contrast(_ lhs: RGB, _ rhs: RGB) -> Double {
        let l1 = self.luminance(lhs)
        let l2 = self.luminance(rhs)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    private func luminance(_ color: RGB) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b)
    }

    private func composite(_ foreground: RGBA, over background: RGB) -> RGB {
        RGB(
            r: foreground.r * foreground.a + background.r * (1 - foreground.a),
            g: foreground.g * foreground.a + background.g * (1 - foreground.a),
            b: foreground.b * foreground.a + background.b * (1 - foreground.a))
    }

    private func opaqueRGB(_ color: NSColor) -> RGB {
        let rgba = self.rgba(color)
        return RGB(r: rgba.r, g: rgba.g, b: rgba.b)
    }

    private func rgba(_ color: NSColor) -> RGBA {
        let resolved = color.usingColorSpace(.deviceRGB) ?? color
        return RGBA(
            r: Double(resolved.redComponent),
            g: Double(resolved.greenComponent),
            b: Double(resolved.blueComponent),
            a: Double(resolved.alphaComponent))
    }

    private struct RGB {
        let r: Double
        let g: Double
        let b: Double
    }

    private struct RGBA {
        let r: Double
        let g: Double
        let b: Double
        let a: Double
    }

    @MainActor
    @Test
    func `bundled font families resolve to real font names`() {
        RunicTypography.registerFonts()

        let mona = RunicTypography.fontName(for: RunicFontChoice.monaSans.id)
        let commit = RunicTypography.fontName(for: RunicFontChoice.commitMono.id)

        #expect(mona == "MonaSans-Regular")
        #expect(commit == "CommitMono-Regular")
        #expect(NSFont(name: mona, size: 13) != nil)
        #expect(NSFont(name: commit, size: 13) != nil)
    }

    @MainActor
    @Test
    func `font picker exposes curated families and hides pruned fonts`() {
        RunicTypography.registerFonts()

        let ids = Set(RunicFontChoice.availableChoices().map(\.id))

        #expect(ids.contains(RunicFontChoice.monaSans.id))
        #expect(ids.contains(RunicFontChoice.commitMono.id))
        #expect(ids.contains(RunicFontChoice.geist.id))
        #expect(ids.contains(RunicFontChoice.geistMono.id))
        if RunicTypography.discoverBundledFontFamilies().contains(RunicFontChoice.berkeleyMono.id) {
            #expect(ids.contains(RunicFontChoice.berkeleyMono.id))
        }
        if RunicTypography.discoverBundledFontFamilies().contains(RunicFontChoice.operatorMono.id) {
            #expect(ids.contains(RunicFontChoice.operatorMono.id))
        }
        if NSFontManager.shared.availableMembers(ofFontFamily: RunicFontChoice.tx02.id)?.isEmpty == false {
            #expect(ids.contains(RunicFontChoice.tx02.id))
        }
        #expect(!ids.contains("Fira Code"))
        #expect(!ids.contains("JetBrains Mono"))
        #expect(!ids.contains(where: { id in
            let normalized = id.lowercased()
            let compact = normalized.replacingOccurrences(of: " ", with: "")
            return compact.contains("jetbrainsmono") && normalized.contains("nerd font")
        }))
        #expect(!ids.contains("IBM Plex Mono"))
        #expect(!ids.contains("Space Mono"))
        #expect(!ids.contains("VT323"))
    }

    @Test
    func `non curated saved fonts migrate to Mona Sans`() {
        #expect(RunicFontChoice.migratedFamily("Avenir Next") == RunicFontChoice.defaultFamily)
        #expect(RunicFontChoice.migratedFamily("Helvetica") == RunicFontChoice.defaultFamily)
    }

    @MainActor
    @Test
    func `licensed Berkeley and Operator faces are treated as curated mono faces when present`() {
        RunicTypography.registerFonts()

        let ids = Set(RunicFontChoice.availableChoices().map(\.id))
        let bundledFamilies = Set(RunicTypography.discoverBundledFontFamilies())
        let expectedChoices: [RunicFontChoice] = [
            .berkeleyMono,
            .tx02,
            .operatorMono,
        ]

        for choice in expectedChoices
            where bundledFamilies.contains(choice.id) ||
                NSFontManager.shared.availableMembers(ofFontFamily: choice.id)?.isEmpty == false
        {
            let rules = RunicFontRules.rules(for: choice.id)
            #expect(ids.contains(choice.id))
            #expect(rules.prefersMonospacedDigits)
        }

        #expect(RunicFontChoice.tx02.displayName == "TX-02 Berkeley Mono")
    }

    @MainActor
    @Test
    func `legacy theme JSON decodes with default style`() throws {
        let json = """
        {
          "id": "legacy-test",
          "displayName": "Legacy",
          "tagline": "Old file",
          "symbolName": "circle",
          "isCustom": false,
          "prefersDarkAppearance": false,
          "colors": {
            "primary": "#336BE6",
            "secondary": "#1A9EB8",
            "accent": "#2670EB",
            "highlight": "#E6781F",
            "warm": "#DB4761",
            "tertiary": "#219457",
            "surface": "#F5F7FA",
            "surfaceAlt": "#FFFFFFB8",
            "cardFill": "#FFFFFFA8",
            "cardStroke": "#0000001E",
            "primaryText": "#000000DB",
            "secondaryText": "#0000008C"
          },
          "fonts": { "body": "system", "numeric": "system" },
          "shape": { "preset": "standard" },
          "motion": { "preset": "standard" },
          "density": { "preset": "normal" }
        }
        """

        let dto = try JSONDecoder().decode(RunicThemeJSON.self, from: Data(json.utf8))
        let palette = dto.toPalette()

        #expect(palette.style.typography.scale == 1.0)
        #expect(palette.style.chrome.borderStyle == .hairline)
        #expect(palette.style.controls.progressStyle == .softBar)
    }

    @MainActor
    @Test
    func `rich theme JSON decodes style settings`() throws {
        let json = """
        {
          "id": "terminal-test",
          "displayName": "Terminal",
          "tagline": "HUD",
          "symbolName": "terminal.fill",
          "isCustom": true,
          "prefersDarkAppearance": true,
          "colors": {
            "primary": "#0DE37A",
            "secondary": "#2FC8E8",
            "accent": "#18F28B",
            "highlight": "#F8BA2E",
            "warm": "#F06773",
            "tertiary": "#55E3B8",
            "surface": "#020807",
            "surfaceAlt": "#031A13D9",
            "cardFill": "#05211799",
            "cardStroke": "#10D77A42",
            "primaryText": "#D7F7E5",
            "secondaryText": "#9CC8B2"
          },
          "fonts": { "body": "mono", "numeric": "mono" },
          "shape": { "cornerMultiplier": 0.62, "separator": "hairline" },
          "motion": { "preset": "instant" },
          "density": { "preset": "normal" },
          "style": {
            "typography": {
              "bodyFamily": "CommitMono",
              "numericFamily": "CommitMono",
              "scale": 0.98,
              "tracking": 0.03,
              "lineSpacing": 0.35,
              "contrast": "strong"
            },
            "chrome": {
              "borderStyle": "hud",
              "borderWeight": 0.75,
              "borderOpacity": 0.44,
              "cornerStyle": "compact",
              "panelDepth": "low"
            },
            "effects": {
              "scanlineOpacity": 0.32,
              "glowStrength": 0.16,
              "materialIntensity": 0.0
            },
            "controls": {
              "selectedFillStyle": "terminalSolid",
              "progressStyle": "segmentedHUD",
              "hoverStyle": "neutral"
            }
          }
        }
        """

        let dto = try JSONDecoder().decode(RunicThemeJSON.self, from: Data(json.utf8))
        let palette = dto.toPalette()

        #expect(palette.style.typography.bodyFamily == "CommitMono")
        #expect(palette.style.typography.lineSpacing == 0.35)
        #expect(palette.style.typography.contrast == .strong)
        #expect(palette.style.chrome.borderStyle == .hud)
        #expect(palette.style.effects.scanlineOpacity == 0.32)
        #expect(palette.style.controls.progressStyle == .segmentedHUD)
    }

    @MainActor
    @Test
    func `bundled theme JSON decodes every current theme`() throws {
        let themeDirs = RunicResourceLocator.directories(named: "Themes")
        var decodedIDs = Set<String>()

        for dir in themeDirs {
            let files = try FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil)
            for file in files where file.pathExtension.lowercased() == "json" {
                let data = try Data(contentsOf: file)
                let palette = try JSONDecoder().decode(RunicThemeJSON.self, from: data).toPalette()
                decodedIDs.insert(palette.id)
                #expect(palette.style.typography.scale > 0)
                #expect(palette.style.chrome.borderWeight > 0)
            }
        }

        #expect(Set(Theme.allCases.map(\.rawValue)).isSubset(of: decodedIDs))
    }

    @MainActor
    @Test
    func `theme polish helpers keep motion contrast and chrome scoped`() {
        let retro = Theme.retro.palette
        let terminal = Theme.terminal.palette
        let glass = Theme.glass.palette
        let light = Theme.light.palette

        #expect(retro.prefersRetroToggleChrome)
        #expect(terminal.prefersRetroToggleChrome)
        #expect(!glass.prefersRetroToggleChrome)
        #expect(!light.prefersRetroToggleChrome)
        #expect(terminal.chartScanlineOpacity == terminal.style.effects.scanlineOpacity)
        #expect(light.nsColor(light.chartAxisLabelColor).alphaComponent >= 0.80)
        #expect(glass.motion.curve(reduceMotion: true) == nil)
        #expect(glass.motion.delayedCurve(reduceMotion: true, delay: 1) == nil)
    }

    @MainActor
    @Test
    func `terminal typography keeps readable hud line rhythm`() {
        let palette = Theme.terminal.palette
        let rules = RunicFontRules.rules(for: RunicFontChoice.commitMono.id)
            .applying(palette.style.typography)

        #expect(rules.lineSpacing == 1.45)
        #expect(rules.lineSpacing > RunicFontRules.rules(for: RunicFontChoice.commitMono.id).lineSpacing)
    }

    @MainActor
    @Test
    func `theme numeric family drives numeric font store`() {
        let store = RunicFontStore()

        store.applyTheme(Theme.terminal.palette)

        #expect(store.activeNumericFamily == RunicFontChoice.commitMono.id)
    }

    @MainActor
    @Test
    func `model breakdown collapses duplicate display rows`() {
        let summaries = [
            UsageLedgerModelSummary(
                provider: .codex,
                projectID: "alpha",
                model: "gpt-5.5",
                entryCount: 2,
                totals: UsageLedgerTotals(
                    inputTokens: 90,
                    outputTokens: 30,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 20,
                    costUSD: 0.20)),
            UsageLedgerModelSummary(
                provider: .codex,
                projectID: "beta",
                model: "gpt-5.5",
                entryCount: 1,
                totals: UsageLedgerTotals(
                    inputTokens: 70,
                    outputTokens: 10,
                    cacheCreationTokens: 0,
                    cacheReadTokens: 10,
                    costUSD: 0.10)),
        ]

        let model = ModelBreakdownMenuView.makeModel(from: summaries)

        #expect(model.items.count == 1)
        #expect(model.items.first?.displayName == "gpt-5.5")
        #expect(model.items.first?.totalTokens == 230)
        #expect(model.items.first?.requestCount == 3)
        #expect(model.grandTotalCostText?.contains("0.30") == true)
    }

    @Test
    func `account info parses auth token`() throws {
        let tmp = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()),
            create: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let token = Self.fakeJWT(email: "user@example.com", plan: "pro")
        let auth = ["tokens": ["idToken": token]]
        let data = try JSONSerialization.data(withJSONObject: auth)
        let authURL = tmp.appendingPathComponent("auth.json")
        try data.write(to: authURL)

        let fetcher = UsageFetcher(environment: ["CODEX_HOME": tmp.path])
        let account = fetcher.loadAccountInfo()
        #expect(account.email == "user@example.com")
        #expect(account.plan == "pro")
    }

    private static func fakeJWT(email: String, plan: String) -> String {
        let header = (try? JSONSerialization.data(withJSONObject: ["alg": "none"])) ?? Data()
        let payload = (try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "chatgpt_plan_type": plan,
        ])) ?? Data()
        func b64(_ data: Data) -> String {
            data.base64EncodedString()
                .replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
        }
        return "\(b64(header)).\(b64(payload))."
    }
}
