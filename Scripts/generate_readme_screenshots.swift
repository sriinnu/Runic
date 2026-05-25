#!/usr/bin/env swift

import AppKit
import Foundation

private struct Palette {
    let background: NSColor
    let surface: NSColor
    let card: NSColor
    let stroke: NSColor
    let text: NSColor
    let secondary: NSColor
    let accent: NSColor
    let warm: NSColor
    let highlight: NSColor
}

private let daybreak = Palette(
    background: NSColor.hex(0xEAF8FC),
    surface: NSColor.hex(0xF7FCFF),
    card: NSColor.hex(0xE5F7FB),
    stroke: NSColor.hex(0xA5DDE8),
    text: NSColor.hex(0x1F2937),
    secondary: NSColor.hex(0x6B7280),
    accent: NSColor.hex(0x55B8C9),
    warm: NSColor.hex(0xFF5C84),
    highlight: NSColor.hex(0xFFB000))

private let terminal = Palette(
    background: NSColor.hex(0x020806),
    surface: NSColor.hex(0x06130E),
    card: NSColor.hex(0x0B1B13),
    stroke: NSColor.hex(0x00A866),
    text: NSColor.hex(0xD7FCE8),
    secondary: NSColor.hex(0x7AB795),
    accent: NSColor.hex(0x00F082),
    warm: NSColor.hex(0xFFB42B),
    highlight: NSColor.hex(0x40DFFF))

private final class Canvas {
    let width: CGFloat
    let height: CGFloat
    let context: CGContext

    init(width: CGFloat, height: CGFloat, context: CGContext) {
        self.width = width
        self.height = height
        self.context = context
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x, y: self.height - y - height, width: width, height: height)
    }

    func fill(_ color: NSColor, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        color.setFill()
        self.rect(x, y, width, height).fill()
    }

    func rounded(
        _ color: NSColor,
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        radius: CGFloat,
        stroke: NSColor? = nil,
        lineWidth: CGFloat = 1)
    {
        let path = NSBezierPath(roundedRect: self.rect(x, y, width, height), xRadius: radius, yRadius: radius)
        color.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = lineWidth
            path.stroke()
        }
    }

    func text(
        _ value: String,
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        _ height: CGFloat,
        size: CGFloat,
        color: NSColor,
        weight: NSFont.Weight = .regular,
        monospaced: Bool = false,
        alignment: NSTextAlignment = .left)
    {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingTail
        let font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        NSString(string: value).draw(in: self.rect(x, y, width, height), withAttributes: attributes)
    }

    func circle(_ color: NSColor, centerX: CGFloat, centerY: CGFloat, radius: CGFloat) {
        color.setFill()
        NSBezierPath(ovalIn: self.rect(centerX - radius, centerY - radius, radius * 2, radius * 2)).fill()
    }

    func line(_ color: NSColor, points: [CGPoint], width: CGFloat = 3) {
        guard let first = points.first else { return }
        let path = NSBezierPath()
        path.move(to: CGPoint(x: first.x, y: self.height - first.y))
        for point in points.dropFirst() {
            path.line(to: CGPoint(x: point.x, y: self.height - point.y))
        }
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    func progress(
        _ x: CGFloat,
        _ y: CGFloat,
        _ width: CGFloat,
        percent: CGFloat,
        palette: Palette,
        tint: NSColor? = nil)
    {
        self.rounded(palette.stroke.withAlphaComponent(0.22), x, y, width, 14, radius: 7)
        self.rounded((tint ?? palette.accent).withAlphaComponent(0.85), x, y, max(12, width * percent), 14, radius: 7)
        for tick in [0.25, 0.5, 0.75] {
            self.fill(palette.surface.withAlphaComponent(0.50), x + width * tick, y + 1, 2, 12)
        }
    }

    func tab(_ title: String, _ x: CGFloat, _ y: CGFloat, width: CGFloat, selected: Bool, palette: Palette) {
        self.rounded(
            selected ? palette.accent.withAlphaComponent(0.30) : palette.surface.withAlphaComponent(0.84),
            x,
            y,
            width,
            64,
            radius: 32,
            stroke: selected ? palette.accent.withAlphaComponent(0.55) : palette.stroke.withAlphaComponent(0.35))
        self.text(title, x + 28, y + 19, width - 56, 28, size: 24, color: selected ? palette.accent : palette.secondary, weight: .semibold)
    }
}

private extension NSColor {
    static func hex(_ value: Int, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha)
    }
}

