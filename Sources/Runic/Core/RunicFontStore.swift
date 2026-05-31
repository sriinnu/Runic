import AppKit
import Observation
import SwiftUI

/// Observable font configuration. SwiftUI views read this through
/// `@Environment(\.runicFonts)`; when the chosen family or active theme
/// typography changes, dependent view bodies invalidate automatically.
///
/// `RunicFont` (the legacy enum) remains as a static facade that forwards to
/// `RunicFontStore.shared` so AppKit code paths (NSMenu, NSStatusItem,
/// IconRenderer) keep working without env. Only SwiftUI views need the env to
/// be reactive.
///
/// Not marked `@MainActor` so the `@Entry` environment default can construct
/// a placeholder instance without isolation hops. Mutations only happen from
/// `SettingsStore` (which is `@MainActor`), so writes remain serialized.
@Observable
final class RunicFontStore: @unchecked Sendable {
    /// Active font family identifier (one of the `RunicFontChoice` ids, or a
    /// bundled font name).
    var family: String = RunicFontChoice.defaultFamily

    /// Theme-driven design override (Terminal forces `.monospaced`, Daybreak
    /// forces `.rounded`) when the active font is one of the virtual system
    /// families. Custom bundled fonts keep their real family.
    var themeDesign: Font.Design?

    /// Optional theme-selected real family, e.g. CommitMono for Terminal.
    var themeFamilyOverride: String?

    /// Optional theme-selected family for numeric labels and metric values.
    var themeNumericFamilyOverride: String?

    /// Fine-grained typography tuning from theme JSON.
    var themeTypography: RunicThemeTypographyStyle = .standard

    /// Single source of truth shared between the static `RunicFont` facade
    /// and the reactive SwiftUI environment. Both point at this instance.
    static let shared = RunicFontStore()

    // MARK: - SwiftUI Fonts

    var caption2: Font {
        self.makeFont(size: 11, relativeTo: .caption2)
    }

    var caption: Font {
        self.makeFont(size: 12, relativeTo: .caption)
    }

    var footnote: Font {
        self.makeFont(size: 13, relativeTo: .footnote)
    }

    var callout: Font {
        self.makeFont(size: 15, relativeTo: .callout)
    }

    var body: Font {
        self.makeFont(size: 14, relativeTo: .body)
    }

    var subheadline: Font {
        self.makeFont(size: 15, relativeTo: .subheadline)
    }

    var headline: Font {
        self.makeFont(size: 16, relativeTo: .headline).weight(.bold)
    }

    var title3: Font {
        self.makeFont(size: 18, relativeTo: .title3)
    }

    var title2: Font {
        self.makeFont(size: 20, relativeTo: .title2)
    }

    var title: Font {
        self.makeFont(size: 24, relativeTo: .title)
    }

    var largeTitle: Font {
        self.makeFont(size: 28, relativeTo: .largeTitle)
    }

    var numericCaption: Font {
        self.makeNumericFont(size: 12, weight: .regular)
    }

    var numericFootnote: Font {
        self.makeNumericFont(size: 13, weight: .medium)
    }

    var numericHeadline: Font {
        self.makeNumericFont(size: 16, weight: .semibold)
    }

    var activeRules: RunicFontRules {
        RunicFontRules.rules(for: self.activeFamily).applying(self.themeTypography)
    }

    var systemFallbackDesign: Font.Design {
        self.effectiveDesign ?? Self.systemDesign(for: self.activeFamily)
    }

    var activeFamily: String {
        self.themeFamilyOverride ?? self.family
    }

    var activeNumericFamily: String {
        self.themeNumericFamilyOverride ?? self.activeFamily
    }

    func system(size: CGFloat) -> Font {
        if let design = self.effectiveDesign {
            return .system(size: self.scaled(size), design: design)
        }
        return Font.custom(RunicTypography.fontName(for: self.activeFamily), fixedSize: self.scaled(size))
    }

    func system(size: CGFloat, weight: Font.Weight) -> Font {
        if let design = self.effectiveDesign {
            return .system(size: self.scaled(size), weight: weight, design: design)
        }
        return Font.custom(
            RunicTypography.fontName(for: self.activeFamily),
            fixedSize: self.scaled(size))
            .weight(weight)
    }

