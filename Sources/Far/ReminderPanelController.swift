import AppKit
import Combine
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

struct BreakPanelDisplay: Equatable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect
}

/// Native coordinates only. Injected displays make window positioning testable without a desktop.
@MainActor struct BreakPanelEnvironment {
    var displays: () -> [BreakPanelDisplay] = {
        NSScreen.screens.compactMap { screen in
            guard
                let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            else { return nil }
            return BreakPanelDisplay(id: id, frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }
    var pointer: () -> CGPoint = { NSEvent.mouseLocation }
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var reduceTransparency: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency }
}

enum BreakPanelLayout: Equatable {
    case notice, rest, completion
    init?(_ stage: BreakStage) {
        switch stage {
        case .countdown: self = .notice
        case .resting: self = .rest
        case .completion: self = .completion
        default: return nil
        }
    }
    var size: CGSize {
        switch self {
        case .notice: CGSize(width: 420, height: 252)
        case .rest: CGSize(width: 392, height: 292)
        case .completion: CGSize(width: 320, height: 180)
        }
    }
    var radius: CGFloat {
        switch self {
        case .notice: 30
        case .rest: 36
        case .completion: 32
        }
    }
}

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    // Placement is already clamped to the selected display, not whichever screen AppKit
    // associates with the panel partway through a resize or a Space transition.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor final class ReminderPanelController {
    let panel: NSPanel
    let surface: BreakPanelSurface
    let dimming = RestDimmingController()
    private let environment: BreakPanelEnvironment
    private var screenID: UInt32?
    private var layout: BreakPanelLayout?
    private var target: CGRect?
    private var transition: Task<Void, Never>?
    private var subscription: AnyCancellable?
    private var lastSnapshot: BreakSnapshot
    private let model: AppModel

    init(model: AppModel, environment: BreakPanelEnvironment = BreakPanelEnvironment()) {
        self.model = model
        self.environment = environment
        lastSnapshot = model.snapshot
        let content = ReminderPanelView(
            snapshot: model.snapshot, postpone: { [weak model] in model?.postponeBreak() },
            skip: { [weak model] in model?.skipBreak() })
        surface = BreakPanelSurface(content: content)
        panel = ReminderPanel(
            contentRect: CGRect(origin: .zero, size: BreakPanelLayout.notice.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier("Far.breakPanel")
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.contentView = surface
        panel.setAccessibilityLabel("Far screen break")
        // @Published delivers before model.snapshot is assigned. Use the emitted snapshot
        // for BOTH geometry and content, avoiding a frame/content mismatch at transitions.
        subscription = model.$snapshot.removeDuplicates().sink { [weak self] snapshot in
            self?.present(snapshot)
        }
    }

    func present(_ snapshot: BreakSnapshot) {
        lastSnapshot = snapshot
        guard let nextLayout = BreakPanelLayout(snapshot.stage) else {
            hide()
            return
        }
        let content = ReminderPanelView(
            snapshot: snapshot, postpone: { [weak model] in model?.postponeBreak() },
            skip: { [weak model] in model?.skipBreak() })
        surface.update(content: content, radius: nextLayout.radius, opaque: environment.reduceTransparency())
        let displays = environment.displays()
        if nextLayout == .rest {
            dimming.show(on: displays, reduceMotion: environment.reduceMotion())
        } else {
            dimming.hide()
        }
        if layout == nil || !displays.contains(where: { $0.id == screenID }) {
            screenID = (displays.first { $0.frame.contains(environment.pointer()) } ?? displays.first)?.id
        }
        guard let display = displays.first(where: { $0.id == screenID }) else {
            hide()
            return
        }
        let frame = PanelPlacement.frame(
            panelSize: nextLayout.size, visibleFrame: display.visibleFrame,
            centered: nextLayout != .notice)
        if nextLayout == layout && target == frame {
            // Timer text changes may trigger deferred layout. Reassert placement after layout
            // whenever there is no intentional movement in flight.
            if transition == nil { place(frame) }
            return
        }
        let appearing = layout == nil
        layout = nextLayout
        target = frame
        transition?.cancel()
        transition = nil
        if appearing {
            place(frame)
            panel.alphaValue = environment.reduceMotion() ? 1 : 0
            panel.orderFrontRegardless()
            animate(to: frame, opacity: 1, duration: 0.18)
        } else {
            animate(to: frame, opacity: 1, duration: 0.42, revealContent: true)
        }
    }
    private func place(_ frame: CGRect) {
        panel.setFrame(frame, display: true)
        surface.frame = CGRect(origin: .zero, size: frame.size)
        surface.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
    }
    private func animate(to destination: CGRect, opacity: CGFloat, duration: Double, revealContent: Bool = false) {
        transition?.cancel()
        surface.hosting.alphaValue = revealContent && !environment.reduceMotion() ? 0 : 1
        if environment.reduceMotion() {
            place(destination)
            panel.alphaValue = opacity
            transition = nil
            if opacity == 0 { panel.orderOut(nil) }
            return
        }
        let startFrame = panel.frame
        let startOpacity = panel.alphaValue
        transition = Task { [weak self] in
            let start = ContinuousClock.now
            while !Task.isCancelled {
                guard let self else { return }
                let elapsed = start.duration(to: .now)
                let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                let t = min(1, seconds / duration)
                let ease = CGFloat(1 - pow(1 - t, 3))
                let frame = CGRect(
                    x: startFrame.minX + (destination.minX - startFrame.minX) * ease,
                    y: startFrame.minY + (destination.minY - startFrame.minY) * ease,
                    width: startFrame.width + (destination.width - startFrame.width) * ease,
                    height: startFrame.height + (destination.height - startFrame.height) * ease)
                self.place(frame)
                self.panel.alphaValue = startOpacity + (opacity - startOpacity) * ease
                if revealContent { self.surface.hosting.alphaValue = CGFloat(min(1, max(0, (t - 0.15) / 0.65))) }
                if t >= 1 {
                    self.place(destination)
                    self.panel.alphaValue = opacity
                    self.surface.hosting.alphaValue = 1
                    if opacity == 0 { self.panel.orderOut(nil) }
                    self.transition = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
    private func hide() {
        dimming.hide()
        guard layout != nil else { return }
        layout = nil
        target = nil
        animate(to: panel.frame, opacity: 0, duration: 0.15)
    }
    func repositionIfVisible() {
        guard layout != nil else { return }
        target = nil
        present(lastSnapshot)
    }
    func close() {
        dimming.hide()
        transition?.cancel()
        transition = nil
        subscription?.cancel()
        panel.orderOut(nil)
    }
}