private func writeImage(
    named name: String,
    width: CGFloat,
    height: CGFloat,
    draw: (Canvas) -> Void) throws
{
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    guard let graphics = NSGraphicsContext.current else {
        image.unlockFocus()
        throw NSError(domain: "RunicScreenshots", code: 2)
    }
    draw(Canvas(width: width, height: height, context: graphics.cgContext))
    image.unlockFocus()

    let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("assets/screenshots", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "RunicScreenshots", code: 3)
    }
    try png.write(to: output.appendingPathComponent(name))
    print(output.appendingPathComponent(name).path)
}

private func drawPopover(_ c: Canvas, palette: Palette, terminalMode: Bool = false) {
    c.fill(palette.background, 0, 0, c.width, c.height)
    c.rounded(palette.surface.withAlphaComponent(0.92), 18, 18, c.width - 36, c.height - 36, radius: 30, stroke: palette.stroke.withAlphaComponent(0.45), lineWidth: 2)
    if terminalMode {
        for y in stride(from: 42, through: c.height - 42, by: 8) {
            c.fill(palette.accent.withAlphaComponent(0.04), 28, y, c.width - 56, 1)
        }
    }

    c.tab("Overview", 42, 52, width: 190, selected: false, palette: palette)
    c.tab("Codex", 252, 52, width: 180, selected: true, palette: palette)
    c.tab("Claude", 452, 52, width: 190, selected: false, palette: palette)
    c.tab("Gemini", 662, 52, width: 190, selected: false, palette: palette)

    c.rounded(palette.card, 42, 148, c.width - 84, 220, radius: 24, stroke: palette.stroke.withAlphaComponent(0.75), lineWidth: 2)
    c.circle(palette.highlight, centerX: 96, centerY: 220, radius: 26)
    c.text("/_", 78, 200, 44, 34, size: 24, color: palette.surface, weight: .bold, monospaced: true, alignment: .center)
    c.text("Codex", 150, 190, 300, 40, size: 32, color: palette.text, weight: .bold)
    c.rounded(palette.surface.withAlphaComponent(0.90), 150, 232, 230, 34, radius: 13)
    c.text("demo@runic.local", 168, 238, 200, 24, size: 18, color: palette.secondary, weight: .semibold)
    c.rounded(palette.accent.withAlphaComponent(0.18), c.width - 180, 196, 100, 44, radius: 14, stroke: palette.accent.withAlphaComponent(0.28))
    c.text("Pro", c.width - 146, 204, 54, 28, size: 22, color: palette.accent, weight: .bold)
    c.text("Updated just now", 62, 284, 300, 32, size: 22, color: palette.secondary, weight: .semibold)
    c.text("Top model: gpt-5.5 - 1.4B tokens - 5516 req - ctx 400K", 62, 330, c.width - 124, 28, size: 20, color: palette.secondary, weight: .medium)

    c.rounded(palette.surface.withAlphaComponent(0.72), 42, 398, c.width - 84, 148, radius: 16, stroke: palette.stroke.withAlphaComponent(0.35))
    c.text("Session", 70, 426, 200, 30, size: 22, color: palette.secondary, weight: .semibold)
    c.text("Resets in 32m", c.width - 260, 426, 190, 30, size: 20, color: palette.secondary, weight: .medium, alignment: .right)
    c.progress(70, 474, c.width - 140, percent: 0.02, palette: palette)
    c.text("0% used", 70, 504, 160, 30, size: 22, color: palette.text, weight: .bold)

    c.rounded(palette.surface.withAlphaComponent(0.72), 42, 578, c.width - 84, 170, radius: 16, stroke: palette.stroke.withAlphaComponent(0.35))
    c.text("Weekly", 70, 608, 200, 30, size: 22, color: palette.secondary, weight: .semibold)
    c.text("Resets in 4d 11h", c.width - 290, 608, 220, 30, size: 20, color: palette.secondary, weight: .medium, alignment: .right)
    c.progress(70, 656, c.width - 140, percent: 0.06, palette: palette)
    c.text("2% used", 70, 686, 160, 30, size: 22, color: palette.text, weight: .bold)
    c.text("Pace: Behind (-34%) - Lasts to reset", 70, 722, 380, 26, size: 18, color: palette.secondary, weight: .medium)

    c.rounded(palette.surface.withAlphaComponent(0.88), 42, 786, c.width - 84, 610, radius: 24, stroke: palette.stroke.withAlphaComponent(0.38))
    c.text("Explore", 70, 814, 180, 28, size: 22, color: palette.secondary, weight: .bold)
    let chips = ["Timeline", "Today", "7 days", "Utilization", "Windows", "Projects", "Models"]
    for (index, chip) in chips.enumerated() {
        let col = index % 2
        let row = index / 2
        let x = CGFloat(70 + col * 395)
        let y = CGFloat(870 + row * 72)
        c.rounded(index == 0 ? palette.warm.withAlphaComponent(0.18) : palette.card, x, y, 360, 50, radius: 12, stroke: index == 0 ? palette.warm : palette.stroke.withAlphaComponent(0.35))
        c.text(chip, x + 28, y + 13, 280, 28, size: 22, color: index == 0 ? palette.warm : palette.text, weight: .semibold)
    }
    c.text("Timeline", 70, 1128, 180, 30, size: 26, color: palette.text, weight: .bold)
    c.rounded(palette.card.withAlphaComponent(0.8), 70, 1170, c.width - 140, 60, radius: 14, stroke: palette.stroke.withAlphaComponent(0.30))
    for (i, label) in ["3d", "7d", "30d", "90d", "1y"].enumerated() {
        let x = CGFloat(90 + i * 145)
        if label == "7d" {
            c.rounded(palette.surface, x - 12, 1176, 110, 48, radius: 13, stroke: palette.stroke.withAlphaComponent(0.55))
        }
        c.text(label, x, 1186, 82, 30, size: 25, color: palette.text, weight: .medium, alignment: .center)
    }
    let points = [
        CGPoint(x: 88, y: 1320), CGPoint(x: 210, y: 1284), CGPoint(x: 330, y: 1304),
        CGPoint(x: 450, y: 1238), CGPoint(x: 570, y: 1286), CGPoint(x: 690, y: 1188),
        CGPoint(x: 800, y: 1218),
    ]
    c.line(palette.accent, points: points, width: 5)
    c.line(palette.warm, points: points.enumerated().map { CGPoint(x: $0.element.x, y: $0.element.y - CGFloat($0.offset) * 8) }, width: 4)
}