    // MARK: - AppKit NSFont

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let family = self.activeFamily
        let size = self.scaled(size)
        switch family {
        case RunicFontChoice.sfPro.id:
            return .systemFont(ofSize: size, weight: weight)
        case RunicFontChoice.sfMono.id:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        case RunicFontChoice.sfRounded.id:
            return Self.nsSystemFont(size: size, weight: weight, design: .rounded)
        case RunicFontChoice.newYork.id:
            return Self.nsSystemFont(size: size, weight: weight, design: .serif)
        default:
            let fontName = RunicTypography.fontName(for: family, nsWeight: weight)
            if let font = NSFont(name: fontName, size: size) {
                return font
            }
            let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: family,
                .traits: traits,
            ])
            return NSFont(descriptor: descriptor, size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    func applyTheme(_ palette: RunicThemePalette) {
        self.themeDesign = palette.fonts.swiftUIDesignOverride
        self.themeFamilyOverride = RunicFontChoice.resolvedThemeFamily(palette.style.typography.bodyFamily)
        self.themeNumericFamilyOverride = RunicFontChoice.resolvedThemeFamily(palette.style.typography.numericFamily)
        self.themeTypography = palette.style.typography
    }

    // MARK: - Internals

    private var effectiveDesign: Font.Design? {
        if self.usesCustomFontFamily { return nil }
        if let override = self.themeDesign { return override }
        switch self.activeFamily {
        case RunicFontChoice.sfPro.id: return Font.Design.default
        case RunicFontChoice.sfMono.id: return .monospaced
        case RunicFontChoice.sfRounded.id: return .rounded
        case RunicFontChoice.newYork.id: return .serif
        default: return nil
        }
    }

    private func makeFont(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if let design = self.effectiveDesign {
            return .system(size: self.scaled(size), design: design)
        }
        return Font.custom(RunicTypography.fontName(for: self.activeFamily), size: self.scaled(size), relativeTo: style)
    }

    private func makeNumericFont(size: CGFloat, weight: Font.Weight) -> Font {
        let scaledSize = self.scaled(size)
        if self.activeNumericFamily == self.activeFamily, let design = self.effectiveDesign {
            return .system(size: scaledSize, weight: weight, design: design)
        }
        switch self.activeNumericFamily {
        case RunicFontChoice.sfPro.id:
            return .system(size: scaledSize, weight: weight)
        case RunicFontChoice.sfMono.id:
            return .system(size: scaledSize, weight: weight, design: .monospaced)
        case RunicFontChoice.sfRounded.id:
            return .system(size: scaledSize, weight: weight, design: .rounded)
        case RunicFontChoice.newYork.id:
            return .system(size: scaledSize, weight: weight, design: .serif)
        default:
            return Font.custom(RunicTypography.fontName(for: self.activeNumericFamily), fixedSize: scaledSize)
                .weight(weight)
        }
    }

    private var usesCustomFontFamily: Bool {
        switch self.activeFamily {
        case RunicFontChoice.sfPro.id,
             RunicFontChoice.sfMono.id,
             RunicFontChoice.sfRounded.id,
             RunicFontChoice.newYork.id:
            false
        default:
            true
        }
    }

    private func scaled(_ size: CGFloat) -> CGFloat {
        max(8, size * self.themeTypography.scale)
    }

    private static func systemDesign(for family: String) -> Font.Design {
        switch family {
        case RunicFontChoice.sfMono.id: .monospaced
        case RunicFontChoice.sfRounded.id: .rounded
        case RunicFontChoice.newYork.id: .serif
        default:
            RunicFontRules.rules(for: family).prefersMonospacedDigits ? .monospaced : .default
        }
    }

    private static func nsSystemFont(
        size: CGFloat,
        weight: NSFont.Weight,
        design: NSFontDescriptor.SystemDesign)
        -> NSFont
    {
        let baseDescriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let descriptor = baseDescriptor.withDesign(design) {
            return NSFont(descriptor: descriptor, size: size)
                ?? .systemFont(ofSize: size, weight: weight)
        }
        return .systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Environment

extension EnvironmentValues {
    /// Default is a fresh placeholder; the real `RunicFontStore.shared` gets
    /// injected at every scene root by `RunicApp`. Using `.shared` directly
    /// as the default would trigger a main-actor isolation warning at the
    /// `@Entry` site.
    @Entry var runicFonts: RunicFontStore = .init()
}
