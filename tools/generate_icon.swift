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

let srcW = CGFloat(sourceImage.width)
let srcH = CGFloat(sourceImage.height)

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

    let canvas = CGFloat(pixelSize)

    // Fill white
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))

    // Center source preserving aspect ratio
    let s = min(canvas / srcW, canvas / srcH)
    let drawW = srcW * s
    let drawH = srcH * s
    let drawX = (canvas - drawW) / 2
    let drawY = (canvas - drawH) / 2

    ctx.interpolationQuality = .high
    ctx.draw(sourceImage, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))

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
print("Generated \(mappings.count) icons from \(sourcePath) → \(outDir)")
