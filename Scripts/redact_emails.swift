#!/usr/bin/env swift

// Redacts email addresses in PNG screenshots and overlays a placeholder in
// their place. Uses Vision OCR (VNRecognizeTextRequest) to find email-shaped
// text, samples the surrounding background to paint over the original, then
// renders the replacement in roughly-matched typography.
//
// Usage:
//   redact_emails.swift <placeholder> <png> [<png> ...]
//
// Example:
//   ./Scripts/redact_emails.swift demo@runic.app assets/screenshots/*.png

import AppKit
import CoreImage
import Foundation
import Vision

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write("usage: redact_emails.swift <placeholder> <png> [<png> ...]\n".data(using: .utf8)!)
    exit(2)
}

let placeholder = CommandLine.arguments[1]
let paths = Array(CommandLine.arguments.dropFirst(2))

// Anything that looks like an address: non-whitespace, at-sign, non-whitespace,
// dot, non-whitespace. Loose on purpose so it catches truncations and weird
// fonts after OCR.
let emailRegex = try NSRegularExpression(
    pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)

func loadCGImage(from url: URL) -> CGImage? {
    guard let data = try? Data(contentsOf: url),
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    return image
}

struct EmailHit {
    let rect: CGRect
    let originalText: String
}

func findEmails(in image: CGImage) -> [EmailHit] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])

    var hits: [EmailHit] = []
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)

    for observation in request.results ?? [] {
        let candidates = observation.topCandidates(1)
        guard let candidate = candidates.first else { continue }
        let text = candidate.string

        let matches = emailRegex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text))

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let matchedString = String(text[range])
            // Vision lets us get the rect of an arbitrary substring; fall back
            // to the line's overall box when the per-substring lookup fails.
            let perRange = try? candidate.boundingBox(for: range)
            let normalized = perRange?.boundingBox ?? observation.boundingBox
            // Vision uses bottom-left origin in [0..1] coords; convert.
            let rect = CGRect(
                x: normalized.origin.x * width,
                y: (1.0 - normalized.origin.y - normalized.height) * height,
                width: normalized.width * width,
                height: normalized.height * height)
            hits.append(EmailHit(rect: rect, originalText: matchedString))
        }
    }
    return hits
}

// Sample the dominant color in a thin strip just outside `rect` so we can
// fill the redacted box without an obvious seam.
func sampleBackgroundColor(in image: CGImage, around rect: CGRect, pad: CGFloat = 4) -> NSColor {
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)

    let samples = [
        CGPoint(x: rect.minX - pad, y: rect.midY),
        CGPoint(x: rect.maxX + pad, y: rect.midY),
        CGPoint(x: rect.midX, y: rect.minY - pad),
        CGPoint(x: rect.midX, y: rect.maxY + pad),
    ]

    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, n: CGFloat = 0
    for point in samples {
        let px = max(0, min(width - 1, point.x))
        let py = max(0, min(height - 1, point.y))
        if let color = pixelColor(in: image, x: Int(px), y: Int(py)) {
            r += color.redComponent
            g += color.greenComponent
            b += color.blueComponent
            n += 1
        }
    }
    guard n > 0 else { return .black }
    return NSColor(red: r / n, green: g / n, blue: b / n, alpha: 1)
}

func sampleTextColor(in image: CGImage, around rect: CGRect, background: NSColor) -> NSColor {
    // Walk the email rect, pick the pixel whose luminance is farthest from
    // the background. That's almost certainly text glyph.
    let stepX = max(1, Int(rect.width / 20))
    let stepY = max(1, Int(rect.height / 6))
    let bgLum = 0.299 * background.redComponent + 0.587 * background.greenComponent + 0.114 * background.blueComponent

    var best: NSColor = background
    var bestDelta: CGFloat = 0
    for x in stride(from: Int(rect.minX), to: Int(rect.maxX), by: stepX) {
        for y in stride(from: Int(rect.minY), to: Int(rect.maxY), by: stepY) {
            guard let color = pixelColor(in: image, x: x, y: y) else { continue }
            let lum = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
            let delta = abs(lum - bgLum)
            if delta > bestDelta {
                bestDelta = delta
                best = color
            }
        }
    }
    return best
}

func pixelColor(in image: CGImage, x: Int, y: Int) -> NSColor? {
    guard x >= 0, x < image.width, y >= 0, y < image.height else { return nil }
    let space = CGColorSpaceCreateDeviceRGB()
    var pixel: [UInt8] = [0, 0, 0, 0]
    guard let context = CGContext(
        data: &pixel,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
    return NSColor(
        red: CGFloat(pixel[0]) / 255,
        green: CGFloat(pixel[1]) / 255,
        blue: CGFloat(pixel[2]) / 255,
        alpha: 1)
}

func redact(image: CGImage, hits: [EmailHit], placeholder: String) -> CGImage? {
    let width = image.width
    let height = image.height
    let space = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    // Work in the CGContext's native bottom-left coords; flip each hit's Y so
    // we don't have to mirror the whole canvas (which would also mirror text).
    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsContext

    for hit in hits {
        let bgColor = sampleBackgroundColor(in: image, around: hit.rect)
        let textColor = sampleTextColor(in: image, around: hit.rect, background: bgColor)

        // Convert top-left rect to bottom-left, then pad slightly to wipe
        // aliased edges from the original glyphs.
        let flippedY = CGFloat(height) - hit.rect.maxY
        let drawnRect = CGRect(x: hit.rect.minX, y: flippedY, width: hit.rect.width, height: hit.rect.height)
        let fill = drawnRect.insetBy(dx: -2, dy: -2)
        bgColor.setFill()
        NSBezierPath(rect: fill).fill()

        // Match SF's body height by sizing the font to ~80% of the OCR rect.
        let fontSize = max(8, hit.rect.height * 0.78)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
        ]
        let attributed = NSAttributedString(string: placeholder, attributes: attrs)
        let measured = attributed.size()
        let textY = flippedY + (hit.rect.height - measured.height) / 2
        let textRect = CGRect(
            x: hit.rect.minX,
            y: textY,
            width: max(hit.rect.width, measured.width),
            height: measured.height)
        attributed.draw(in: textRect)
    }

    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "redact", code: 1)
    }
    try data.write(to: url)
}

var anyHits = false
for path in paths {
    let url = URL(fileURLWithPath: path)
    guard let image = loadCGImage(from: url) else {
        FileHandle.standardError.write("skip: cannot read \(path)\n".data(using: .utf8)!)
        continue
    }
    let hits = findEmails(in: image)
    if hits.isEmpty {
        print("\(path): no emails detected")
        continue
    }
    anyHits = true
    print("\(path): found \(hits.count) email(s):")
    for hit in hits {
        print("  - \(hit.originalText) at \(hit.rect)")
    }
    guard let redacted = redact(image: image, hits: hits, placeholder: placeholder) else {
        FileHandle.standardError.write("redact failed for \(path)\n".data(using: .utf8)!)
        continue
    }
    do {
        try writePNG(redacted, to: url)
        print("  wrote \(path)")
    } catch {
        FileHandle.standardError.write("write failed for \(path): \(error)\n".data(using: .utf8)!)
    }
}

if !anyHits {
    print("no emails detected in any input")
}
