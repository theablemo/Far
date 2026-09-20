import AppKit
import FarCore
import SwiftUI
import XCTest

@testable import Far

final class ReminderPanelTests: FarTestCase {
    @MainActor func testDimmingCoversDisplaysAndClearsOnEveryExit() async throws {
        let (model, clock, _, availability, _, _, _) = fixture()
        let first = BreakPanelDisplay(
            id: 1, frame: CGRect(x: -1440, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: -1440, y: 40, width: 1440, height: 830))
        let second = BreakPanelDisplay(
            id: 2, frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            visibleFrame: CGRect(x: 0, y: 40, width: 1280, height: 730))
        var displays = [first, second]
        let controller = ReminderPanelController(
            model: model,
            environment: BreakPanelEnvironment(
                displays: { displays }, pointer: { .zero }, reduceMotion: { true }, reduceTransparency: { true }))
        defer {
            controller.close()
            model.shutdown()
        }
        clock.advance(10)
        model.tick()
        XCTAssertTrue(controller.dimming.panels.isEmpty, "No dimming before rest")
        clock.advance(3)
        model.tick()
        XCTAssertEqual(controller.dimming.panels.count, 2)
        for display in displays {
            let backdrop = try XCTUnwrap(controller.dimming.panels[display.id])
            XCTAssertEqual(backdrop.frame, display.frame)
            XCTAssertTrue(backdrop.ignoresMouseEvents)
            XCTAssertFalse(backdrop.canBecomeKey)
            XCTAssertTrue(backdrop.isVisible)
            XCTAssertLessThan(backdrop.level.rawValue, controller.panel.level.rawValue)
            XCTAssertFalse(
                SystemActivityReader.containsInteractiveWindow(
                    [backdrop], at: CGPoint(x: display.frame.midX, y: display.frame.midY)),
                "Click-through dimming must not make work in other apps look like input to Far")
        }
        displays = [second]
        controller.repositionIfVisible()
        XCTAssertEqual(Set(controller.dimming.panels.keys), [2])
        clock.advance(4)
        model.tick()
        XCTAssertTrue(controller.dimming.panels.isEmpty, "Completion clears dimming")
        model.startSuggestedBreak()
        model.postponeBreak()
        XCTAssertTrue(controller.dimming.panels.isEmpty)
        model.startSuggestedBreak()
        model.skipBreak()
        XCTAssertTrue(controller.dimming.panels.isEmpty)
        model.startSuggestedBreak()
        availability.state.screenSaver = true
        availability.onChange?()
        XCTAssertTrue(controller.dimming.panels.isEmpty)
        availability.state.screenSaver = false
        availability.onChange?()
        model.startSuggestedBreak()
        model.manualMeetingMode = true
        XCTAssertTrue(controller.dimming.panels.isEmpty)
    }

    @MainActor func testCancelledDimmingFadeCannotLeaveAnOverlay() async throws {
        let (model, _, _, _, _, _, _) = fixture()
        let display = BreakPanelDisplay(
            id: 1, frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            visibleFrame: CGRect(x: 0, y: 40, width: 1280, height: 730))
        let controller = ReminderPanelController(
            model: model,
            environment: BreakPanelEnvironment(
                displays: { [display] }, pointer: { .zero }, reduceMotion: { false }, reduceTransparency: { false }))
        defer {
            controller.close()
            model.shutdown()
        }
        model.startSuggestedBreak()
        let old = try XCTUnwrap(controller.dimming.panels[1])
        model.skipBreak()
        model.startSuggestedBreak()
        let next = try XCTUnwrap(controller.dimming.panels[1])
        try await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(old.isVisible)
        XCTAssertTrue(next.isVisible)
        XCTAssertEqual(next.alphaValue, 1, accuracy: 0.01)
        controller.close()
        XCTAssertFalse(next.isVisible)
        XCTAssertTrue(controller.dimming.panels.isEmpty)
    }

