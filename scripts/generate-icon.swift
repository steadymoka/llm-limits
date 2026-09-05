#!/usr/bin/env swift

import Cocoa

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    print("Failed to create bitmap")
    exit(1)
}
bitmap.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// Background — compact, terminal-inspired dark tile.
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 220, yRadius: 220)
NSColor(red: 0.055, green: 0.065, blue: 0.075, alpha: 1.0).setFill()
bgPath.fill()

// Gradient overlay
let gradientRect = NSRect(x: 0, y: 0, width: size, height: size)
let gradient = NSGradient(
    starting: NSColor(red: 0.0, green: 0.62, blue: 0.48, alpha: 0.34),
    ending: NSColor(red: 0.20, green: 0.34, blue: 0.68, alpha: 0.16)
)!
let gradientPath = NSBezierPath(roundedRect: gradientRect, xRadius: 220, yRadius: 220)
gradient.draw(in: gradientPath, angle: -45)

// Terminal panel
let panelRect = NSRect(x: 155, y: 265, width: 714, height: 500)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 72, yRadius: 72)
NSColor(red: 0.03, green: 0.04, blue: 0.05, alpha: 0.72).setFill()
panel.fill()
NSColor.white.withAlphaComponent(0.12).setStroke()
panel.lineWidth = 5
panel.stroke()

// Window controls
for (index, color) in [
    NSColor(red: 0.95, green: 0.35, blue: 0.32, alpha: 0.9),
    NSColor(red: 0.96, green: 0.69, blue: 0.25, alpha: 0.9),
    NSColor(red: 0.30, green: 0.76, blue: 0.43, alpha: 0.9),
].enumerated() {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 215 + CGFloat(index * 54), y: 686, width: 26, height: 26)).fill()
}

// Prompt glyph
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 285, weight: .bold),
    .foregroundColor: NSColor(red: 0.38, green: 0.92, blue: 0.68, alpha: 1.0)
]
let prompt = ">_"
let promptSize = prompt.size(withAttributes: attrs)
let promptPoint = NSPoint(
    x: (CGFloat(size) - promptSize.width) / 2,
    y: 350
)
prompt.draw(at: promptPoint, withAttributes: attrs)

// Product monogram
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 112, weight: .semibold),
    .kern: 12,
    .foregroundColor: NSColor.white.withAlphaComponent(0.84)
]
let text = "LLM"
let textSize = text.size(withAttributes: textAttrs)
let textPoint = NSPoint(
    x: (CGFloat(size) - textSize.width) / 2,
    y: 105
)
text.draw(at: textPoint, withAttributes: textAttrs)

NSGraphicsContext.restoreGraphicsState()

// Save as PNG
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to generate image")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_1024.png"

try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Icon saved to \(outputPath)")
