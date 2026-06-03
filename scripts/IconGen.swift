// usage: swift scripts/IconGen.swift <out.png> <size>
// Renders a 1024×1024 (or any size) Vibe Vault app icon as PNG.
// HIG-flavoured: rounded squircle, accent gradient, monochrome key glyph.
import AppKit
import CoreGraphics
import CoreText
import Foundation

let args = CommandLine.arguments
guard args.count >= 3, let size = Int(args[2]) else {
    FileHandle.standardError.write(Data("usage: swift IconGen.swift <out.png> <size>\n".utf8))
    exit(64)
}
let outPath = args[1]
let s = CGFloat(size)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

// Background: rounded squircle (~22% radius, Apple icon mask).
let bg = CGRect(x: 0, y: 0, width: s, height: s)
let r = s * 0.2237
let path = CGPath(roundedRect: bg, cornerWidth: r, cornerHeight: r, transform: nil)
ctx.addPath(path)
ctx.clip()

// Vertical gradient: #6D28D9 -> #7C3AED -> #A855F7
let colors = [
    CGColor(red: 0x6D/255, green: 0x28/255, blue: 0xD9/255, alpha: 1),
    CGColor(red: 0x7C/255, green: 0x3A/255, blue: 0xED/255, alpha: 1),
    CGColor(red: 0xA8/255, green: 0x55/255, blue: 0xF7/255, alpha: 1)
] as CFArray
let stops: [CGFloat] = [0.0, 0.55, 1.0]
let grad = CGGradient(colorsSpace: cs, colors: colors, locations: stops)!
ctx.drawLinearGradient(
    grad,
    start: CGPoint(x: 0, y: s),
    end: CGPoint(x: s, y: 0),
    options: []
)

// Subtle inner highlight (top sheen)
ctx.saveGState()
let sheenColors = [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.28),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0)
] as CFArray
let sheen = CGGradient(colorsSpace: cs, colors: sheenColors, locations: [0, 1])!
ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: s * 0.55), options: [])
ctx.restoreGState()

// Key glyph — SF Symbols rendered into the bitmap.
let glyphSize = s * 0.58
let symbolConfig = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .semibold, scale: .large)
if let img = NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(symbolConfig) {
    let imgRect = NSRect(
        x: (s - img.size.width) / 2,
        y: (s - img.size.height) / 2,
        width: img.size.width, height: img.size.height
    )
    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = gctx
    // Drop shadow
    let shadow = NSShadow()
    shadow.shadowBlurRadius = s * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.set()
    NSColor.white.set()
    img.draw(in: imgRect, from: .zero, operation: .sourceOver, fraction: 1.0,
             respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
}

guard let cgImage = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: cgImage)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
