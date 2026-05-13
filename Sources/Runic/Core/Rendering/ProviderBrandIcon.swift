import AppKit
import RunicCore

@MainActor
enum ProviderBrandIcon {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for provider: UsageProvider, size: CGFloat = 16) -> NSImage? {
        let cacheSize = Int(size.rounded())
        let key = "\(provider.rawValue)-\(cacheSize)-brand-mark-v2" as NSString
        if let cached = self.cache.object(forKey: key) {
            return cached
        }

        guard let image = self.loadBrandColorMark(for: provider, size: size) else {
            return nil
        }

        self.cache.setObject(image, forKey: key)
        return image
    }

    static func templateImage(for provider: UsageProvider, size: CGFloat = 16) -> NSImage? {
        let cacheSize = Int(size.rounded())
        let key = "\(provider.rawValue)-\(cacheSize)-template-mark-v1" as NSString
        if let cached = self.cache.object(forKey: key) {
            return cached
        }

        guard let image = self.loadTemplateMark(for: provider, size: size) else {
            return nil
        }

        self.cache.setObject(image, forKey: key)
        return image
    }

    private static func loadTemplateMark(for provider: UsageProvider, size: CGFloat) -> NSImage? {
        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let url = Self.resourceURL(named: baseName),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }

    private static func loadBrandColorMark(for provider: UsageProvider, size: CGFloat) -> NSImage? {
        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let url = Self.resourceURL(named: baseName),
              let source = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }

        let brandHex = Self.brandHexColor(for: provider)
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
        Bundle.main.url(forResource: baseName, withExtension: "svg")
            ?? Bundle.main.url(forResource: baseName, withExtension: "svg", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: baseName, withExtension: "svg")
            ?? Bundle.module.url(forResource: baseName, withExtension: "svg", subdirectory: "Resources")
    }

    private static func brandHexColor(for provider: UsageProvider) -> String {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        let red = max(0, min(255, Int((color.red * 255).rounded())))
        let green = max(0, min(255, Int((color.green * 255).rounded())))
        let blue = max(0, min(255, Int((color.blue * 255).rounded())))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
