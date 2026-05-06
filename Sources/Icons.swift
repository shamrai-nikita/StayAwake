import Cocoa

enum Icons {
    static func burningEye(active: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let img = NSImage(size: size)

        img.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let lineWidth: CGFloat = 1.4

        // Eye almond — spans x:2..20, y:5..11, centered at (11, 8)
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 2, y: 8))
        eye.curve(to: NSPoint(x: 20, y: 8),
                  controlPoint1: NSPoint(x: 6, y: 12.5),
                  controlPoint2: NSPoint(x: 16, y: 12.5))
        eye.curve(to: NSPoint(x: 2, y: 8),
                  controlPoint1: NSPoint(x: 16, y: 3.5),
                  controlPoint2: NSPoint(x: 6, y: 3.5))
        eye.lineWidth = lineWidth
        eye.lineJoinStyle = .round
        eye.stroke()

        // Iris ring
        let iris = NSBezierPath(ovalIn: NSRect(x: 7.5, y: 4.5, width: 7, height: 7))
        iris.lineWidth = lineWidth
        iris.stroke()

        // Pupil — filled when active, hollow when inactive
        if active {
            let pupil = NSBezierPath(ovalIn: NSRect(x: 9.5, y: 6.5, width: 3, height: 3))
            pupil.fill()
        } else {
            let pupil = NSBezierPath(ovalIn: NSRect(x: 9.75, y: 6.75, width: 2.5, height: 2.5))
            pupil.lineWidth = lineWidth
            pupil.stroke()
        }

        // Flames — drawn only when active
        if active {
            // Center (tallest) flame
            let center = NSBezierPath()
            center.move(to: NSPoint(x: 9, y: 13))
            center.curve(to: NSPoint(x: 11, y: 20.5),
                         controlPoint1: NSPoint(x: 6.5, y: 15.5),
                         controlPoint2: NSPoint(x: 13.5, y: 16.5))
            center.curve(to: NSPoint(x: 13, y: 13),
                         controlPoint1: NSPoint(x: 9, y: 17),
                         controlPoint2: NSPoint(x: 14.5, y: 16))
            center.lineWidth = lineWidth
            center.lineCapStyle = .round
            center.lineJoinStyle = .round
            center.stroke()

            // Left flame curling inward
            let left = NSBezierPath()
            left.move(to: NSPoint(x: 4, y: 11.5))
            left.curve(to: NSPoint(x: 6.5, y: 17),
                       controlPoint1: NSPoint(x: 2.5, y: 13.5),
                       controlPoint2: NSPoint(x: 8, y: 14))
            left.lineWidth = lineWidth
            left.lineCapStyle = .round
            left.stroke()

            // Right flame curling inward
            let right = NSBezierPath()
            right.move(to: NSPoint(x: 18, y: 11.5))
            right.curve(to: NSPoint(x: 15.5, y: 17),
                        controlPoint1: NSPoint(x: 19.5, y: 13.5),
                        controlPoint2: NSPoint(x: 14, y: 14))
            right.lineWidth = lineWidth
            right.lineCapStyle = .round
            right.stroke()
        }

        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
