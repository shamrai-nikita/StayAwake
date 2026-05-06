import Cocoa

enum Icons {
    static func burningEye(active: Bool) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let img = NSImage(size: size)

        img.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        let lineWidth: CGFloat = 1.6

        // Eye almond — wide and substantial. x:1..21 (20pt), y:4..14 (10pt tall)
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: 1, y: 9))
        eye.curve(to: NSPoint(x: 21, y: 9),
                  controlPoint1: NSPoint(x: 5, y: 14.5),
                  controlPoint2: NSPoint(x: 17, y: 14.5))
        eye.curve(to: NSPoint(x: 1, y: 9),
                  controlPoint1: NSPoint(x: 17, y: 3.5),
                  controlPoint2: NSPoint(x: 5, y: 3.5))
        eye.lineWidth = lineWidth
        eye.lineJoinStyle = .round
        eye.stroke()

        // Iris ring — clearly smaller than eye outline (2pt margin all around)
        let iris = NSBezierPath(ovalIn: NSRect(x: 8, y: 6, width: 6, height: 6))
        iris.lineWidth = lineWidth
        iris.stroke()

        // Pupil — always filled for visibility
        let pupilSize: CGFloat = active ? 3 : 2.5
        let pupilOrigin = NSPoint(x: 11 - pupilSize / 2, y: 9 - pupilSize / 2)
        let pupil = NSBezierPath(ovalIn: NSRect(origin: pupilOrigin,
                                                size: NSSize(width: pupilSize, height: pupilSize)))
        pupil.fill()

        // Flames — drawn only when active
        if active {
            // Center (tallest) flame
            let center = NSBezierPath()
            center.move(to: NSPoint(x: 9, y: 14))
            center.curve(to: NSPoint(x: 11, y: 21),
                         controlPoint1: NSPoint(x: 6.5, y: 16.5),
                         controlPoint2: NSPoint(x: 13.5, y: 17))
            center.curve(to: NSPoint(x: 13, y: 14),
                         controlPoint1: NSPoint(x: 9, y: 17.5),
                         controlPoint2: NSPoint(x: 14.5, y: 16.5))
            center.lineWidth = lineWidth
            center.lineCapStyle = .round
            center.lineJoinStyle = .round
            center.stroke()

            // Left flame curling inward
            let left = NSBezierPath()
            left.move(to: NSPoint(x: 4, y: 12))
            left.curve(to: NSPoint(x: 6, y: 17.5),
                       controlPoint1: NSPoint(x: 2.5, y: 14),
                       controlPoint2: NSPoint(x: 7.5, y: 14.5))
            left.lineWidth = lineWidth
            left.lineCapStyle = .round
            left.stroke()

            // Right flame curling inward
            let right = NSBezierPath()
            right.move(to: NSPoint(x: 18, y: 12))
            right.curve(to: NSPoint(x: 16, y: 17.5),
                        controlPoint1: NSPoint(x: 19.5, y: 14),
                        controlPoint2: NSPoint(x: 14.5, y: 14.5))
            right.lineWidth = lineWidth
            right.lineCapStyle = .round
            right.stroke()
        }

        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}
