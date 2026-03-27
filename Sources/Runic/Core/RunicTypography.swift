import CoreText
import SwiftUI

// MARK: - Typography tokens

/// App-wide font design token.
enum RunicTypography {
    static let typeSize: DynamicTypeSize = .xLarge

    /// Register all TTF/OTF fonts found in the app bundle's Fonts directory.
    /// Call once at launch before any UI is created.
    static func registerFonts() {
        guard let fontsURL = Bundle.main.url(forResource: "Fonts", withExtension: nil)
            ?? Bundle.main.resourceURL?.appendingPathComponent("Fonts")
        else { return }
        guard let enumerator = FileManager.default.enumerator(
            at: fontsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        else { return }
        for case let fileURL as URL in enumerator
            where fileURL.pathExtension.lowercased() == "ttf" || fileURL.pathExtension.lowercased() == "otf"
        {
            CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, nil)
        }
    }

    /// Discover bundled font family names from the Fonts directory.
    static func discoverBundledFontFamilies() -> [String] {
        guard let fontsURL = Bundle.main.url(forResource: "Fonts", withExtension: nil)
            ?? Bundle.main.resourceURL?.appendingPathComponent("Fonts")
        else { return [] }
        guard let enumerator = FileManager.default.enumerator(
            at: fontsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        else { return [] }
        var families = Set<String>()
        for case let fileURL as URL in enumerator
            where fileURL.pathExtension.lowercased() == "ttf" || fileURL.pathExtension.lowercased() == "otf"
        {
            if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fileURL as CFURL) as? [CTFontDescriptor] {
                for desc in descriptors {
                    if let name = CTFontDescriptorCopyAttribute(desc, kCTFontFamilyNameAttribute) as? String {
                        families.insert(name)
                    }
                }
            }
        }
        return families.sorted()
    }
}

// MARK: - Available font choices

/// A selectable font option shown in preferences.
struct RunicFontChoice: Identifiable, Hashable {
    let id: String
    let displayName: String

    /// System fonts — always available, no bundling.
    static let sfPro = RunicFontChoice(id: "__sf_pro__", displayName: "SF Pro")
    static let sfMono = RunicFontChoice(id: "__sf_mono__", displayName: "SF Mono")

    /// Font used to render this choice's name in the picker (preview in its own typeface).
    var previewFont: Font {
        switch self.id {
        case Self.sfPro.id: .system(.body)
        case Self.sfMono.id: .system(.body, design: .monospaced)
        default: Font.custom(self.id, fixedSize: 13)
        }
    }

    /// Build the full list: system fonts first, then bundled custom fonts.
    static func availableChoices() -> [RunicFontChoice] {
        var choices: [RunicFontChoice] = [.sfPro, .sfMono]
        for family in RunicTypography.discoverBundledFontFamilies() {
            choices.append(RunicFontChoice(id: family, displayName: family))
        }
        return choices
    }
}

// MARK: - Dynamic SwiftUI Font Scale

@MainActor
enum RunicFont {
    /// The active font family identifier. Updated from SettingsStore.
    static var family: String = "Fira Code"

    private static var isSystemFont: Bool {
        family.hasPrefix("__")
    }

    /// Font design used by `.runicTypography()` for system-font fallback.
    static var systemFallbackDesign: Font.Design {
        family == RunicFontChoice.sfPro.id ? .default : .monospaced
    }

    // MARK: Semantic sizes

    static var caption2: Font {
        makeFont(size: 10, relativeTo: .caption2)
    }

    static var caption: Font {
        makeFont(size: 11, relativeTo: .caption)
    }

    static var footnote: Font {
        makeFont(size: 12, relativeTo: .footnote)
    }

    static var callout: Font {
        makeFont(size: 13, relativeTo: .callout)
    }

    static var body: Font {
        makeFont(size: 13, relativeTo: .body)
    }

    static var subheadline: Font {
        makeFont(size: 12, relativeTo: .subheadline)
    }

    static var headline: Font {
        makeFont(size: 13, relativeTo: .headline).weight(.bold)
    }

    static var title3: Font {
        makeFont(size: 15, relativeTo: .title3)
    }

    static var title2: Font {
        makeFont(size: 17, relativeTo: .title2)
    }

    static var title: Font {
        makeFont(size: 22, relativeTo: .title)
    }

    static var largeTitle: Font {
        makeFont(size: 26, relativeTo: .largeTitle)
    }

    /// Custom fixed size.
    static func system(size: CGFloat) -> Font {
        switch self.family {
        case RunicFontChoice.sfPro.id: .system(size: size)
        case RunicFontChoice.sfMono.id: .system(size: size, design: .monospaced)
        default: Font.custom(self.family, fixedSize: size)
        }
    }

    /// Custom fixed size with weight.
    static func system(size: CGFloat, weight: Font.Weight) -> Font {
        switch self.family {
        case RunicFontChoice.sfPro.id: .system(size: size, weight: weight)
        case RunicFontChoice.sfMono.id: .system(size: size, weight: weight, design: .monospaced)
        default: Font.custom(self.family, fixedSize: size).weight(weight)
        }
    }

    // MARK: Private

    private static func makeFont(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        switch self.family {
        case RunicFontChoice.sfPro.id: .system(style)
        case RunicFontChoice.sfMono.id: .system(style, design: .monospaced)
        default: Font.custom(self.family, size: size, relativeTo: style)
        }
    }
}

// MARK: - AppKit NSFont

extension RunicFont {
    static func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self.family {
        case RunicFontChoice.sfPro.id:
            return .systemFont(ofSize: size, weight: weight)
        case RunicFontChoice.sfMono.id:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        default:
            let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
            let descriptor = NSFontDescriptor(fontAttributes: [
                .family: family,
                .traits: traits,
            ])
            return NSFont(descriptor: descriptor, size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }
}

// MARK: - View modifier

extension View {
    /// Apply the selected font as the default, with system fallback design and xLarge dynamic type.
    func runicTypography() -> some View {
        self
            .font(RunicFont.body)
            .fontDesign(RunicFont.systemFallbackDesign)
            .dynamicTypeSize(RunicTypography.typeSize)
    }
}
