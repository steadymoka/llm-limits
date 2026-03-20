#!/usr/bin/env swift

import Cocoa

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

// Background - dark rounded rect
let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 220, yRadius: 220)
NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).setFill()
bgPath.fill()

// Gradient overlay
let gradientRect = NSRect(x: 0, y: 0, width: size, height: size)
let gradient = NSGradient(
    starting: NSColor(red: 0.0, green: 0.55, blue: 0.35, alpha: 0.3),
    ending: NSColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 0.15)
)!
let gradientPath = NSBezierPath(roundedRect: gradientRect, xRadius: 220, yRadius: 220)
gradient.draw(in: gradientPath, angle: -45)

// Sparkle symbol
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 420, weight: .medium),
    .foregroundColor: NSColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1.0)
]
let sparkle = "✦"
let sparkleSize = sparkle.size(withAttributes: attrs)
let sparklePoint = NSPoint(
    x: (CGFloat(size) - sparkleSize.width) / 2,
    y: (CGFloat(size) - sparkleSize.height) / 2 + 60
)
sparkle.draw(at: sparklePoint, withAttributes: attrs)

// "cc" text
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 180, weight: .bold),
    .foregroundColor: NSColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 0.9)
]
let text = "cc"
let textSize = text.size(withAttributes: textAttrs)
let textPoint = NSPoint(
    x: (CGFloat(size) - textSize.width) / 2,
    y: 100
)
text.draw(at: textPoint, withAttributes: textAttrs)

image.unlockFocus()

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to generate image")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_1024.png"

try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Icon saved to \(outputPath)")
