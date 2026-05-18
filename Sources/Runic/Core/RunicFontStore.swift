import AppKit
import Observation
import SwiftUI

/// Observable font configuration. SwiftUI views read this through
/// `@Environment(\.runicFonts)`; when `family` or `themeDesign` changes, every
/// dependent view body invalidates automatically — no manual rebuilds,
/// no `.id()` hammer.
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
    var family: String = "Fira Code"

    /// Theme-driven design override (Terminal forces `.monospaced`, Daybreak
    /// forces `.rounded`). Wins over family-derived design.
    var themeDesign: Font.Design?

    /// Single source of truth shared between the static `RunicFont` facade
    /// and the reactive SwiftUI environment. Both point at this instance.
    static let shared = RunicFontStore()

    // MARK: - SwiftUI Fonts

    var caption2: Font { self.makeFont(size: 10, relativeTo: .caption2) }
    var caption: Font { self.makeFont(size: 11, relativeTo: .caption) }
    var footnote: Font { self.makeFont(size: 12, relativeTo: .footnote) }
    var callout: Font { self.makeFont(size: 13, relativeTo: .callout) }
    var body: Font { self.makeFont(size: 13, relativeTo: .body) }
    var subheadline: Font { self.makeFont(size: 12, relativeTo: .subheadline) }
    var headline: Font { self.makeFont(size: 13, relativeTo: .headline).weight(.bold) }
    var title3: Font { self.makeFont(size: 15, relativeTo: .title3) }
    var title2: Font { self.makeFont(size: 17, relativeTo: .title2) }
    var title: Font { self.makeFont(size: 22, relativeTo: .title) }
    var largeTitle: Font { self.makeFont(size: 26, relativeTo: .largeTitle) }

    var activeRules: RunicFontRules {
        RunicFontRules.rules(for: self.family)
    }

    var systemFallbackDesign: Font.Design {
        self.effectiveDesign ?? Self.systemDesign(for: self.family)
    }

    func system(size: CGFloat) -> Font {
        if let design = self.effectiveDesign {
            return .system(size: size, design: design)
        }
        return Font.custom(RunicTypography.fontName(for: self.family), fixedSize: size)
    }

    func system(size: CGFloat, weight: Font.Weight) -> Font {
        if let design = self.effectiveDesign {
            return .system(size: size, weight: weight, design: design)
        }
        return Font.custom(RunicTypography.fontName(for: self.family), fixedSize: size).weight(weight)
    }

    // MARK: - AppKit NSFont

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self.family {
        case RunicFontChoice.sfPro.id:
            return .systemFont(ofSize: size, weight: weight)
        case RunicFontChoice.sfMono.id:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        case RunicFontChoice.sfRounded.id:
            return Self.nsSystemFont(size: size, weight: weight, design: .rounded)
        case RunicFontChoice.newYork.id:
            return Self.nsSystemFont(size: size, weight: weight, design: .serif)
        default:
            let fontName = RunicTypography.fontName(for: self.family, nsWeight: weight)
            if let font = NSFont(name: fontName, size: size) {
                return font
            }
            let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: self.family,
                .traits: traits,
            ])
            return NSFont(descriptor: descriptor, size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }

    // MARK: - Internals

    private var effectiveDesign: Font.Design? {
        if let override = self.themeDesign { return override }
        switch self.family {
        case RunicFontChoice.sfPro.id: return Font.Design.default
        case RunicFontChoice.sfMono.id: return .monospaced
        case RunicFontChoice.sfRounded.id: return .rounded
        case RunicFontChoice.newYork.id: return .serif
        default: return nil
        }
    }

    private func makeFont(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if let design = self.effectiveDesign {
            return .system(style, design: design)
        }
        return Font.custom(RunicTypography.fontName(for: self.family), size: size, relativeTo: style)
    }

    private static func systemDesign(for family: String) -> Font.Design {
        switch family {
        case RunicFontChoice.sfMono.id: .monospaced
        case RunicFontChoice.sfRounded.id: .rounded
        case RunicFontChoice.newYork.id: .serif
        default: RunicFontRules.rules(for: family).prefersMonospacedDigits ? .monospaced : .default
        }
    }

    private static func nsSystemFont(size: CGFloat, weight: NSFont.Weight, design: NSFontDescriptor.SystemDesign) -> NSFont {
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
    @Entry var runicFonts: RunicFontStore = RunicFontStore()
}