private func drawSettingsProviders(_ c: Canvas) {
    let palette = daybreak
    c.fill(NSColor.hex(0xDDF5FA), 0, 0, c.width, c.height)
    c.rounded(palette.surface, 28, 28, c.width - 56, c.height - 56, radius: 26, stroke: palette.stroke.withAlphaComponent(0.65), lineWidth: 2)
    c.rounded(NSColor.white.withAlphaComponent(0.68), 54, 70, 230, c.height - 140, radius: 18, stroke: palette.stroke.withAlphaComponent(0.30))
    c.text("Runic", 84, 100, 160, 40, size: 30, color: palette.text, weight: .bold)
    for (i, item) in ["General", "Providers", "Analytics", "Budgets", "Advanced"].enumerated() {
        let y = CGFloat(168 + i * 62)
        c.rounded(item == "Providers" ? palette.accent.withAlphaComponent(0.22) : NSColor.clear, 74, y, 180, 44, radius: 12)
        c.text(item, 96, y + 10, 140, 24, size: 18, color: item == "Providers" ? palette.accent : palette.secondary, weight: .semibold)
    }

    c.text("Providers", 330, 84, 260, 40, size: 34, color: palette.text, weight: .bold)
    c.text("Enable providers and manage credentials. Demo data shown.", 330, 126, 520, 26, size: 17, color: palette.secondary)
    let providers = ["Codex", "Claude", "Gemini", "DeepSeek", "Vercel AI", "MiniMax"]
    for (i, provider) in providers.enumerated() {
        let col = i % 2
        let row = i / 2
        let x = CGFloat(330 + col * 360)
        let y = CGFloat(184 + row * 150)
        c.rounded(palette.card, x, y, 330, 120, radius: 18, stroke: palette.stroke.withAlphaComponent(0.55))
        c.circle(i < 3 ? palette.accent : palette.highlight, centerX: x + 42, centerY: y + 42, radius: 18)
        c.text(provider, x + 74, y + 28, 180, 28, size: 22, color: palette.text, weight: .bold)
        c.text(i < 3 ? "Connected" : "Needs credentials", x + 74, y + 62, 190, 24, size: 16, color: i < 3 ? palette.accent : palette.warm, weight: .semibold)
        c.rounded(i < 3 ? palette.accent : palette.surface, x + 250, y + 34, 48, 26, radius: 13, stroke: palette.stroke.withAlphaComponent(0.35))
    }
    c.rounded(palette.surface.withAlphaComponent(0.78), 330, 660, c.width - 390, 150, radius: 18, stroke: palette.stroke.withAlphaComponent(0.45))
    c.text("Credential storage", 360, 690, 260, 30, size: 24, color: palette.text, weight: .bold)
    c.text("API keys are stored in macOS Keychain. Browser-backed providers reuse local sessions and may require provider re-login when sessions expire.", 360, 732, c.width - 460, 52, size: 17, color: palette.secondary)
}

