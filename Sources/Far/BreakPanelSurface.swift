import AppKit
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

/// The AppKit root owns both the material mask and host bounds. SwiftUI never sizes the window.
final class BreakPanelSurface: NSView {
    let material = NSVisualEffectView()
    let glass = FarGlass.makeView()
    let hosting: NSHostingView<ReminderPanelView>
    private(set) var cornerRadius: CGFloat = 30
    private var usesOpaqueBackground = false
    private var maskRadius: CGFloat?

    init(content: ReminderPanelView) {
        hosting = NSHostingView(rootView: content)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerCurve = .continuous
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        material.wantsLayer = true
        material.layer?.masksToBounds = true
        hosting.sizingOptions = []
        hosting.wantsLayer = true
        addSubview(material)
        if let glass {
            addSubview(glass)
            FarGlass.embed(hosting, in: glass)
        } else {
            addSubview(hosting)
        }
        material.isHidden = glass != nil
        material.autoresizingMask = [.width, .height]
        hosting.autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(content: ReminderPanelView, radius: CGFloat, opaque: Bool) {
        hosting.rootView = content
        cornerRadius = radius
        self.usesOpaqueBackground = opaque
        material.isHidden = opaque || glass != nil
        if let glass {
            glass.isHidden = opaque
            // Content must remain visible when accessibility removes the glass.
            if opaque && hosting.superview !== self {
                FarGlass.embed(nil, in: glass)
                addSubview(hosting)
            } else if !opaque && hosting.superview === self {
                hosting.removeFromSuperview()
                FarGlass.embed(hosting, in: glass)
            }
        }
        updateSurface()
        needsLayout = true
    }
    override func layout() {
        super.layout()
        material.frame = bounds
        glass?.frame = bounds
        hosting.frame = bounds
        updateSurface()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateSurface()
    }
    private func updateSurface() {
        layer?.cornerRadius = cornerRadius
        material.layer?.cornerRadius = cornerRadius
        if let glass { FarGlass.configure(glass, radius: cornerRadius) }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor =
                usesOpaqueBackground ? NSColor.windowBackgroundColor.cgColor : NSColor.clear.cgColor
        }
        // NSVisualEffectView's backdrop is composited natively; maskImage clips that backdrop,
        // including on macOS versions where a SwiftUI clip does not clip an NSViewRepresentable.
        guard bounds.width > 0, bounds.height > 0, maskRadius != cornerRadius else { return }
        let radius = cornerRadius
        maskRadius = radius
        let maskSize = CGSize(width: cornerRadius * 2 + 1, height: cornerRadius * 2 + 1)
        let mask = NSImage(size: maskSize, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        mask.resizingMode = .stretch
        material.maskImage = mask
    }
}
