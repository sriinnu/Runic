import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Runic

/// Contrast audit for the text tones the menu actually puts on its fills:
/// the Resets panel, metric cards, overview pills, and chips. The older
/// tests cover surface/cardFill; these cover the composited panel fills
/// (surface card → menuSubtleFill, metric card → menuSubtleFill@0.82,
/// selected chip → accent wash) where text really sits.
struct ThemeContrastAuditTests {
    @MainActor
    @Test
    func `body text tones clear 4point5 on every menu fill`() {
        for theme in Theme.allCases {
            let palette = theme.palette
            for (name, fill) in self.menuFills(palette) {
                for (tone, color) in self.readableTones(palette) {
                    #expect(
                        self.contrast(color, against: fill, palette: palette) >= 4.5,
                        "\(theme.rawValue): \(tone) on \(name) must hit 4.5:1")
                }
            }
        }
    }

    @MainActor
    @Test
    func `accent and status tones read on every menu fill`() {
        for theme in Theme.allCases {
            let palette = theme.palette
            for (name, fill) in self.menuFills(palette) {
                for (tone, color) in self.emphasisTones(palette) {
                    #expect(
                        self.contrast(color, against: fill, palette: palette) >= 3.0,
                        "\(theme.rawValue): \(tone) on \(name) must hit 3:1")
                }
            }
        }
    }

    @MainActor
    @Test
    func `selected chip text reads on the selected wash`() {
        for theme in Theme.allCases {
            let palette = theme.palette
            let wash = palette.accent.opacity(0.22)
            // Chips draw their selected foreground in the accent itself.
            #expect(
                self.contrast(palette.accent, against: wash, palette: palette) >= 3.0,
                "\(theme.rawValue): accent on its own selected wash must hit 3:1")
        }
    }

    // MARK: - Fixtures

    private func menuFills(_ palette: RunicThemePalette) -> [(String, Color)] {
        [
            ("surface", palette.surface),
            ("menuSubtleFill", palette.menuSubtleFill),
            ("metricCard", palette.menuSubtleFill.opacity(0.82)),
            ("menuHoverFill", palette.menuHoverFill),
        ]
    }

    private func readableTones(_ palette: RunicThemePalette) -> [(String, Color)] {
        var tones: [(String, Color)] = [
            ("primaryText", palette.primaryText),
            ("readableSecondaryText", palette.readableSecondaryText),
            ("subduedSecondaryText", palette.subduedSecondaryText),
        ]
        // System mirrors Apple's secondaryLabelColor, which ships under 4.5.
        if palette.id != "system" {
            tones.append(("secondaryText", palette.secondaryText))
        }
        return tones
    }

    private func emphasisTones(_ palette: RunicThemePalette) -> [(String, Color)] {
        [
            ("accent", palette.accent),
            ("highlight", palette.highlight),
            ("warm", palette.warm),
            ("tertiary", palette.tertiary),
        ]
    }

    // MARK: - Math (mirrors RunicTests)

    private func contrast(_ foreground: Color, against background: Color, palette: RunicThemePalette) -> Double {
        let surface = self.opaqueRGB(palette.nsColor(palette.surface, fallback: .windowBackgroundColor))
        let resolvedBackground = self.composite(
            self.rgba(palette.nsColor(background, fallback: .windowBackgroundColor)),
            over: surface)
        let resolvedForeground = self.composite(
            self.rgba(palette.nsColor(foreground, fallback: .controlAccentColor)),
            over: resolvedBackground)
        let l1 = self.luminance(resolvedForeground)
        let l2 = self.luminance(resolvedBackground)
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
