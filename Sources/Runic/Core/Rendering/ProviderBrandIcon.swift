import AppKit
import RunicCore

@MainActor
enum ProviderBrandIcon {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for provider: UsageProvider, size: CGFloat = 16) -> NSImage? {
        let cacheSize = Int(size.rounded())
        let key = "\(provider.rawValue)-\(cacheSize)" as NSString
        if let cached = self.cache.object(forKey: key) {
            return cached
        }

        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let url = Bundle.main.url(forResource: baseName, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        let targetSize = NSSize(width: size, height: size)
        image.size = targetSize
        image.isTemplate = true
        let tinted = self.tintedImage(image, color: self.brandColor(for: provider), size: targetSize)
        self.cache.setObject(tinted, forKey: key)
        return tinted
    }

    static func templateImage(for provider: UsageProvider, size: CGFloat = 16) -> NSImage? {
        let cacheSize = Int(size.rounded())
        let key = "\(provider.rawValue)-\(cacheSize)-template" as NSString
        if let cached = self.cache.object(forKey: key) {
            return cached
        }

        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let url = Bundle.main.url(forResource: baseName, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        self.cache.setObject(image, forKey: key)
        return image
    }

    private static func brandColor(for provider: UsageProvider) -> NSColor {
        let color = ProviderDescriptorRegistry.descriptor(for: provider).branding.color
        return NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: 1)
    }

    private static func tintedImage(_ image: NSImage, color: NSColor, size: NSSize) -> NSImage {
        let rect = NSRect(origin: .zero, size: size)
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        color.setFill()
        rect.fill()
        image.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1.0)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}
