import AppKit
import FarCore
import SwiftUI
import XCTest

@testable import Far

final class VisualFixtureTests: FarTestCase {
    @MainActor func testMenuAndSettingsVisualFixturesWhenRequested() async throws {
        guard let directory = ProcessInfo.processInfo.environment["FAR_PREVIEW_DIR"] else {
            throw XCTSkip("Set FAR_PREVIEW_DIR to render offscreen fixtures")
        }
        _ = NSApplication.shared
        let defaults = makeDefaults()
        defaults.set(false, forKey: "endSoundEnabled")
        let model = AppModel(
            defaults: defaults, clock: TestClock(), activity: TestActivity(),
            availability: TestAvailability(), meeting: TestMeeting(), store: TestStore(), startTimer: false)
        defer { model.shutdown() }
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for section in PreferencesSection.allCases {
                try renderUtility(
                    PreferencesView(model: model, section: section, appVersion: "0.4.0 preview"), folder,
                    "settings-\(section.id)-\(name)", appearance, CGSize(width: 560, height: 650))
            }
            try renderUtility(
                MenuBarView(model: model), folder, "menu-\(name)", appearance, CGSize(width: 336, height: 450))
            try renderUtility(
                MenuPopoverView(content: MenuBarView(model: model), size: CGSize(width: 336, height: 260)),
                folder, "menu-short-screen-\(name)", appearance, CGSize(width: 336, height: 260))
        }
        model.startSuggestedBreak()
        try renderUtility(MenuBarView(model: model), folder, "menu-rest-light", .aqua, CGSize(width: 336, height: 450))
        try renderUtility(
            MenuBarView(model: model), folder, "menu-rest-dark", .darkAqua, CGSize(width: 336, height: 450))
        model.manualMeetingMode = true
        try renderUtility(
            MenuBarView(model: model), folder, "menu-meeting-light", .aqua, CGSize(width: 336, height: 450))
    }
    @MainActor private func renderUtility<V: View>(
        _ view: V, _ folder: URL, _ name: String,
        _ appearance: NSAppearance.Name, _ size: CGSize
    ) throws {
        // Liquid Glass requires the live WindowServer compositor. Cache-display
        // fixtures verify the opaque accessibility layout, not glass appearance.
        let host = NSHostingView(
            rootView:
                view
                .environment(\.farOpaqueSurfaces, true))
        // The menu popover sizes to its content. Capture those bounds rather than adding
        // transparent bands from the arbitrary screenshot canvas height.
        let captureSize = name.hasPrefix("menu-") ? host.fittingSize : size
        host.frame = CGRect(origin: .zero, size: captureSize)
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = host.appearance
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: folder.appendingPathComponent("\(name)-opaque.png"))
        window.orderOut(nil)
    }

    /// Opt-in offscreen fixtures use synthetic state and never start live monitoring.
    @MainActor func testRenderVisualFixturesWhenRequested() async throws {
        guard let directory = ProcessInfo.processInfo.environment["FAR_PREVIEW_DIR"] else {
            throw XCTSkip("Set FAR_PREVIEW_DIR to render offscreen fixtures")
        }
        _ = NSApplication.shared
        let defaults = makeDefaults()
        defaults.set(false, forKey: "endSoundEnabled")
        let clock = TestClock()
        let store = TestStore()
        store.value.hasKnownRest = true
        store.value.focusWork = 1320
        store.value.recoveryWork = 2640
        store.value.screenSinceRest = 1320
        var totals = DailyTotals()
        totals.screenTime = 7920
        totals.guidedBreaks = 3
        store.value.days["2023-11-14"] = totals
        let model = AppModel(
            defaults: defaults, clock: clock, activity: TestActivity(),
            availability: TestAvailability(), meeting: TestMeeting(), store: store, startTimer: false)
        defer { model.shutdown() }
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try render(model, folder, "countdown-light", .aqua, BreakPanelLayout.notice.size)
        try render(model, folder, "countdown-dark", .darkAqua, BreakPanelLayout.notice.size)
        clock.advance(7.5)
        model.tick()
        try render(model, folder, "countdown-halfway-light", .aqua, BreakPanelLayout.notice.size)
        clock.advance(7.5)
        model.tick()
        try render(model, folder, "rest-light", .aqua, BreakPanelLayout.rest.size)
        try render(model, folder, "rest-dark", .darkAqua, BreakPanelLayout.rest.size)
        try render(model, folder, "rest-material-light", .aqua, BreakPanelLayout.rest.size, opaque: false)
        try render(model, folder, "rest-material-dark", .darkAqua, BreakPanelLayout.rest.size, opaque: false)
        clock.advance(30)
        model.tick()
        try render(model, folder, "completion-light", .aqua, BreakPanelLayout.completion.size)
        try render(model, folder, "completion-dark", .darkAqua, BreakPanelLayout.completion.size)
        clock.advance(3600)
        model.tick()
        try render(model, folder, "recovery-notice-light", .aqua, BreakPanelLayout.notice.size)
        clock.advance(15)
        model.tick()
        try render(model, folder, "recovery-light", .aqua, BreakPanelLayout.rest.size)
        try render(model, folder, "recovery-dark", .darkAqua, BreakPanelLayout.rest.size)
    }
    @MainActor private func render(
        _ model: AppModel, _ folder: URL, _ name: String,
        _ appearance: NSAppearance.Name, _ size: CGSize, opaque: Bool = true
    ) throws {
        let content = ReminderPanelView(snapshot: model.snapshot, postpone: {}, skip: {})
        let host = BreakPanelSurface(content: content)
        host.frame = CGRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = host
        window.appearance = host.appearance
        host.update(content: content, radius: BreakPanelLayout(model.snapshot.stage)!.radius, opaque: opaque)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return XCTFail("No image buffer")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        XCTAssertLessThan(
            bitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? 1, 0.01,
            "The native surface must not paint square corners")
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: folder.appendingPathComponent("\(name).png"))

        window.orderOut(nil)
    }
}
