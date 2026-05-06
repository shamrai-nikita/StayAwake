import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

guard CommandLine.arguments.count == 3 else {
    print("Usage: generate_icon <source.png> <output_iconset_dir>")
    exit(1)
}

let sourcePath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]

guard let dataProvider = CGDataProvider(filename: sourcePath) else {
    print("Could not open source image at \(sourcePath)")
    exit(1)
}
guard let sourceImage = CGImage(pngDataProviderSource: dataProvider,
                                decode: nil,
                                shouldInterpolate: true,
                                intent: .defaultIntent) else {
    print("Could not decode source image as PNG")
    exit(1)
}

// Detect the bounding box of non-white content so the actual artwork fills
// the icon canvas instead of being lost in surrounding whitespace.
func findContentBounds(of img: CGImage) -> CGRect {
    let w = img.width
    let h = img.height
    let bytesPerRow = w * 4
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let space = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: &pixels, width: w, height: h,
                              bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                              space: space, bitmapInfo: info) else {
        return CGRect(x: 0, y: 0, width: w, height: h)
    }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))

    let whiteThreshold: UInt8 = 240
    var minX = w, maxX = -1, minY = h, maxY = -1
    for y in 0..<h {
        for x in 0..<w {
            let i = (y * w + x) * 4
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2]
            let nearWhite = r >= whiteThreshold && g >= whiteThreshold && b >= whiteThreshold
            if !nearWhite {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
    }
    if maxX < minX || maxY < minY {
        return CGRect(x: 0, y: 0, width: w, height: h)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let bbox = findContentBounds(of: sourceImage)
guard let cropped = sourceImage.cropping(to: bbox) else {
    print("Failed to crop content region")
    exit(1)
}
print("Source: \(sourceImage.width)x\(sourceImage.height) → content bbox: \(Int(bbox.width))x\(Int(bbox.height))")

let croppedW = CGFloat(cropped.width)
let croppedH = CGFloat(cropped.height)

func renderPNG(pixelSize: Int, to url: URL) -> Bool {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: nil,
                              width: pixelSize,
                              height: pixelSize,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: bitmapInfo) else { return false }

    let canvas = CGFloat(pixelSize)
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

    // Fit cropped content into ~92% of the canvas, preserving aspect ratio.
    let inset: CGFloat = 0.92
    let fitScale = min(canvas / croppedW, canvas / croppedH) * inset
    let drawW = croppedW * fitScale
    let drawH = croppedH * fitScale
    let drawX = (canvas - drawW) / 2
    let drawY = (canvas - drawH) / 2

    ctx.interpolationQuality = .high
    ctx.draw(cropped, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))

    guard let img = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString,
                                                     1, nil) else {
        return false
    }
    CGImageDestinationAddImage(dest, img, nil)
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

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, size) in mappings {
    let url = URL(fileURLWithPath: "\(outDir)/\(name)")
    if !renderPNG(pixelSize: size, to: url) {
        print("Failed to render \(name)")
        exit(1)
    }
}
print("Generated \(mappings.count) icons → \(outDir)")
