import AppKit
import RunicCore

@MainActor
enum ProviderBrandIcon {
    private static let cache = NSCache<NSString, NSImage>()

    /// Brand-color mark for the provider, adapted to the target appearance.
    /// Near-black brands (xAI's #141414) are lifted to a readable tone on
    /// dark backgrounds; near-white brands are grounded on light ones.
    /// `prefersDark` defaults to the app's effective appearance.
    static func image(for provider: UsageProvider, size: CGFloat = 16, prefersDark: Bool? = nil) -> NSImage? {
        let dark = prefersDark ?? Self.systemPrefersDark
        let cacheSize = Int(size.rounded())
        let key = "\(provider.rawValue)-\(cacheSize)-brand-mark-v3-\(dark ? "dark" : "light")" as NSString
        if let cached = self.cache.object(forKey: key) {
            return cached
        }

        guard let image = self.loadBrandColorMark(for: provider, size: size, prefersDark: dark) else {
            return nil
        }

        self.cache.setObject(image, forKey: key)
        return image
    }

    private static var systemPrefersDark: Bool {
        NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func loadBrandColorMark(
        for provider: UsageProvider,
        size: CGFloat,
        prefersDark: Bool) -> NSImage?
    {
        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let url = Self.resourceURL(named: baseName),
              let source = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        let brandHex = Self.resolvedBrandHex(for: provider, prefersDark: prefersDark)
        var coloredSource = source
        let replacements = [
            (#"stroke="black""#, #"stroke="\#(brandHex)""#),
            (#"fill="black""#, #"fill="\#(brandHex)""#),
            (#"stroke="currentColor""#, #"stroke="\#(brandHex)""#),
            (#"fill="currentColor""#, #"fill="\#(brandHex)""#),
            ("stroke=\"#000\"", "stroke=\"\(brandHex)\""),
            ("fill=\"#000\"", "fill=\"\(brandHex)\""),
            ("stroke=\"#000000\"", "stroke=\"\(brandHex)\""),
            ("fill=\"#000000\"", "fill=\"\(brandHex)\""),
            ("stroke='black'", "stroke='\(brandHex)'"),
            ("fill='black'", "fill='\(brandHex)'"),
            ("stroke='currentColor'", "stroke='\(brandHex)'"),
            ("fill='currentColor'", "fill='\(brandHex)'"),
        ]
        for (target, replacement) in replacements {
            coloredSource = coloredSource.replacingOccurrences(of: target, with: replacement)
        }

        guard let data = coloredSource.data(using: .utf8),
              let image = NSImage(data: data)
        else {
            return nil
        }

        image.size = NSSize(width: size, height: size)
        image.isTemplate = false
        return image
    }

    private static func resourceURL(named baseName: String) -> URL? {
        RunicResourceLocator.url(forResource: baseName, withExtension: "svg")
    }

    /// Brand hex after the appearance-readability guard. Internal (not
    /// private) so tests can assert the resolved tint per appearance.
    static func resolvedBrandHex(for provider: UsageProvider, prefersDark: Bool) -> String {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        let (red, green, blue) = Self.readableComponents(
            red: color.red,
            green: color.green,
            blue: color.blue,
            prefersDark: prefersDark)
        return String(
            format: "#%02X%02X%02X",
            Self.channelByte(red),
            Self.channelByte(green),
            Self.channelByte(blue))
    }

    /// Luminance guard: near-black marks vanish on dark surfaces and
    /// near-white marks vanish on light ones. Blend those extremes toward
    /// the opposing pole while leaving genuinely colorful brands untouched.
    private static func readableComponents(
        red: Double,
        green: Double,
        blue: Double,
        prefersDark: Bool) -> (Double, Double, Double)
    {
        let luminance = Self.relativeLuminance(red: red, green: green, blue: blue)
        if prefersDark, luminance < 0.05 {
            let lift = 0.88
            return (red + (1 - red) * lift, green + (1 - green) * lift, blue + (1 - blue) * lift)
        }
        if !prefersDark, luminance > 0.85 {
            let drop = 0.88
            return (red * (1 - drop), green * (1 - drop), blue * (1 - drop))
        }
        return (red, green, blue)
    }

    private static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    private static func channelByte(_ value: Double) -> Int {
        max(0, min(255, Int((value * 255).rounded())))
    }
}
