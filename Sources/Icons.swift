import Cocoa

enum Icons {
    static func burningEye(active: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)

        let img = NSImage(size: size, flipped: false) { _ in
            drawIcon(active: active)
            return true
        }
        img.isTemplate = !active
        img.accessibilityDescription = active ? "Sleep prevented" : "Sleep allowed"
        return img
    }

    private static func drawIcon(active: Bool) {
        let lineWidth: CGFloat = 2.0
        let outlineColor: NSColor = active ? .labelColor : .black
        let irisFillColor = NSColor.systemOrange
        let pupilColor    = NSColor.black
        let flameOuter    = NSColor.systemRed
        let flameInner    = NSColor.systemOrange

        // Eye almond — centered at (11, 11), 17pt wide, 11pt tall (more "open").
        outlineColor.setStroke()
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 2.5, y: 11))
        eye.curve(to: NSPoint(x: 19.5, y: 11),
                  controlPoint1: NSPoint(x: 6, y: 16.5),
                  controlPoint2: NSPoint(x: 16, y: 16.5))
        eye.curve(to: NSPoint(x: 2.5, y: 11),
                  controlPoint1: NSPoint(x: 16, y: 5.5),
                  controlPoint2: NSPoint(x: 6, y: 5.5))
        eye.close()
        eye.lineWidth = lineWidth
        eye.lineJoinStyle = .round
        eye.stroke()

        // Iris — diameter 7, centered at (11, 11)
        let irisRect = NSRect(x: 7.5, y: 7.5, width: 7, height: 7)
        if active {
            irisFillColor.setFill()
            NSBezierPath(ovalIn: irisRect).fill()
        } else {
            outlineColor.setStroke()
            let ring = NSBezierPath(ovalIn: irisRect)
            ring.lineWidth = lineWidth
            ring.stroke()
        }

        // Pupil — centered at (11, 11)
        pupilColor.setFill()
        let pupilSize: CGFloat = active ? 3.0 : 2.5
        let pupilRect = NSRect(x: 11 - pupilSize / 2,
                               y: 11 - pupilSize / 2,
                               width: pupilSize,
                               height: pupilSize)
        NSBezierPath(ovalIn: pupilRect).fill()

        // Flames — only when active. Eye top is around y=16.5 so flames live above.
        guard active else { return }

        // Center flame silhouette (filled red), apex around y=21
        let cFlame = NSBezierPath()
        cFlame.move(to: NSPoint(x: 9.5, y: 16))
        cFlame.curve(to: NSPoint(x: 11, y: 21.5),
                     controlPoint1: NSPoint(x: 7,  y: 18.5),
                     controlPoint2: NSPoint(x: 13, y: 18.5))
        cFlame.curve(to: NSPoint(x: 12.5, y: 16),
                     controlPoint1: NSPoint(x: 9.5, y: 18.5),
                     controlPoint2: NSPoint(x: 14,  y: 18))
        cFlame.close()
        flameOuter.setFill()
        cFlame.fill()

        // Center flame inner highlight
        let cInner = NSBezierPath()
        cInner.move(to: NSPoint(x: 10.4, y: 16.4))
        cInner.curve(to: NSPoint(x: 11, y: 19.8),
                     controlPoint1: NSPoint(x: 9.4, y: 17.6),
                     controlPoint2: NSPoint(x: 12.2, y: 18))
        cInner.curve(to: NSPoint(x: 11.6, y: 16.4),
                     controlPoint1: NSPoint(x: 10.2, y: 18),
                     controlPoint2: NSPoint(x: 12.6, y: 17.6))
        cInner.close()
        flameInner.setFill()
        cInner.fill()

        // Side flames — short stroked curls licking up from the sides
        flameOuter.setStroke()
        let lFlame = NSBezierPath()
        lFlame.move(to: NSPoint(x: 4, y: 14))
        lFlame.curve(to: NSPoint(x: 6.5, y: 18),
                     controlPoint1: NSPoint(x: 2.5, y: 16),
                     controlPoint2: NSPoint(x: 8,   y: 15.5))
        lFlame.lineWidth = lineWidth
        lFlame.lineCapStyle = .round
        lFlame.stroke()

        let rFlame = NSBezierPath()
        rFlame.move(to: NSPoint(x: 18, y: 14))
        rFlame.curve(to: NSPoint(x: 15.5, y: 18),
                     controlPoint1: NSPoint(x: 19.5, y: 16),
                     controlPoint2: NSPoint(x: 14,   y: 15.5))
        rFlame.lineWidth = lineWidth
        rFlame.lineCapStyle = .round
        rFlame.stroke()
    }
}
