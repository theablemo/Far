import CoreGraphics

public enum PanelPlacement {
    public static func frame(panelSize: CGSize, visibleFrame: CGRect, centered: Bool, margin: CGFloat = 20) -> CGRect {
        let safe = visibleFrame.insetBy(
            dx: min(margin, visibleFrame.width / 4), dy: min(margin, visibleFrame.height / 4))
        let size = CGSize(width: min(panelSize.width, safe.width), height: min(panelSize.height, safe.height))
        return CGRect(
            x: safe.midX - size.width / 2,
            y: centered ? safe.midY - size.height / 2 : safe.maxY - size.height,
            width: size.width, height: size.height)
    }
}
