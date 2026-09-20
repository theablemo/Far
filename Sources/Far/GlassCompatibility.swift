import AppKit
import SwiftUI

/// Public AppKit API bridge for builds made with the macOS 15 SDK. Remove the
/// dynamic branch once Xcode 26 is the minimum build tool; no private selectors.
@MainActor enum FarGlass {
    static func makeView() -> NSView? {
        guard #available(macOS 26.0, *) else { return nil }
        #if compiler(>=6.2)
            return NSGlassEffectView()
        #else
            guard let type = NSClassFromString("NSGlassEffectView") as? NSView.Type else { return nil }
            let view = type.init(frame: .zero)
            guard
                ["setContentView:", "setCornerRadius:", "setTintColor:"].allSatisfy({
                    view.responds(to: NSSelectorFromString($0))
                })
            else { return nil }
            return view
        #endif
    }
    static func configure(_ view: NSView, radius: CGFloat, tint: NSColor? = nil) {
        view.setValue(radius, forKey: "cornerRadius")
        view.setValue(tint, forKey: "tintColor")
    }
    static func embed(_ content: NSView?, in view: NSView) {
        view.setValue(content, forKey: "contentView")
    }
}

/// Decorative control background. SwiftUI retains input, focus and accessibility.
private struct FarOpaqueSurfacesKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    /// Enables deterministic layout previews without WindowServer compositing.
    var farOpaqueSurfaces: Bool {
        get { self[FarOpaqueSurfacesKey.self] }
        set { self[FarOpaqueSurfacesKey.self] = newValue }
    }
}

struct GlassPillBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> GlassPillSurface { GlassPillSurface() }
    func updateNSView(_ view: GlassPillSurface, context: Context) {
        view.refresh()
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: GlassPillSurface, context: Context) -> CGSize? {
        // This is decoration, so its native subviews must never impose a minimum
        // or ideal size on SwiftUI's button, menu, or enclosing window.
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}

final class GlassPillSurface: NSView {
    private let glass = FarGlass.makeView()
    override init(frame: NSRect) {
        super.init(frame: frame)
        if let glass {
            addSubview(glass)
            glass.setAccessibilityElement(false)
        }
        setAccessibilityElement(false)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout()
        glass?.frame = bounds
        refresh()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }
    func refresh() {
        guard let glass else { return }
        FarGlass.configure(
            glass, radius: bounds.height / 2,
            tint: NSColor(Color.farGreen).withAlphaComponent(0.08))
    }
}
