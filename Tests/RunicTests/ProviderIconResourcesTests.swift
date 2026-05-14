import AppKit
import Foundation
import RunicCore
import Testing

@MainActor
struct ProviderIconResourcesTests {
    @Test
    func `provider icon SVGs exist`() throws {
        let root = try Self.repoRoot()
        let resources = root.appending(path: "Sources/Runic/Resources", directoryHint: .isDirectory)

        for descriptor in ProviderDescriptorRegistry.all {
            let resource = descriptor.branding.iconResourceName
            let url = resources.appending(path: "\(resource).svg")
            #expect(
                FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                "Missing SVG for \(descriptor.id.rawValue)")

            let data = try Data(contentsOf: url)
            #expect(data.count < 32_768, "Provider SVG is too large for menu rendering: \(descriptor.id.rawValue)")
            let source = String(decoding: data, as: UTF8.self)
            #expect(source.contains("<svg"), "Provider SVG must contain an SVG root: \(descriptor.id.rawValue)")
            #expect(source.contains("viewBox=\"0 0 24 24\""), "Provider SVG must use the brand-mark icon grid: \(descriptor.id.rawValue)")
            #expect(
                !source.contains("<rect x=\"0\"") && !source.contains("viewBox=\"0 0 64 64\""),
                "Provider SVG must not include an outer icon plate: \(descriptor.id.rawValue)")

            let image = NSImage(contentsOf: url)
            #expect(image != nil, "Could not load SVG as NSImage for \(descriptor.id.rawValue)")
        }
    }

    @Test
    func `gemini icon renders visibly through appkit data path`() throws {
        let root = try Self.repoRoot()
        let url = root.appending(path: "Sources/Runic/Resources/ProviderIcon-gemini.svg")
        let data = try Data(contentsOf: url)
        let image = try #require(NSImage(data: data), "Gemini SVG must render through NSImage(data:)")
        let rendered = NSImage(size: NSSize(width: 64, height: 64))

        rendered.lockFocus()
        image.draw(in: NSRect(x: 8, y: 8, width: 48, height: 48))
        rendered.unlockFocus()

        let tiff = try #require(rendered.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        var visiblePixels = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.15 {
                    visiblePixels += 1
                }
            }
        }

        #expect(visiblePixels > 500, "Gemini icon rendered too small or invisible through AppKit SVG rasterization")
    }

    private static func repoRoot() throws -> URL {
        var dir = URL(filePath: #filePath).deletingLastPathComponent()
        for _ in 0..<12 {
            let candidate = dir.appending(path: "Package.swift")
            if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return dir
            }
            dir.deleteLastPathComponent()
        }
        throw NSError(domain: "ProviderIconResourcesTests", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not locate repo root (Package.swift) from \(#filePath)",
        ])
    }
}
