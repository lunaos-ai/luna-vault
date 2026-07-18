// usage: swift scripts/dmg/DMGBackgroundGen.swift <out.png> <width> <height>
import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 4,
      let w = Int(args[2]), let h = Int(args[3]) else {
    FileHandle.standardError.write(Data("usage: DMGBackgroundGen.swift <out.png> <w> <h>\n".utf8))
    exit(64)
}
let out = args[1]
let width = CGFloat(w)
let height = CGFloat(h)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: w, height: h,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let bg = CGRect(x: 0, y: 0, width: width, height: height)
ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
ctx.fill(bg)

let accent = CGColor(red: 0x4F/255, green: 0x46/255, blue: 0xE5/255, alpha: 1)
ctx.setStrokeColor(accent)
ctx.setLineWidth(1.5)
let arrowY = height * 0.52
ctx.move(to: CGPoint(x: width * 0.42, y: arrowY))
ctx.addLine(to: CGPoint(x: width * 0.58, y: arrowY))
ctx.addLine(to: CGPoint(x: width * 0.54, y: arrowY - 10))
ctx.move(to: CGPoint(x: width * 0.58, y: arrowY))
ctx.addLine(to: CGPoint(x: width * 0.54, y: arrowY + 10))
ctx.strokePath()

guard let img = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: img)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
