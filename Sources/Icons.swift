import Cocoa

enum Icons {
    static func burningEye(active: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let resourceName = active ? "MenuBarEye" : "MenuBarEyeOutline"
        let label = active ? "Sleep prevented" : "Sleep allowed"
        if let img = cachedImage(for: resourceName, size: size, template: !active, label: label) {
            return img
        }
        return NSImage(size: size)
    }

    private static var cache: [String: NSImage] = [:]

    private static func cachedImage(for resourceName: String,
                                    size: NSSize,
                                    template: Bool,
                                    label: String) -> NSImage? {
        if let img = cache[resourceName] { return img }
        guard let cropped = loadAndKeyOutBlack(resource: resourceName) else { return nil }
        let inset: CGFloat = 0.82
        let img = NSImage(size: size, flipped: false) { rect in
            guard let outCtx = NSGraphicsContext.current?.cgContext else { return false }
            let cw = CGFloat(cropped.width), ch = CGFloat(cropped.height)
            let scale = min(rect.width / cw, rect.height / ch) * inset
            let dw = cw * scale, dh = ch * scale
            let dx = (rect.width - dw) / 2, dy = (rect.height - dh) / 2
            outCtx.interpolationQuality = .high
            outCtx.draw(cropped, in: CGRect(x: dx, y: dy, width: dw, height: dh))
            return true
        }
        img.isTemplate = template
        img.accessibilityDescription = label
        cache[resourceName] = img
        return img
    }

    // Loads a PNG bundled in Resources, converts near-black pixels to fully
    // transparent (chroma key on the black background), then crops to the
    // bounding box of remaining non-transparent content.
    private static func loadAndKeyOutBlack(resource: String) -> CGImage? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "png"),
              let provider = CGDataProvider(url: url as CFURL),
              let raw = CGImage(pngDataProviderSource: provider,
                                decode: nil,
                                shouldInterpolate: true,
                                intent: .defaultIntent) else { return nil }
        let w = raw.width, h = raw.height
        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: &pixels,
                                  width: w,
                                  height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow,
                                  space: space,
                                  bitmapInfo: info) else { return nil }
        ctx.draw(raw, in: CGRect(x: 0, y: 0, width: w, height: h))

        let blackThreshold: UInt8 = 32
        var i = 0
        while i < pixels.count {
            let r = pixels[i], g = pixels[i + 1], b = pixels[i + 2]
            if r < blackThreshold && g < blackThreshold && b < blackThreshold {
                pixels[i] = 0
                pixels[i + 1] = 0
                pixels[i + 2] = 0
                pixels[i + 3] = 0
            }
            i += 4
        }
        guard let keyed = ctx.makeImage() else { return nil }
        let bbox = nonTransparentBounds(of: keyed)
        return keyed.cropping(to: bbox) ?? keyed
    }

    private static func nonTransparentBounds(of cg: CGImage) -> CGRect {
        let w = cg.width, h = cg.height
        let bytesPerRow = w * 4
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                  space: space, bitmapInfo: info) else {
            return CGRect(x: 0, y: 0, width: w, height: h)
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let alphaThreshold: UInt8 = 8
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w {
                let a = pixels[(y * w + x) * 4 + 3]
                if a > alphaThreshold {
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
}
