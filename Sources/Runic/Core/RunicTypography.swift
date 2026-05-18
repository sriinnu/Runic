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
        RunicResourceLocator.directories(named: "Fonts")
    }
}

// MARK: - Available font choices

enum RunicBackgroundTone {
    case light
    case dark
}

enum RunicTextRole {
    case primary
    case secondary
    case muted
}

struct RunicFontContrast: Hashable {
    let lightPrimaryOpacity: Double
    let lightSecondaryOpacity: Double
    let lightMutedOpacity: Double
    let darkPrimaryOpacity: Double
    let darkSecondaryOpacity: Double
    let darkMutedOpacity: Double

    func color(role: RunicTextRole, on tone: RunicBackgroundTone) -> Color {
        switch (tone, role) {
        case (.light, .primary): Color.black.opacity(self.lightPrimaryOpacity)
        case (.light, .secondary): Color.black.opacity(self.lightSecondaryOpacity)
        case (.light, .muted): Color.black.opacity(self.lightMutedOpacity)
        case (.dark, .primary): Color.white.opacity(self.darkPrimaryOpacity)
        case (.dark, .secondary): Color.white.opacity(self.darkSecondaryOpacity)
        case (.dark, .muted): Color.white.opacity(self.darkMutedOpacity)
        }
    }
}

struct RunicFontRules: Hashable {
    let letterSpacing: CGFloat
    let compactLetterSpacing: CGFloat
    let wordSpacing: CGFloat
    let lineSpacing: CGFloat
    let prefersMonospacedDigits: Bool
    let contrast: RunicFontContrast

    var summary: String {
        "letter \(Self.format(self.letterSpacing)) · word \(Self.format(self.wordSpacing)) · line \(Self.format(self.lineSpacing))"
    }

    static func rules(for family: String) -> RunicFontRules {
        let normalized = family.lowercased()
        if family == RunicFontChoice.sfMono.id ||
            normalized.contains("fira") ||
            normalized.contains("jetbrains") ||
            normalized.contains("ibm plex mono") ||
            normalized.contains("menlo") ||
            normalized.contains("monaco") ||
            normalized.contains("space mono") ||
            normalized.contains("geist mono")
        {
            return RunicFontRules(
                letterSpacing: 0.10,
                compactLetterSpacing: 0,
                wordSpacing: 0,
                lineSpacing: 1.0,
                prefersMonospacedDigits: true,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.90,
                    lightSecondaryOpacity: 0.62,
                    lightMutedOpacity: 0.42,
                    darkPrimaryOpacity: 0.94,
                    darkSecondaryOpacity: 0.66,
                    darkMutedOpacity: 0.46))
        }

