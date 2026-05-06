import Cocoa

enum Icons {
    static func burningEye(active: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)

        let img = NSImage(size: size, flipped: false) { _ in
            drawIcon(active: active)
            return true
        }
        // Inactive icon is template (auto-tints to label color).
        // Active icon is colored, so it must NOT be a template.
        img.isTemplate = !active
        img.accessibilityDescription = active ? "Sleep prevented" : "Sleep allowed"
        return img
    }

    private static func drawIcon(active: Bool) {
        let lineWidth: CGFloat = 2.0

        // Colors. NSColor.labelColor resolves dynamically every time
        // the drawing handler runs, so the icon adapts to dark/light.
        let outlineColor: NSColor = active ? .labelColor : .black
        let irisColor    = NSColor.systemOrange
        let pupilColor   = NSColor.black
        let flameOuter   = NSColor.systemRed
        let flameInner   = NSColor.systemOrange

        // ----- Eye almond -----
        outlineColor.setStroke()
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 1, y: 9))
        eye.curve(to: NSPoint(x: 21, y: 9),
                  controlPoint1: NSPoint(x: 5, y: 14.5),
                  controlPoint2: NSPoint(x: 17, y: 14.5))
        eye.curve(to: NSPoint(x: 1, y: 9),
                  controlPoint1: NSPoint(x: 17, y: 3.5),
                  controlPoint2: NSPoint(x: 5, y: 3.5))
        eye.close()
        eye.lineWidth = lineWidth
        eye.lineJoinStyle = .round
        eye.stroke()

        // ----- Iris -----
        let irisRect = NSRect(x: 7.5, y: 5.5, width: 7, height: 7)
        if active {
            irisColor.setFill()
            NSBezierPath(ovalIn: irisRect).fill()
        } else {
            outlineColor.setStroke()
            let ring = NSBezierPath(ovalIn: irisRect)
            ring.lineWidth = lineWidth
            ring.stroke()
        }

        // ----- Pupil -----
        pupilColor.setFill()
        let pupilSize: CGFloat = active ? 3.0 : 2.5
        let pupilRect = NSRect(x: 11 - pupilSize / 2,
                               y: 9 - pupilSize / 2,
                               width: pupilSize,
                               height: pupilSize)
        NSBezierPath(ovalIn: pupilRect).fill()

        // ----- Flames (only when active) -----
        guard active else { return }

        // Center flame — drawn as a closed flame silhouette and filled
        let cFlame = NSBezierPath()
        cFlame.move(to: NSPoint(x: 9.5, y: 14))
        cFlame.curve(to: NSPoint(x: 11, y: 21),
                     controlPoint1: NSPoint(x: 7,  y: 16.5),
                     controlPoint2: NSPoint(x: 13, y: 17))
        cFlame.curve(to: NSPoint(x: 12.5, y: 14),
                     controlPoint1: NSPoint(x: 9.5, y: 17),
                     controlPoint2: NSPoint(x: 14,  y: 16.5))
        cFlame.close()
        flameOuter.setFill()
        cFlame.fill()

        // Center flame inner highlight (yellow-ish core)
        let cInner = NSBezierPath()
        cInner.move(to: NSPoint(x: 10.4, y: 14.5))
        cInner.curve(to: NSPoint(x: 11, y: 19),
                     controlPoint1: NSPoint(x: 9.4, y: 16),
                     controlPoint2: NSPoint(x: 12.2, y: 16.5))
        cInner.curve(to: NSPoint(x: 11.6, y: 14.5),
                     controlPoint1: NSPoint(x: 10.2, y: 16.5),
                     controlPoint2: NSPoint(x: 12.6, y: 16))
        cInner.close()
        flameInner.setFill()
        cInner.fill()

        // Side flames — strokes that curl inward
        flameOuter.setStroke()
        let lFlame = NSBezierPath()
        lFlame.move(to: NSPoint(x: 4, y: 12))
        lFlame.curve(to: NSPoint(x: 6.5, y: 17),
                     controlPoint1: NSPoint(x: 2.5, y: 14),
                     controlPoint2: NSPoint(x: 8,   y: 14.2))
        lFlame.lineWidth = lineWidth
        lFlame.lineCapStyle = .round
        lFlame.stroke()

        let rFlame = NSBezierPath()
        rFlame.move(to: NSPoint(x: 18, y: 12))
        rFlame.curve(to: NSPoint(x: 15.5, y: 17),
                     controlPoint1: NSPoint(x: 19.5, y: 14),
                     controlPoint2: NSPoint(x: 14,   y: 14.2))
        rFlame.lineWidth = lineWidth
        rFlame.lineCapStyle = .round
        rFlame.stroke()
    }
}
