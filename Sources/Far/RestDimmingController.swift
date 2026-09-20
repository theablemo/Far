import AppKit

private final class RestBackdropPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// One click-through backdrop per display. Never participates in input or takes focus.
@MainActor final class RestDimmingController {
    private(set) var panels: [UInt32: NSPanel] = [:]
    private var fade: Task<Void, Never>?

    func show(on displays: [BreakPanelDisplay], reduceMotion: Bool) {
        let ids = Set(displays.map(\.id))
        for id in Array(panels.keys) where !ids.contains(id) { panels.removeValue(forKey: id)?.orderOut(nil) }
        let appearing = panels.isEmpty
        for display in displays {
            let window: NSPanel
            if let existing = panels[display.id] {
                window = existing
            } else {
                window = RestBackdropPanel(
                    contentRect: display.frame,
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                window.identifier = NSUserInterfaceItemIdentifier("Far.restBackdrop.\(display.id)")
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
                window.backgroundColor = .black.withAlphaComponent(0.60)
                window.isOpaque = false
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.hidesOnDeactivate = false
                window.setAccessibilityElement(false)
                window.alphaValue = appearing && !reduceMotion ? 0 : 1
                panels[display.id] = window
                window.orderFrontRegardless()
            }
            window.setFrame(display.frame, display: true)
        }
        guard appearing, !reduceMotion, !panels.isEmpty else { return }
        fade?.cancel()
        fade = Task { [weak self] in
            let start = ContinuousClock.now
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = start.duration(to: .now)
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                let t = min(1, seconds / 0.35)
                for window in self.panels.values { window.alphaValue = 1 - pow(1 - t, 3) }
                if t >= 1 {
                    self.fade = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
    func hide() {
        fade?.cancel()
        fade = nil
        for panel in panels.values { panel.orderOut(nil) }
        panels.removeAll()
    }
}
