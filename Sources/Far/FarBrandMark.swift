import AppKit
import SwiftUI

/// The approved original Soft pause, without the eye. Shared by native UI and icon export.
enum FarBrand {
    static var designPath: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 24, y: 39))
        path.addCurve(to: CGPoint(x: 43, y: 19), control1: CGPoint(x: 24, y: 26), control2: CGPoint(x: 32, y: 19))
        path.addLine(to: CGPoint(x: 46, y: 19))
        path.addLine(to: CGPoint(x: 46, y: 62))
        path.addCurve(to: CGPoint(x: 27, y: 82), control1: CGPoint(x: 46, y: 75), control2: CGPoint(x: 38, y: 82))
        path.addLine(to: CGPoint(x: 24, y: 82))
        path.closeSubpath()
        path.move(to: CGPoint(x: 55, y: 19))
        path.addLine(to: CGPoint(x: 58, y: 19))
        path.addCurve(to: CGPoint(x: 77, y: 39), control1: CGPoint(x: 69, y: 19), control2: CGPoint(x: 77, y: 26))
        path.addLine(to: CGPoint(x: 77, y: 82))
        path.addLine(to: CGPoint(x: 74, y: 82))
        path.addCurve(to: CGPoint(x: 55, y: 62), control1: CGPoint(x: 63, y: 82), control2: CGPoint(x: 55, y: 75))
        path.closeSubpath()
        return path
    }

    static func path(in rect: CGRect) -> CGPath {
        let scale = min(rect.width / 53, rect.height / 63)
        var transform = CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: rect.midX - 50.5 * scale, ty: rect.midY - 50.5 * scale)
        return designPath.copy(using: &transform)!
    }

    /// Template drawing stays vector-backed and adapts to menu-bar tint and Retina scale.
    static var menuBarImage: NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(path(in: CGRect(x: 2, y: 1, width: 14, height: 16)))
            context.fillPath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Far"
        return image
    }
}

struct FarBrandMark: Shape {
    func path(in rect: CGRect) -> Path {
        Path(FarBrand.path(in: rect))
    }
}
