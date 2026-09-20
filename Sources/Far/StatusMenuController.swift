import AppKit
import Combine
import SwiftUI

#if canImport(FarCore)
    import FarCore
#endif

/// Native popover placement is delegated to AppKit, anchored to the status button's bounds.
/// These two effects are injectable so ordering and attachment can be tested without a menu bar.
@MainActor struct MenuPresentation {
    var show: (NSPopover, NSView, NSRect, NSRectEdge) -> Void = { popover, anchor, rect, edge in
        popover.show(relativeTo: rect, of: anchor, preferredEdge: edge)
    }
    var close: (NSPopover) -> Void = { $0.close() }
}

enum MenuPopoverLayout {
    static let width: CGFloat = 336

    static func size(idealHeight: CGFloat, visibleFrame: CGRect?, anchor: CGRect?) -> CGSize {
        // Leave space for AppKit's arrow, outer chrome and screen-edge margins.
        let available: CGFloat
        if let visibleFrame, let anchor {
            available = min(anchor.minY, visibleFrame.maxY) - visibleFrame.minY - 24
        } else {
            available = 600
        }
        return CGSize(width: width, height: max(1, min(ceil(idealHeight), available)))
    }
}

@MainActor final class StatusMenuController: NSObject, NSPopoverDelegate {
    let popover = NSPopover()
    let button: NSButton
    private(set) lazy var content = MenuBarView(
        model: model,
        startBreak: { [weak self] in self?.startBreak() },
        showSettings: { [weak self] in self?.showSettings() },
        postpone: { [weak self] in self?.perform { $0.postponeBreak() } },
        skip: { [weak self] in self?.perform { $0.skipBreak() } },
        pause: { [weak self] in
            self?.perform { model in
                if model.reminderPaused { model.resumeReminders() } else { model.pauseReminders() }
            }
        },
        quit: { NSApp.terminate(nil) })
    private var statusItem: NSStatusItem?
    private let model: AppModel
    private let presentation: MenuPresentation
    private var subscription: AnyCancellable?
    private var lastPhase: Int
    private var settingsWindow: NSWindow?
    private var wasShown = false
    private var previousApplication: NSRunningApplication?
    private var menuHost: NSHostingView<MenuPopoverView>?

    init(model: AppModel, button: NSButton? = nil, presentation: MenuPresentation = MenuPresentation()) {
        self.model = model
        self.presentation = presentation
        lastPhase = Self.phase(model.snapshot.stage)
        if let button {
            self.button = button
        } else {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem = item
            self.button = item.button!
        }
        super.init()
        self.button.target = self
        self.button.action = #selector(toggleMenu)
        self.button.setAccessibilityLabel("Far")
        self.button.toolTip = "Far — screen breaks"
        popover.behavior = .transient
        popover.delegate = self
        // A plain controller prevents NSHostingController's automatic sizing
        // from moving the popover while native glass subviews are being laid out.
        popover.contentViewController = NSViewController()
        subscription = model.$snapshot.sink { [weak self] snapshot in
            guard let self else { return }
            let phase = Self.phase(snapshot.stage)
            // Opening the menu during rest remains possible. Timer ticks never open it or
            // dismiss it repeatedly; only entry into a new countdown/rest closes it.
            if phase != self.lastPhase, phase == 1 || phase == 2 { self.dismiss() }
            self.lastPhase = phase
            let symbol: String?
            if self.model.suppressionReason != nil || snapshot.tracking.pausedUntil != nil {
                symbol = "pause"
            } else {
                switch snapshot.stage {
                case .countdown: symbol = "timer"
                case .resting: symbol = "leaf.fill"
                case .completion: symbol = "checkmark"
                default: symbol = nil
                }
            }
            self.button.image =
                symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: "Far") }
                ?? FarBrand.menuBarImage
            self.button.image?.isTemplate = true
            self.button.toolTip = "Far — \(self.model.menuStatus)"
        }
    }
    private static func phase(_ stage: BreakStage) -> Int {
        switch stage {
        case .countdown: 1
        case .resting: 2
        case .completion: 3
        default: 0
        }
    }
    @objc func toggleMenu() {
        if popover.isShown || wasShown {
            dismiss()
            return
        }
        previousApplication = NSWorkspace.shared.frontmostApplication
        prepareMenuSize()
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        presentation.show(popover, button, button.bounds, .minY)
        wasShown = true
        button.highlight(true)
    }
    private func prepareMenuSize() {
        let measurement = NSHostingView(rootView: content.fixedSize(horizontal: false, vertical: true))
        let idealHeight = measurement.fittingSize.height
        let window = button.window
        let anchor = window.map { $0.convertToScreen(button.convert(button.bounds, to: nil)) }
        let size = MenuPopoverLayout.size(
            idealHeight: idealHeight,
            visibleFrame: window?.screen?.visibleFrame, anchor: anchor)
        let root = MenuPopoverView(content: content, size: size)
        if let menuHost {
            menuHost.rootView = root
            menuHost.frame = CGRect(origin: .zero, size: size)
        } else {
            let host = NSHostingView(rootView: root)
            host.sizingOptions = []
            host.frame = CGRect(origin: .zero, size: size)
            popover.contentViewController?.view = host
            menuHost = host
        }
        popover.contentSize = size
        menuHost?.layoutSubtreeIfNeeded()
    }
    func dismiss() {
        guard wasShown || popover.isShown else { return }
        // Close synchronously before starting a break; no second surface fades alongside it.
        popover.animates = false
        presentation.close(popover)
        wasShown = false
        button.highlight(false)
    }
    func startBreak() {
        dismiss()
        // Clicking a popover can make Far key. Return to the working app before showing rest.
        if let app = previousApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.activate(options: [])
        }
        model.startSuggestedBreak()
    }
    private func perform(_ action: (AppModel) -> Void) {
        dismiss()
        action(model)
    }
    func showSettings() {
        dismiss()
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: PreferencesView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = "Far Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(CGSize(width: 560, height: 650))
            window.contentMinSize = CGSize(width: 510, height: 560)
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func popoverShouldDetach(_ popover: NSPopover) -> Bool { false }
    func popoverDidClose(_ notification: Notification) {
        wasShown = false
        button.highlight(false)
    }
    func close() {
        dismiss()
        subscription?.cancel()
        settingsWindow?.close()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
    }
}
