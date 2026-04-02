import AppKit
import CodeRelayCore

enum CodeRelayStatusIconRenderer {
    private static let outputSize = NSSize(width: 18, height: 18)

    // CodexBar sets the quality bar for crisp 18pt template icons.
    static func makeIcon(hasAccounts: Bool, status: UsageProbeStatus, isBusy: Bool) -> NSImage {
        let image = NSImage(size: self.outputSize)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            image.isTemplate = true
            return image
        }

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        let alpha: CGFloat
        if !hasAccounts {
            alpha = 0.55
        } else if isBusy {
            alpha = 0.95
        } else {
            switch status {
            case .fresh:
                alpha = 1.0
            case .stale:
                alpha = 0.78
            case .error, .unknown:
                alpha = 0.68
            }
        }

        NSColor.labelColor.withAlphaComponent(alpha).setStroke()
        NSColor.labelColor.withAlphaComponent(alpha).setFill()

        let leftLoop = NSBezierPath(ovalIn: CGRect(x: 1.8, y: 4.1, width: 7.2, height: 7.2))
        leftLoop.lineWidth = 1.85
        leftLoop.lineJoinStyle = .round
        leftLoop.stroke()

        let rightLoop = NSBezierPath(ovalIn: CGRect(x: 8.9, y: 4.1, width: 7.2, height: 7.2))
        rightLoop.lineWidth = 1.85
        rightLoop.lineJoinStyle = .round
        rightLoop.stroke()

        let bridge = NSBezierPath(
            roundedRect: CGRect(x: 3.4, y: 7.15, width: 11.2, height: 2.6),
            xRadius: 1.3,
            yRadius: 1.3)
        var transform = AffineTransform()
        transform.translate(x: 9, y: 8.45)
        transform.rotate(byDegrees: 34)
        transform.translate(x: -9, y: -8.45)
        bridge.transform(using: transform)
        bridge.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
