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
                if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fileURL as CFURL)
                    as? [CTFontDescriptor]
                {
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

    func applying(_ strength: RunicThemeTypographyStyle.ContrastStrength) -> RunicFontContrast {
        switch strength {
        case .soft:
            RunicFontContrast(
                lightPrimaryOpacity: max(0.82, self.lightPrimaryOpacity - 0.03),
                lightSecondaryOpacity: max(0.54, self.lightSecondaryOpacity - 0.03),
                lightMutedOpacity: max(0.36, self.lightMutedOpacity - 0.02),
                darkPrimaryOpacity: max(0.88, self.darkPrimaryOpacity - 0.03),
                darkSecondaryOpacity: max(0.56, self.darkSecondaryOpacity - 0.03),
                darkMutedOpacity: max(0.38, self.darkMutedOpacity - 0.02))
        case .standard:
            self
        case .strong:
            RunicFontContrast(
                lightPrimaryOpacity: min(0.96, self.lightPrimaryOpacity + 0.04),
                lightSecondaryOpacity: min(0.76, self.lightSecondaryOpacity + 0.08),
                lightMutedOpacity: min(0.58, self.lightMutedOpacity + 0.07),
                darkPrimaryOpacity: min(0.98, self.darkPrimaryOpacity + 0.03),
                darkSecondaryOpacity: min(0.78, self.darkSecondaryOpacity + 0.08),
                darkMutedOpacity: min(0.60, self.darkMutedOpacity + 0.07))
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
        "letter \(Self.format(self.letterSpacing)) · " +
            "word \(Self.format(self.wordSpacing)) · line \(Self.format(self.lineSpacing))"
    }

    func applying(_ typography: RunicThemeTypographyStyle) -> RunicFontRules {
        let lineSpacing = typography.lineSpacing ?? self.lineSpacing * typography.scale
        return RunicFontRules(
            letterSpacing: max(0, self.letterSpacing + typography.tracking),
            compactLetterSpacing: max(0, self.compactLetterSpacing + typography.tracking * 0.65),
            wordSpacing: self.wordSpacing,
            lineSpacing: max(0, lineSpacing),
            prefersMonospacedDigits: self.prefersMonospacedDigits,
            contrast: self.contrast.applying(typography.contrast))
    }

    static func rules(for family: String) -> RunicFontRules {
        let normalized = family.lowercased()
        if family == RunicFontChoice.sfMono.id ||
            normalized.contains("menlo") ||
            normalized.contains("monaco") ||
            normalized.contains("commitmono") ||
            normalized.contains("berkeley mono") ||
            normalized.contains("operator mono") ||
            normalized == "tx-02" ||
            normalized.contains("geist mono")
        {
            return RunicFontRules(
                letterSpacing: 0.10,
                compactLetterSpacing: 0,
                wordSpacing: 0,
                lineSpacing: 1.15,
                prefersMonospacedDigits: true,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.92,
                    lightSecondaryOpacity: 0.68,
                    lightMutedOpacity: 0.48,
                    darkPrimaryOpacity: 0.96,
                    darkSecondaryOpacity: 0.72,
                    darkMutedOpacity: 0.52))
        }

        // Mona Sans is the default product face: compact, clear, and calm.
        // Geist stays available as a slightly warmer alternate sans.
        if normalized == "mona sans" ||
            normalized == "geist" ||
            normalized.hasPrefix("geist ") && !normalized.contains("mono")
        {
            return RunicFontRules(
                letterSpacing: 0,
                compactLetterSpacing: 0,
                wordSpacing: 0,
                lineSpacing: normalized == "mona sans" ? 1.25 : 1.15,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.92,
                    lightSecondaryOpacity: 0.68,
                    lightMutedOpacity: 0.48,
                    darkPrimaryOpacity: 0.96,
                    darkSecondaryOpacity: 0.72,
                    darkMutedOpacity: 0.52))
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
                    lightPrimaryOpacity: 0.90,
                    lightSecondaryOpacity: 0.64,
                    lightMutedOpacity: 0.46,
                    darkPrimaryOpacity: 0.95,
                    darkSecondaryOpacity: 0.70,
                    darkMutedOpacity: 0.50))
        }

        if family == RunicFontChoice.sfRounded.id {
            return RunicFontRules(
                letterSpacing: 0,
                compactLetterSpacing: 0,
                wordSpacing: 0.10,
                lineSpacing: 1.5,
                prefersMonospacedDigits: false,
                contrast: RunicFontContrast(
                    lightPrimaryOpacity: 0.91,
                    lightSecondaryOpacity: 0.66,
                    lightMutedOpacity: 0.47,
                    darkPrimaryOpacity: 0.95,
                    darkSecondaryOpacity: 0.71,
                    darkMutedOpacity: 0.51))
        }

        return RunicFontRules(
            letterSpacing: 0,
            compactLetterSpacing: 0,
            wordSpacing: 0,
            lineSpacing: 1.4,
            prefersMonospacedDigits: false,
            contrast: RunicFontContrast(
                lightPrimaryOpacity: 0.91,
                lightSecondaryOpacity: 0.66,
                lightMutedOpacity: 0.47,
                darkPrimaryOpacity: 0.95,
                darkSecondaryOpacity: 0.70,
                darkMutedOpacity: 0.50))
    }

    private static func format(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }
}

