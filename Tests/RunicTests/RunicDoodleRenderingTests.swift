import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Runic

/// Render-sanity coverage for the character layer: the lemniscate menubar
/// glyph and the Runi mascot doodles.
@MainActor
struct RunicDoodleRenderingTests {
    // MARK: - Menubar glyph

    @Test
    func `menubar glyph is a single continuous lemniscate path`() throws {
        let url = try Self.menubarIconURL()
        let source = try String(contentsOf: url, encoding: .utf8)

        #expect(source.contains("viewBox=\"0 0 38 22\""), "Glyph must keep the 38x22 canvas IconRenderer expects")
        #expect(source.components(separatedBy: "<path").count == 2, "Glyph must be one continuous path")
        #expect(!source.contains("<ellipse"), "Glyph must not regress to disjoint circles (reads as 'oo')")
        #expect(source.contains("currentColor"), "Glyph must stay template-tintable")
        #expect(
            !source.contains("<linearGradient") && !source.contains("<radialGradient") && !source.contains("url(#"),
            "Glyph must stay a solid fillable stroke for the sourceIn reveal")
    }

    @Test
    func `menubar glyph renders with an opaque center crossover`() throws {
        let url = try Self.menubarIconURL()
        let image = try #require(NSImage(contentsOf: url), "Menubar SVG must load through NSImage")

        let width = 76
        let height = 44
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        var visible = 0
        for y in 0..<height {
            for x in 0..<width where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                visible += 1
            }
        }
        #expect(visible > 400, "Glyph rendered too faint or empty")

        // The crossover: the previous two-circle mark left a hollow gap at the
        // center; a true lemniscate strokes straight through it.
        var centerVisible = 0
        for y in (height / 2 - 6)..<(height / 2 + 6) {
            for x in (width / 2 - 2)...(width / 2 + 2)
                where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5
            {
                centerVisible += 1
            }
        }
        #expect(centerVisible > 4, "Lemniscate must cross at the center so the mark reads as ∞")
    }

    // MARK: - Runi doodles

    @Test
    func `runi doodle renders visibly at menu sizes in light and dark themes`() throws {
        let moods: [RunicDoodle.Mood] = [.resting, .searching, .tangled, .zen]
        for theme in [Theme.light, Theme.dark] {
            let palette = theme.palette
            for mood in moods {
                for size in [CGFloat(44), CGFloat(76)] {
                    let art = RunicDoodleArt(
                        mood: mood,
                        bodyColor: palette.accent,
                        eyeColor: palette.primaryText,
                        detailColor: palette.secondaryText.opacity(0.55))
                        .frame(width: size, height: size * 0.6)
                    let visible = try Self.visiblePixelCount(of: art)
                    #expect(
                        visible > Int(size * 4),
                        "Runi \(mood) should render visibly at \(Int(size))pt in \(theme.rawValue) theme")
                }
            }
        }
    }

    @Test
    func `runi moods draw distinct artwork`() throws {
        // Cheap distinctness guard: each mood's ink coverage should differ —
        // catching a regression where every mood falls back to the same body.
        var coverage: [Int] = []
        let palette = Theme.light.palette
        for mood in [RunicDoodle.Mood.resting, .searching, .tangled, .zen] {
            let art = RunicDoodleArt(
                mood: mood,
                bodyColor: palette.accent,
                eyeColor: palette.primaryText,
                detailColor: palette.secondaryText.opacity(0.55))
                .frame(width: 76, height: 76 * 0.6)
            try coverage.append(Self.visiblePixelCount(of: art))
        }
        #expect(Set(coverage).count == coverage.count, "Each mood should produce distinct artwork: \(coverage)")
    }

    // MARK: - Helpers

    private static func visiblePixelCount(of view: some View) throws -> Int {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage, "Doodle failed to render")
        let tiff = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiff))
        var visible = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.15 {
                visible += 1
            }
        }
        return visible
    }

    private static func menubarIconURL() throws -> URL {
        let root = try Self.repoRoot()
        return root.appending(path: "Sources/Runic/Resources/RunicMenubarIcon.svg")
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
        throw NSError(domain: "RunicDoodleRenderingTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not locate repo root (Package.swift) from \(#filePath)",
        ])
    }
}
