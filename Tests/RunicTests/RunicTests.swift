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
                self.contrast(
                    selectedIcon,
                    against: self.providerTabSelectedFill(for: palette),
                    palette: palette) >= 3.0,
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
}