/// A selectable font option shown in preferences.
struct RunicFontChoice: Identifiable, Hashable {
    let id: String
    let displayName: String

    static let defaultFamily = "Mona Sans"

    /// System fonts — always available, no bundling.
    static let sfPro = RunicFontChoice(id: "__sf_pro__", displayName: "SF Pro")
    static let sfMono = RunicFontChoice(id: "__sf_mono__", displayName: "SF Mono")
    static let sfRounded = RunicFontChoice(id: "__sf_rounded__", displayName: "SF Rounded")
    static let newYork = RunicFontChoice(id: "__new_york__", displayName: "New York")

    /// Curated families. Commercial faces are shown only when installed locally.
    static let monaSans = RunicFontChoice(id: "Mona Sans", displayName: "Mona Sans")
    static let geist = RunicFontChoice(id: "Geist", displayName: "Geist")
    static let commitMono = RunicFontChoice(id: "CommitMono", displayName: "Commit Mono")
    static let geistMono = RunicFontChoice(id: "Geist Mono", displayName: "Geist Mono")
    static let berkeleyMono = RunicFontChoice(id: "Berkeley Mono", displayName: "Berkeley Mono")
    static let operatorMono = RunicFontChoice(id: "Operator Mono", displayName: "Operator Mono")
    /// Licensed commercial mono face; shown only when bundled or installed on the Mac.
    static let tx02 = RunicFontChoice(id: "TX-02", displayName: "TX-02 Berkeley Mono")

    private static let hiddenBundledFamilies: Set<String> = ["VT323"]
    private static let prunedBundledFamilies: Set<String> = [
        "fira code",
        "firacode",
        "ibm plex mono",
        "jetbrains mono",
        "space mono",
    ]

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
        var choices: [RunicFontChoice] = [.monaSans, .sfPro, .sfRounded, .newYork, .sfMono]
        let bundledFamilies = Set(RunicTypography.discoverBundledFontFamilies())
        let curatedBundled: [RunicFontChoice] = [
            .geist,
            .commitMono,
            .geistMono,
            .berkeleyMono,
            .tx02,
            .operatorMono,
        ]
        for choice in curatedBundled
            where bundledFamilies.contains(choice.id) || self.isFontFamilyAvailable(choice.id)
        {
            choices.append(choice)
        }

        var seen = Set(choices.map(\.id))
        for family in bundledFamilies.sorted() {
            guard !self.hiddenBundledFamilies.contains(family) else { continue }
            guard !self.isPrunedFamily(family) else { continue }
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

    static func migratedFamily(_ storedFamily: String?) -> String {
        let trimmed = storedFamily?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return self.defaultFamily }
        guard !self.isPrunedFamily(trimmed) else { return self.defaultFamily }
        guard !self.hiddenBundledFamilies.contains(trimmed) else { return self.defaultFamily }
        guard self.availableChoices().contains(where: { $0.id == trimmed }) else { return self.defaultFamily }
        return trimmed
    }

    static func resolvedThemeFamily(_ family: String?) -> String? {
        guard let family = family?.trimmingCharacters(in: .whitespacesAndNewlines), !family.isEmpty else {
            return nil
        }
        guard !self.isPrunedFamily(family), !self.hiddenBundledFamilies.contains(family) else {
            return self.defaultFamily
        }
        return family
    }

    private static func isFontFamilyAvailable(_ family: String) -> Bool {
        NSFontManager.shared.availableMembers(ofFontFamily: family)?.isEmpty == false
    }

    private static func isPrunedFamily(_ family: String) -> Bool {
        let normalized = family.lowercased()
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        return self.prunedBundledFamilies.contains(normalized) ||
            compact.contains("jetbrainsmono") && normalized.contains("nerd font")
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

    static func applyTheme(_ palette: RunicThemePalette) {
        RunicFontStore.shared.applyTheme(palette)
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
        RunicFontStore.shared.nsFont(size: size, weight: weight)
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