    /// Exercise native windows and subscriptions with injected display geometry.
    @MainActor func testActualHostTransitionsStayCentered() async throws {
        _ = NSApplication.shared
        let (model, clock, _, _, _, _, _) = fixture()
        let display = BreakPanelDisplay(
            id: 1, frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: -1920, y: 40, width: 1920, height: 1015))
        let environment = BreakPanelEnvironment(
            displays: { [display] }, pointer: { CGPoint(x: -400, y: 200) },
            reduceMotion: { false }, reduceTransparency: { false })
        let controller = ReminderPanelController(model: model, environment: environment)
        defer {
            controller.close()
            model.shutdown()
        }
        clock.advance(10)
        model.tick()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(controller.panel.isVisible)
        XCTAssertEqual(controller.panel.frame.maxY, display.visibleFrame.maxY - 20, accuracy: 1)
        XCTAssertEqual(controller.surface.hosting.rootView.snapshot.stage, model.snapshot.stage)
        XCTAssertEqual(controller.surface.hosting.sizingOptions, [])
        XCTAssertNotNil(controller.surface.material.maskImage)
        XCTAssertEqual(controller.surface.layer?.cornerRadius, 30)
        clock.advance(3)
        model.tick()
        try await Task.sleep(for: .milliseconds(500))
        let center = controller.panel.frame
        XCTAssertEqual(center.midY, display.visibleFrame.midY, accuracy: 0.51)
        XCTAssertEqual(center.midX, display.visibleFrame.midX, accuracy: 0.51)
        XCTAssertEqual(center.size, BreakPanelLayout.rest.size)
        XCTAssertEqual(controller.surface.hosting.rootView.snapshot.stage, model.snapshot.stage)
        for _ in 0..<8 {
            clock.advance(0.25)
            model.tick()
            controller.surface.layoutSubtreeIfNeeded()
            XCTAssertEqual(controller.panel.frame, center)
            XCTAssertEqual(controller.surface.hosting.rootView.snapshot.stage, model.snapshot.stage)
        }
        clock.advance(2)
        model.tick()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(controller.panel.frame.midY, display.visibleFrame.midY, accuracy: 0.51)
        XCTAssertEqual(controller.panel.frame.size, BreakPanelLayout.completion.size)
    }

    @MainActor func testActualHostRepositionAndRapidHideShow() async throws {
        let (model, clock, _, availability, _, _, _) = fixture()
        let first = BreakPanelDisplay(
            id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 830))
        let second = BreakPanelDisplay(
            id: 2, frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
            visibleFrame: CGRect(x: 1440, y: 40, width: 1280, height: 730))
        var displays = [first, second]
        var pointer = CGPoint(x: 500, y: 500)
        let environment = BreakPanelEnvironment(
            displays: { displays }, pointer: { pointer },
            reduceMotion: { true }, reduceTransparency: { true })
        let controller = ReminderPanelController(model: model, environment: environment)
        defer {
            controller.close()
            model.shutdown()
        }
        clock.advance(10)
        model.tick()
        pointer = CGPoint(x: 1800, y: 300)
        clock.advance(3)
        model.tick()
        XCTAssertEqual(controller.panel.frame.midX, first.visibleFrame.midX)
        XCTAssertEqual(controller.panel.frame.midY, first.visibleFrame.midY)
        XCTAssertTrue(controller.surface.material.isHidden)
        XCTAssertEqual(controller.surface.layer?.cornerRadius, 36)
        displays = [second]
        controller.repositionIfVisible()
        XCTAssertEqual(controller.panel.frame.midX, second.visibleFrame.midX)
        XCTAssertEqual(controller.panel.frame.midY, second.visibleFrame.midY)
        availability.state.locked = true
        availability.onChange?()
        XCTAssertFalse(controller.panel.isVisible)
        availability.state.locked = false
        availability.onChange?()
        XCTAssertTrue(controller.panel.isVisible)
        XCTAssertEqual(controller.panel.frame.maxY, second.visibleFrame.maxY - 20)
        // The actual view's controls reach the model, rather than testing only engine methods.
        controller.surface.hosting.rootView.postpone()
        XCTAssertFalse(controller.panel.isVisible)
        XCTAssertEqual(model.snapshot.tracking.postponeRemaining, 300)
    }

    @MainActor func testCancelledFadeCannotHideNewNotice() async throws {
        let (model, clock, _, availability, _, _, _) = fixture()
        let display = BreakPanelDisplay(
            id: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 830))
        let environment = BreakPanelEnvironment(
            displays: { [display] }, pointer: { CGPoint(x: 200, y: 200) },
            reduceMotion: { false }, reduceTransparency: { false })
        let controller = ReminderPanelController(model: model, environment: environment)
        defer {
            controller.close()
            model.shutdown()
        }
        clock.advance(10)
        model.tick()
        try await Task.sleep(for: .milliseconds(200))
        availability.state.locked = true
        availability.onChange?()
        try await Task.sleep(for: .milliseconds(30))
        availability.state.locked = false
        availability.onChange?()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(controller.panel.isVisible)
        XCTAssertEqual(controller.panel.alphaValue, 1, accuracy: 0.01)
        XCTAssertEqual(controller.surface.hosting.rootView.snapshot.stage, model.snapshot.stage)
    }

    @MainActor func testNativeDesktopFocusWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["FAR_LIVE_PANEL_TEST"] == "1" else {
            throw XCTSkip("Set FAR_LIVE_PANEL_TEST=1 for physical desktop validation")
        }
        _ = NSApplication.shared
        try XCTSkipIf(NSScreen.screens.isEmpty, "The test host has no native display connection")
        let (model, clock, _, _, _, _, _) = fixture()
        let originalApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let originalKey = NSApp.keyWindow
        let controller = ReminderPanelController(model: model)
        defer {
            controller.close()
            model.shutdown()
        }
        clock.advance(10)
        model.tick()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(controller.panel.isVisible)
        XCTAssertTrue(NSApp.keyWindow === originalKey)
        clock.advance(3)
        model.tick()
        try await Task.sleep(for: .milliseconds(500))
        let display = try XCTUnwrap(controller.panel.screen)
        XCTAssertEqual(controller.panel.frame.midY, display.visibleFrame.midY, accuracy: 1)
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.processIdentifier, originalApp)
    }

    @MainActor func testGlassSurfaceKeepsContentWhenTransparencyChanges() throws {
        _ = NSApplication.shared
        let (model, _, _, _, _, _, _) = fixture()
        defer { model.shutdown() }
        let content = ReminderPanelView(snapshot: model.snapshot, postpone: {}, skip: {})
        let surface = BreakPanelSurface(content: content)
        surface.frame = CGRect(origin: .zero, size: BreakPanelLayout.rest.size)
        if #available(macOS 26.0, *) {
            XCTAssertNotNil(surface.glass, "macOS 26 must instantiate the public glass view")
        }
        for opaque in [false, true, false, true] {
            surface.update(content: content, radius: 36, opaque: opaque)
            surface.layoutSubtreeIfNeeded()
            XCTAssertTrue(surface.hosting.isDescendant(of: surface))
            XCTAssertEqual(surface.hosting.frame.size, surface.bounds.size)
            XCTAssertEqual(surface.material.isHidden, opaque || surface.glass != nil)
            if let glass = surface.glass {
                XCTAssertEqual(glass.isHidden, opaque)
                XCTAssertEqual(glass.value(forKey: "cornerRadius") as? CGFloat, 36)
                if opaque {
                    XCTAssertTrue(surface.hosting.superview === surface)
                } else {
                    XCTAssertTrue(glass.value(forKey: "contentView") as? NSView === surface.hosting)
                }
            }
        }
        let background = GlassPillSurface()
        background.frame = CGRect(x: 0, y: 0, width: 140, height: 36)
        XCTAssertNil(background.hitTest(CGPoint(x: 30, y: 18)))
    }

}