        // Geist Sans — Vercel's modern UI sans. Tight letter spacing, no
        // tabular digits (it's not a mono), neutral contrast.
        if normalized == "geist" || normalized.hasPrefix("geist ") && !normalized.contains("mono") {
            return RunicFontRules(
                letterSpacing: 0,
                compactLetterSpacing: -0.05,
                wordSpacing: 0,
                lineSpacing: 1.1,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.90,
                    lightSecondaryOpacity: 0.60,
                    lightMutedOpacity: 0.40,
                    darkPrimaryOpacity: 0.94,
                    darkSecondaryOpacity: 0.64,
                    darkMutedOpacity: 0.44))
        }

        if family == RunicFontChoice.newYork.id ||
            normalized.contains("palatino") ||
            normalized.contains("optima") ||
            normalized.contains("hoefler")
        {
            return RunicFontRules(
                letterSpacing: 0,
                compactLetterSpacing: 0,
                wordSpacing: 0.20,
                lineSpacing: 2.0,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.88,
                    lightSecondaryOpacity: 0.58,
                    lightMutedOpacity: 0.40,
                    darkPrimaryOpacity: 0.93,
                    darkSecondaryOpacity: 0.64,
                    darkMutedOpacity: 0.46))
        }

        if normalized.contains("helvetica") {
            return RunicFontRules(
                letterSpacing: 0,
                compactLetterSpacing: 0,
                wordSpacing: 0.05,
                lineSpacing: 1.1,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.90,
                    lightSecondaryOpacity: 0.61,
                    lightMutedOpacity: 0.42,
                    darkPrimaryOpacity: 0.94,
                    darkSecondaryOpacity: 0.65,
                    darkMutedOpacity: 0.46))
        }

        if normalized.contains("din") {
            return RunicFontRules(
                letterSpacing: 0.45,
                compactLetterSpacing: 0.25,
                wordSpacing: 0.15,
                lineSpacing: 0.8,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.91,
                    lightSecondaryOpacity: 0.62,
                    lightMutedOpacity: 0.42,
                    darkPrimaryOpacity: 0.95,
                    darkSecondaryOpacity: 0.66,
                    darkMutedOpacity: 0.47))
        }

        if family == RunicFontChoice.sfRounded.id || normalized.contains("avenir") || normalized.contains("gill sans") {
            return RunicFontRules(
                letterSpacing: 0,
                compactLetterSpacing: 0,
                wordSpacing: 0.10,
                lineSpacing: 1.5,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.89,
                    lightSecondaryOpacity: 0.60,
                    lightMutedOpacity: 0.41,
                    darkPrimaryOpacity: 0.94,
                    darkSecondaryOpacity: 0.65,
                    darkMutedOpacity: 0.46))
        }

        return RunicFontRules(
            letterSpacing: 0,
            compactLetterSpacing: 0,
            wordSpacing: 0,
            lineSpacing: 1.4,
            prefersMonospacedDigits: false,
            contrast: RunicFontContrast(
                lightPrimaryOpacity: 0.88,
                lightSecondaryOpacity: 0.60,
                lightMutedOpacity: 0.40,
                darkPrimaryOpacity: 0.93,
                darkSecondaryOpacity: 0.64,
                darkMutedOpacity: 0.45))
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }
}

/// A selectable font option shown in preferences.
struct RunicFontChoice: Identifiable, Hashable {
    let id: String
    let displayName: String

    /// System fonts — always available, no bundling.
    static let sfPro = RunicFontChoice(id: "__sf_pro__", displayName: "SF Pro")
    static let sfMono = RunicFontChoice(id: "__sf_mono__", displayName: "SF Mono")
    static let sfRounded = RunicFontChoice(id: "__sf_rounded__", displayName: "SF Rounded")
    static let newYork = RunicFontChoice(id: "__new_york__", displayName: "New York")

    /// Bundled families. Display names match the actual `family` attribute
    /// inside each TTF so SwiftUI / NSFont can find them after registration.
    static let geist = RunicFontChoice(id: "Geist", displayName: "Geist")
    static let geistMono = RunicFontChoice(id: "Geist Mono", displayName: "Geist Mono")

    /// Curated macOS families. They are shown only when available on the machine.
    static let avenirNext = RunicFontChoice(id: "Avenir Next", displayName: "Avenir Next")
    static let helveticaNeue = RunicFontChoice(id: "Helvetica Neue", displayName: "Helvetica Neue")
    static let gillSans = RunicFontChoice(id: "Gill Sans", displayName: "Gill Sans")
    static let menlo = RunicFontChoice(id: "Menlo", displayName: "Menlo")
    static let dinAlternate = RunicFontChoice(id: "DIN Alternate", displayName: "DIN Alternate")
    static let optima = RunicFontChoice(id: "Optima", displayName: "Optima")
    static let hoeflerText = RunicFontChoice(id: "Hoefler Text", displayName: "Hoefler Text")

    var rules: RunicFontRules {
        RunicFontRules.rules(for: self.id)
    }

    /// Font used to render this choice's name in the picker (preview in its own typeface).
    @MainActor
    var previewFont: Font {
        RunicFont.previewFont(for: self.id, size: 13)
    }

