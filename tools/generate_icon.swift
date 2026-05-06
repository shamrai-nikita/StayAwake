import Foundation
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    print("Usage: generate_icon <output_iconset_dir>")
    exit(1)
}
let outputDir = CommandLine.arguments[1]

func draw(into ctx: CGContext, pixelSize: Int) {
    let canvas: CGFloat = 1024
    let scale = CGFloat(pixelSize) / canvas
    ctx.saveGState()
    ctx.scaleBy(x: scale, y: scale)

    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // ----- Background squircle (white) -----
    let bgRect = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 225, yRadius: 225)
    NSColor.white.setFill()
    bgPath.fill()

    let strokeWidth: CGFloat = 36

    // ----- Eye almond (black outline) -----
    NSColor.black.setStroke()
    NSColor.black.setFill()

    let centerX: CGFloat = canvas / 2
    let eyeY: CGFloat = 400
    let eyeHalfW: CGFloat = 340
    let eyeArc: CGFloat = 200

    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: centerX - eyeHalfW, y: eyeY))
    eye.curve(to: NSPoint(x: centerX + eyeHalfW, y: eyeY),
              controlPoint1: NSPoint(x: centerX - 200, y: eyeY + eyeArc),
              controlPoint2: NSPoint(x: centerX + 200, y: eyeY + eyeArc))
    eye.curve(to: NSPoint(x: centerX - eyeHalfW, y: eyeY),
              controlPoint1: NSPoint(x: centerX + 200, y: eyeY - eyeArc),
              controlPoint2: NSPoint(x: centerX - 200, y: eyeY - eyeArc))
    eye.close()
    eye.lineWidth = strokeWidth
    eye.lineJoinStyle = .round
    eye.stroke()

    // ----- Iris ring -----
    let irisR: CGFloat = 130
    let iris = NSBezierPath(ovalIn: CGRect(x: centerX - irisR, y: eyeY - irisR,
                                             width: irisR * 2, height: irisR * 2))
    iris.lineWidth = strokeWidth
    iris.stroke()

    // ----- Pupil (filled) -----
    let pupilR: CGFloat = 55
    let pupil = NSBezierPath(ovalIn: CGRect(x: centerX - pupilR, y: eyeY - pupilR,
                                              width: pupilR * 2, height: pupilR * 2))
    pupil.fill()

    // ----- Flames (orange-red) -----
    let flameColor = NSColor(red: 1.0, green: 0.30, blue: 0.05, alpha: 1.0)
    flameColor.setStroke()

    let flameStroke: CGFloat = 36

    // Center (tallest) flame
    let cFlame = NSBezierPath()
    cFlame.move(to: NSPoint(x: centerX - 80, y: 620))
    cFlame.curve(to: NSPoint(x: centerX + 20, y: 940),
                 controlPoint1: NSPoint(x: centerX - 220, y: 770),
                 controlPoint2: NSPoint(x: centerX + 100, y: 850))
    cFlame.curve(to: NSPoint(x: centerX + 90, y: 620),
                 controlPoint1: NSPoint(x: centerX - 30, y: 850),
                 controlPoint2: NSPoint(x: centerX + 220, y: 800))
    cFlame.lineWidth = flameStroke
    cFlame.lineCapStyle = .round
    cFlame.lineJoinStyle = .round
    cFlame.stroke()

    // Left flame curling inward
    let lFlame = NSBezierPath()
    lFlame.move(to: NSPoint(x: 175, y: 620))
    lFlame.curve(to: NSPoint(x: 280, y: 820),
                 controlPoint1: NSPoint(x: 90, y: 720),
                 controlPoint2: NSPoint(x: 380, y: 740))
    lFlame.lineWidth = flameStroke
    lFlame.lineCapStyle = .round
    lFlame.stroke()

    // Right flame curling inward
    let rFlame = NSBezierPath()
    rFlame.move(to: NSPoint(x: 849, y: 620))
    rFlame.curve(to: NSPoint(x: 744, y: 820),
                 controlPoint1: NSPoint(x: 934, y: 720),
                 controlPoint2: NSPoint(x: 644, y: 740))
    rFlame.lineWidth = flameStroke
    rFlame.lineCapStyle = .round
    rFlame.stroke()

    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()
}

func renderPNG(pixelSize: Int, to url: URL) -> Bool {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: nil,
                              width: pixelSize,
                              height: pixelSize,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: bitmapInfo) else {
        return false
    }
    draw(into: ctx, pixelSize: pixelSize)

    guard let cgImage = ctx.makeImage() else { return false }
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString,
                                                     1, nil) else {
        return false
    }
    CGImageDestinationAddImage(dest, cgImage, nil)
    return CGImageDestinationFinalize(dest)
}

let mappings: [(String, Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024)
]

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
for (name, size) in mappings {
    let url = URL(fileURLWithPath: "\(outputDir)/\(name)")
    if !renderPNG(pixelSize: size, to: url) {
        print("Failed to render \(name) at \(size)x\(size)")
        exit(1)
    }
}
print("Wrote \(mappings.count) icon files to \(outputDir)")