private func drawSettingsThemes(_ c: Canvas) {
    let palette = daybreak
    c.fill(NSColor.hex(0xF3FBFD), 0, 0, c.width, c.height)
    c.rounded(palette.surface, 28, 28, c.width - 56, c.height - 56, radius: 26, stroke: palette.stroke.withAlphaComponent(0.60), lineWidth: 2)
    c.text("Appearance", 70, 74, 300, 40, size: 34, color: palette.text, weight: .bold)
    c.text("Themes and fonts preview live before you close settings.", 70, 118, 540, 26, size: 17, color: palette.secondary)
    let themes: [(String, NSColor, NSColor)] = [
        ("Retro", NSColor.hex(0x3B5BA5), NSColor.hex(0xF2E9D4)),
        ("System", NSColor.hex(0x5B7CFA), NSColor.hex(0xF4F6F8)),
        ("Light", NSColor.hex(0x2670EB), NSColor.hex(0xF6F8FB)),
        ("Dark", NSColor.hex(0x8CCCFF), NSColor.hex(0x06080B)),
        ("Daybreak", daybreak.accent, daybreak.surface),
        ("Glass", NSColor.hex(0x6FE8FF), NSColor.hex(0xEAFBFF)),
        ("Terminal", terminal.accent, terminal.background),
    ]
    for (i, item) in themes.enumerated() {
        let col = i % 3
        let row = i / 3
        let x = CGFloat(70 + col * 330)
        let y = CGFloat(180 + row * 170)
        c.rounded(item.2, x, y, 290, 130, radius: 20, stroke: item.0 == "Daybreak" ? item.1 : palette.stroke.withAlphaComponent(0.45), lineWidth: item.0 == "Daybreak" ? 3 : 1)
        c.circle(item.1, centerX: x + 44, centerY: y + 42, radius: 18)
        let darkTile = ["Terminal", "Dark"].contains(item.0)
        c.text(item.0, x + 76, y + 30, 170, 28, size: 22, color: darkTile ? NSColor.hex(0xD7FCE8) : palette.text, weight: .bold)
        c.text("Aa 123 - preview", x + 28, y + 80, 230, 26, size: 17, color: darkTile ? terminal.secondary : palette.secondary, monospaced: item.0 == "Terminal")
    }

    c.rounded(palette.card, 70, 700, c.width - 140, 210, radius: 22, stroke: palette.stroke.withAlphaComponent(0.45))
    c.text("Fonts", 104, 736, 200, 30, size: 26, color: palette.text, weight: .bold)
    let fonts = ["Mona Sans", "SF Pro", "SF Rounded", "New York", "SF Mono", "Geist", "Commit Mono", "Geist Mono"]
    for (i, font) in fonts.enumerated() {
        let x = CGFloat(104 + (i % 4) * 230)
        let y = CGFloat(792 + (i / 4) * 62)
        c.rounded(NSColor.white.withAlphaComponent(0.55), x, y, 190, 46, radius: 13, stroke: palette.stroke.withAlphaComponent(0.28))
        c.text(font, x + 18, y + 12, 154, 24, size: 17, color: palette.text, weight: .semibold, monospaced: font.contains("Mono") || font == "Menlo")
    }
}

try writeImage(named: "menubar-daybreak.png", width: 900, height: 1440) { canvas in
    drawPopover(canvas, palette: daybreak)
}

try writeImage(named: "menubar-terminal.png", width: 900, height: 1440) { canvas in
    drawPopover(canvas, palette: terminal, terminalMode: true)
}

try writeImage(named: "settings-providers.png", width: 1120, height: 860) { canvas in
    drawSettingsProviders(canvas)
}

try writeImage(named: "settings-themes.png", width: 1120, height: 980) { canvas in
    drawSettingsThemes(canvas)
}