    /// Build the full list: system fonts first, then bundled custom fonts.
    static func availableChoices() -> [RunicFontChoice] {
        var choices: [RunicFontChoice] = [.sfPro, .sfMono, .sfRounded, .newYork]
        let curatedFamilies: [RunicFontChoice] = [
            .avenirNext,
            .helveticaNeue,
            .gillSans,
            .menlo,
            .dinAlternate,
            .optima,
            .hoeflerText,
        ]
        for choice in curatedFamilies where self.isFontFamilyAvailable(choice.id) {
            choices.append(choice)
        }

        var seen = Set(choices.map(\.id))
        for family in RunicTypography.discoverBundledFontFamilies() {
            guard seen.insert(family).inserted else { continue }
            choices.append(RunicFontChoice(id: family, displayName: family))
        }
        return choices
    }

    static func displayName(for id: String) -> String {
        if let choice = self.availableChoices().first(where: { $0.id == id }) {
            return choice.displayName
        }
        return id
    }

    private static func isFontFamilyAvailable(_ family: String) -> Bool {
        NSFontManager.shared.availableMembers(ofFontFamily: family)?.isEmpty == false
    }
}

// MARK: - Dynamic SwiftUI Font Scale

/// Static facade that forwards every call to `RunicFontStore.shared`. SwiftUI
/// views should prefer `@Environment(\.runicFonts)` so font changes propagate
/// reactively — using `RunicFont.X` from a view body works but won't update
/// until the body invalidates for some other reason. AppKit paths (NSMenu,
/// NSStatusItem, IconRenderer) keep using the static accessors since they
/// rebuild on each interaction.
@MainActor
enum RunicFont {
    static var family: String {
        get { RunicFontStore.shared.family }
        set { RunicFontStore.shared.family = newValue }
    }

    static var themeDesignOverride: Font.Design? {
        get { RunicFontStore.shared.themeDesign }
        set { RunicFontStore.shared.themeDesign = newValue }
    }

    static var activeRules: RunicFontRules { RunicFontStore.shared.activeRules }
    static var systemFallbackDesign: Font.Design { RunicFontStore.shared.systemFallbackDesign }

    static var caption2: Font { RunicFontStore.shared.caption2 }
    static var caption: Font { RunicFontStore.shared.caption }
    static var footnote: Font { RunicFontStore.shared.footnote }
    static var callout: Font { RunicFontStore.shared.callout }
    static var body: Font { RunicFontStore.shared.body }
    static var subheadline: Font { RunicFontStore.shared.subheadline }
    static var headline: Font { RunicFontStore.shared.headline }
    static var title3: Font { RunicFontStore.shared.title3 }
    static var title2: Font { RunicFontStore.shared.title2 }
    static var title: Font { RunicFontStore.shared.title }
    static var largeTitle: Font { RunicFontStore.shared.largeTitle }

    static func system(size: CGFloat) -> Font {
        RunicFontStore.shared.system(size: size)
    }

    static func system(size: CGFloat, weight: Font.Weight) -> Font {
        RunicFontStore.shared.system(size: size, weight: weight)
    }

    static func previewFont(for family: String, size: CGFloat) -> Font {
        switch family {
        case RunicFontChoice.sfPro.id: .system(size: size)
        case RunicFontChoice.sfMono.id: .system(size: size, design: .monospaced)
        case RunicFontChoice.sfRounded.id: .system(size: size, design: .rounded)
        case RunicFontChoice.newYork.id: .system(size: size, design: .serif)
        default: Font.custom(RunicTypography.fontName(for: family), fixedSize: size)
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
        case RunicFontChoice.sfRounded.id:
            return self.nsSystemFont(size: size, weight: weight, design: .rounded)
        case RunicFontChoice.newYork.id:
            return self.nsSystemFont(size: size, weight: weight, design: .serif)
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

    private static func nsSystemFont(
        size: CGFloat,
        weight: NSFont.Weight,
        design: NSFontDescriptor.SystemDesign) -> NSFont
    {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

// MARK: - View modifier

extension View {
    /// Apply the selected font as the default, with system fallback design and xLarge dynamic type.
    func runicTypography() -> some View {
        self
            .font(RunicFont.body)
            .fontDesign(RunicFont.systemFallbackDesign)
            .tracking(RunicFont.activeRules.letterSpacing)
            .lineSpacing(RunicFont.activeRules.lineSpacing)
            .dynamicTypeSize(RunicTypography.typeSize)
    }
}
