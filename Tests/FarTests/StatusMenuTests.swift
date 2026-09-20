import AppKit
import FarCore
import SwiftUI
import XCTest

@testable import Far

final class StatusMenuTests: FarTestCase {
    @MainActor func testStatusPopoverAnchorsToButtonAndClosesBeforeManualRest() async {
        _ = NSApplication.shared
        let (model, clock, _, _, _, _, _) = fixture()
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        var shows = 0
        var closes = 0
        let presentation = MenuPresentation(
            show: { _, anchor, rect, edge in
                XCTAssertTrue(anchor === button)
                XCTAssertEqual(rect, button.bounds)
                XCTAssertEqual(edge, .minY)
                shows += 1
            },
            close: { _ in
                if closes == 0 { XCTAssertEqual(model.snapshot.stage, .ambient, "Close before publishing rest") }
                closes += 1
            })
        let menu = StatusMenuController(model: model, button: button, presentation: presentation)
        defer {
            menu.close()
            model.shutdown()
        }
        XCTAssertEqual(menu.popover.behavior, .transient)
        XCTAssertFalse(menu.popoverShouldDetach(menu.popover))
        menu.toggleMenu()
        menu.content.startBreak()
        XCTAssertEqual(shows, 1)
        XCTAssertEqual(closes, 1)
        XCTAssertEqual(model.snapshot.stage, .resting(kind: .focusReset, remaining: 4))
        // Reopening during rest stays possible, but tick updates never reopen or close it.
        menu.toggleMenu()
        clock.advance(1)
        model.tick()
        XCTAssertEqual(shows, 2)
        XCTAssertEqual(closes, 1)
        XCTAssertEqual(model.menuStatus, "A break is in progress")
        menu.content.postpone()
        XCTAssertEqual(closes, 2)
        XCTAssertEqual(model.snapshot.tracking.postponeRemaining, 300)
    }
    @MainActor func testAutomaticCountdownDismissesMenuOnce() async {
        let (model, clock, _, _, _, _, _) = fixture()
        var shows = 0
        var closes = 0
        let menu = StatusMenuController(
            model: model, button: NSButton(),
            presentation: MenuPresentation(
                show: { _, _, _, _ in shows += 1 }, close: { _ in closes += 1 }))
        defer {
            menu.close()
            model.shutdown()
        }
        menu.toggleMenu()
        clock.advance(10)
        model.tick()
        XCTAssertEqual(closes, 1)
        clock.advance(3)
        model.tick()
        XCTAssertEqual(shows, 1)
        XCTAssertEqual(closes, 1)
    }

    @MainActor func testGlassMenuHasBoundedNativeLayout() async {
        _ = NSApplication.shared
        let (model, _, _, _, _, _, _) = fixture()
        let menu = StatusMenuController(
            model: model, button: NSButton(),
            presentation: MenuPresentation(show: { _, _, _, _ in }, close: { _ in }))
        defer {
            menu.close()
            model.shutdown()
        }
        let controller = menu.popover.contentViewController!
        for _ in 0..<3 {
            menu.toggleMenu()
            controller.view.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(menu.popover.contentSize.height, 350)
            XCTAssertLessThan(menu.popover.contentSize.height, 550)
            XCTAssertEqual(controller.view.frame.width, 336, accuracy: 1)
            XCTAssertEqual(controller.view.frame.size, menu.popover.contentSize)
            XCTAssertEqual((controller.view as? NSHostingView<MenuPopoverView>)?.sizingOptions, [])
            let size = menu.popover.contentSize
            model.manualMeetingMode.toggle()
            controller.view.layoutSubtreeIfNeeded()
            XCTAssertEqual(menu.popover.contentSize, size, "State updates must not move the open menu")
            menu.dismiss()
        }
    }

    func testMenuViewportFitsShortAndOffsetScreens() {
        for screen in [
            CGRect(x: 0, y: 30, width: 1280, height: 650),
            CGRect(x: -1280, y: -700, width: 1280, height: 300),
            CGRect(x: 1440, y: 900, width: 1920, height: 1050),
        ] {
            let anchor = CGRect(x: screen.midX, y: screen.maxY, width: 24, height: 24)
            for ideal in [441.0, 1200.0] {
                let size = MenuPopoverLayout.size(idealHeight: ideal, visibleFrame: screen, anchor: anchor)
                XCTAssertEqual(size.width, 336)
                XCTAssertLessThanOrEqual(size.height + 24, screen.height)
                XCTAssertLessThanOrEqual(size.height, ideal)
            }
        }
    }

    @MainActor func testShortMenuCanScrollToItsBottomControls() throws {
        _ = NSApplication.shared
        let (model, _, _, _, _, _, _) = fixture()
        defer { model.shutdown() }
        let size = CGSize(width: 336, height: 260)
        let host = NSHostingView(rootView: MenuPopoverView(content: MenuBarView(model: model), size: size))
        host.sizingOptions = []
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        func scrollView(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
        }
        let scroll = try XCTUnwrap(scrollView(in: host))
        let document = try XCTUnwrap(scroll.documentView)
        XCTAssertGreaterThan(document.bounds.height, scroll.contentView.bounds.height)
        let bottom = document.isFlipped ? document.bounds.maxY - scroll.contentView.bounds.height : document.bounds.minY
        scroll.contentView.scroll(to: CGPoint(x: 0, y: bottom))
        scroll.reflectScrolledClipView(scroll.contentView)
        XCTAssertEqual(scroll.documentVisibleRect.minY, bottom, accuracy: 1)
        XCTAssertEqual(host.frame.size, size, "Scrolling must not resize the popover")
    }

    @MainActor func testNativeStatusPopoverWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["FAR_LIVE_PANEL_TEST"] == "1" else {
            throw XCTSkip("Set FAR_LIVE_PANEL_TEST=1 for physical desktop validation")
        }
        _ = NSApplication.shared
        try XCTSkipIf(NSScreen.screens.isEmpty, "The test host has no native display connection")
        let (model, _, _, _, _, _, _) = fixture()
        let menu = StatusMenuController(model: model)
        defer {
            menu.close()
            model.shutdown()
        }
        menu.toggleMenu()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(menu.popover.isShown)
        XCTAssertEqual(menu.popover.positioningRect, menu.button.bounds)
        let window = try XCTUnwrap(menu.button.window)
        let anchor = window.convertToScreen(menu.button.convert(menu.button.bounds, to: nil))
        let popup = try XCTUnwrap(menu.popover.contentViewController?.view.window)
        let screen = try XCTUnwrap(window.screen)
        XCTAssertGreaterThanOrEqual(popup.frame.minY, screen.visibleFrame.minY)
        XCTAssertLessThanOrEqual(popup.frame.maxY, screen.frame.maxY)
        XCTAssertGreaterThanOrEqual(popup.frame.minX, screen.visibleFrame.minX)
        XCTAssertLessThanOrEqual(popup.frame.maxX, screen.visibleFrame.maxX)
        XCTAssertLessThanOrEqual(popup.frame.maxY, anchor.maxY + 1)
        XCTAssertLessThan(abs(popup.frame.maxY - anchor.minY), 40)
        menu.content.startBreak()
        XCTAssertFalse(menu.popover.isShown)
    }

}
