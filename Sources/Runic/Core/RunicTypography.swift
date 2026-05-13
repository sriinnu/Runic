import CoreText
import AppKit
import SwiftUI

// MARK: - Typography tokens

/// App-wide font design token.
enum RunicTypography {
    static let typeSize: DynamicTypeSize = .xLarge

    /// Register all TTF/OTF fonts found in the app bundle's Fonts directory.
    /// Call once at launch before any UI is created.
    static func registerFonts() {
        for fontsURL in self.fontDirectories() {
            guard let enumerator = FileManager.default.enumerator(
                at: fontsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
            else { continue }
            for case let fileURL as URL in enumerator
                where fileURL.pathExtension.lowercased() == "ttf" || fileURL.pathExtension.lowercased() == "otf"
            {
                CTFontManagerRegisterFontsForURL(fileURL as CFURL, .process, nil)
            }
        }
    }

    /// Discover bundled font family names from the Fonts directory.
    static func discoverBundledFontFamilies() -> [String] {
        var families = Set<String>()
        for fontsURL in self.fontDirectories() {
            guard let enumerator = FileManager.default.enumerator(
                at: fontsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles])
            else { continue }
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
        }
        return families.sorted()
    }

    static func fontName(for family: String, nsWeight: NSFont.Weight = .regular) -> String {
        guard !family.hasPrefix("__") else { return family }
        guard let members = NSFontManager.shared.availableMembers(ofFontFamily: family), !members.isEmpty else {
            return family
        }

        let preferredFaces = self.preferredFaceNames(for: nsWeight)
        for preferredFace in preferredFaces {
            if let match = members.first(where: { member in
                guard member.count >= 2, let face = member[1] as? String else { return false }
                return face.range(of: preferredFace, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }), let fontName = match.first as? String {
                return fontName
            }
        }

        return members.compactMap { $0.first as? String }.first ?? family
    }

    private static func preferredFaceNames(for weight: NSFont.Weight) -> [String] {
        let raw = weight.rawValue
        if raw >= NSFont.Weight.bold.rawValue {
            return ["Bold", "SemiBold", "Medium", "Regular"]
        }
        if raw >= NSFont.Weight.semibold.rawValue {
            return ["SemiBold", "DemiBold", "Medium", "Bold", "Regular"]
        }
        if raw >= NSFont.Weight.medium.rawValue {
            return ["Medium", "Regular", "SemiBold"]
        }
        if raw <= NSFont.Weight.light.rawValue {
            return ["Light", "Regular"]
        }
        return ["Regular", "Book", "Medium"]
    }

    private static func fontDirectories() -> [URL] {
        let candidates = [
            Bundle.main.url(forResource: "Fonts", withExtension: nil),
            Bundle.main.url(forResource: "Fonts", withExtension: nil, subdirectory: "Resources"),
            Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
            Bundle.main.resourceURL?.appendingPathComponent("Resources/Fonts"),
            Bundle.module.url(forResource: "Fonts", withExtension: nil),
            Bundle.module.url(forResource: "Fonts", withExtension: nil, subdirectory: "Resources"),
        ]
        var seen: Set<String> = []
        return candidates.compactMap { url in
            guard let url else { return nil }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return nil
            }
            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else { return nil }
            return url
        }
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
        default: Font.custom(RunicTypography.fontName(for: self.id), fixedSize: 13)
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
        default: Font.custom(RunicTypography.fontName(for: self.family), fixedSize: size)
        }
    }

    /// Custom fixed size with weight.
    static func system(size: CGFloat, weight: Font.Weight) -> Font {
        switch self.family {
        case RunicFontChoice.sfPro.id: .system(size: size, weight: weight)
        case RunicFontChoice.sfMono.id: .system(size: size, weight: weight, design: .monospaced)
        default: Font.custom(RunicTypography.fontName(for: self.family), fixedSize: size).weight(weight)
        }
    }

    // MARK: Private

    private static func makeFont(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        switch self.family {
        case RunicFontChoice.sfPro.id: .system(style)
        case RunicFontChoice.sfMono.id: .system(style, design: .monospaced)
        default: Font.custom(RunicTypography.fontName(for: self.family), size: size, relativeTo: style)
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
            let fontName = RunicTypography.fontName(for: self.family, nsWeight: weight)
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
