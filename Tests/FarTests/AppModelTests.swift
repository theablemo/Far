import AppKit
import FarCore
import SwiftUI
import XCTest

@testable import Far

final class AppModelTests: FarTestCase {
    @MainActor func testEndSoundSelectionPersistencePreviewAndCompletion() async {
        let defaults = makeDefaults()
        let clock = TestClock()
        let sound = TestSound()
        let model = AppModel(
            defaults: defaults, clock: clock, activity: TestActivity(),
            availability: TestAvailability(), meeting: TestMeeting(), store: TestStore(), startTimer: false,
            soundPlayer: sound)
        defer { model.shutdown() }
        XCTAssertEqual(model.endSound, .glass)
        model.endSound = .tink
        XCTAssertEqual(defaults.string(forKey: "endSound"), "Tink")
        model.previewEndSound()
        model.startSuggestedBreak()
        clock.advance(30)
        model.tick()
        clock.advance(1)
        model.tick()
        XCTAssertEqual(sound.played, [.tink, .tink], "Completion sound plays exactly once")
        model.endSoundEnabled = false
        model.startSuggestedBreak()
        clock.advance(30)
        model.tick()
        XCTAssertEqual(sound.played.count, 2)
        model.endSoundEnabled = true
        model.startSuggestedBreak()
        model.skipBreak()
        clock.advance(30)
        model.tick()
        XCTAssertEqual(sound.played.count, 2, "Skipping does not play completion audio")
        sound.succeeds = false
        model.previewEndSound()
        XCTAssertNotNil(model.soundMessage)
        let relaunched = AppModel(
            defaults: defaults, clock: clock, activity: TestActivity(),
            availability: TestAvailability(), meeting: TestMeeting(), store: TestStore(), startTimer: false,
            soundPlayer: sound)
        XCTAssertEqual(relaunched.endSound, .tink)
        relaunched.shutdown()
        for choice in BreakEndSound.allCases {
            XCTAssertNotNil(NSSound(named: NSSound.Name(choice.rawValue)), "Installed sound: \(choice.rawValue)")
        }
    }

    @MainActor func testCountdownDefaultMigrationAndCustomPreference() async {
        for saved in [nil, 3, 10, 60] as [Int?] {
            let defaults = makeDefaults()
            if let saved { defaults.set(saved, forKey: "timing.countdown") }
            let model = AppModel(
                defaults: defaults, clock: TestClock(), activity: TestActivity(),
                availability: TestAvailability(), meeting: TestMeeting(), store: TestStore(), startTimer: false)
            XCTAssertEqual(model.timingValue(.countdown), saved == nil || saved == 3 ? 15 : saved!)
            model.shutdown()
        }
    }

    @MainActor func testScreenSaverNotificationsReachTrackingAndOverlapWithLock() async {
        let workspace = NotificationCenter()
        let distributed = NotificationCenter()
        let monitor = SystemAvailabilityMonitor(
            workspace: workspace, distributed: distributed,
            application: NotificationCenter(), systemReconciliation: { $0.screensOff = false })
        let clock = TestClock()
        let defaults = makeDefaults()
        let model = AppModel(
            defaults: defaults, clock: clock, activity: TestActivity(),
            availability: monitor, meeting: TestMeeting(), store: TestStore(), startTimer: false)
        defer { model.shutdown() }
        clock.advance(100)
        model.tick()
        model.startSuggestedBreak()
        distributed.post(name: .init("com.apple.screensaver.didstart"), object: nil)
        XCTAssertEqual(model.suppressionReason, "Screen saver active")
        XCTAssertEqual(model.snapshot.stage, .ambient)
        clock.advance(30)
        model.tick()
        XCTAssertEqual(model.snapshot.today.awayShortRests, 1)
        distributed.post(name: .init("com.apple.screenIsLocked"), object: nil)
        distributed.post(name: .init("com.apple.screensaver.willstop"), object: nil)
        XCTAssertFalse(monitor.state.screenSaver)
        XCTAssertFalse(monitor.state.available, "Stopping the saver cannot clear the independent lock")
        clock.advance(270)
        model.tick()
        XCTAssertEqual(model.snapshot.today.awayRecoveries, 1)
        distributed.post(name: .init("com.apple.screenIsUnlocked"), object: nil)
        XCTAssertTrue(monitor.state.available)
        XCTAssertEqual(model.snapshot.today.screenTime, 100)
        XCTAssertEqual(model.snapshot.today.guidedBreaks, 0)
        clock.advance(5)
        model.tick()
        XCTAssertEqual(model.snapshot.today.screenTime, 105)
        monitor.stop()
        distributed.post(name: .init("com.apple.screensaver.didstart"), object: nil)
        XCTAssertFalse(monitor.state.screenSaver, "Stopped observers must not receive events")
    }

    @MainActor func testRealTimerDrivesCountdownRestAndOneCompletion() async throws {
        let defaults = makeDefaults()
        var configuration = BreakConfiguration()
        configuration.focusResetThreshold = 0.5
        configuration.countdownDuration = 1.25
        configuration.focusResetDuration = 0.5
        let sound = TestSound()
        let model = AppModel(
            defaults: defaults, activity: TestActivity(), availability: TestAvailability(),
            meeting: TestMeeting(), store: TestStore(), configuration: configuration, soundPlayer: sound)
        defer { model.shutdown() }
        let started = ContinuousClock.now
        var sawCountdown = false
        var sawRest = false
        while started.duration(to: .now) < .seconds(5), model.snapshot.today.guidedBreaks == 0 {
            if case .countdown = model.snapshot.stage { sawCountdown = true }
            if case .resting = model.snapshot.stage { sawRest = true }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(sawCountdown)
        XCTAssertTrue(sawRest)
        XCTAssertEqual(model.snapshot.today.guidedBreaks, 1)
        XCTAssertEqual(sound.played, [.glass])
    }
    @MainActor func testControlsPersistSchedulesWithoutFakingCompletions() async {
        let (model, clock, _, _, _, store, _) = fixture()
        clock.advance(10)
        model.tick()
        model.postponeMinutes = 7
        model.postponeBreak()
        XCTAssertEqual(store.value.postponeRemaining, 420)
        XCTAssertEqual(store.value.screenSinceRest, 10)
        model.shutdown()
    }
    @MainActor func testMeetingModesAndUnavailableStateSuppressPresentation() async {
        let (model, clock, _, availability, meeting, _, _) = fixture()
        clock.advance(10)
        model.tick()
        model.manualMeetingMode = true
        XCTAssertEqual(model.snapshot.stage, .ambient)
        XCTAssertEqual(model.suppressionReason, "Meeting mode is on")
        model.manualMeetingMode = false
        XCTAssertEqual(model.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
        meeting.active = true
        model.tick()
        XCTAssertEqual(model.snapshot.stage, .ambient)
        model.automaticMeetingDetection = false
        XCTAssertEqual(model.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
        availability.state.locked = true
        availability.onChange?()
        XCTAssertEqual(model.suppressionReason, "Mac locked")
        XCTAssertEqual(model.snapshot.stage, .ambient)
        model.shutdown()
    }
    @MainActor func testSettingsBoundsAndCompletionPersist() async {
        let (model, clock, _, _, _, store, defaults) = fixture()
        model.postponeMinutes = 90
        XCTAssertEqual(model.postponeMinutes, 60)
        model.postponeMinutes = 0
        XCTAssertEqual(model.postponeMinutes, 1)
        XCTAssertEqual(defaults.integer(forKey: "postponeMinutes"), 1)
        clock.advance(10)
        model.tick()
        clock.advance(3)
        model.tick()
        clock.advance(4)
        model.tick()
        XCTAssertEqual(model.snapshot.today.guidedBreaks, 1)
        XCTAssertTrue(store.value.hasKnownRest)
        model.shutdown()
    }
    @MainActor func testStartupNeverCountsClosedAppTime() async {
        let (model, clock, _, _, _, store, defaults) = fixture()
        clock.advance(10)
        model.tick(forceSave: true)
        model.shutdown()
        clock.advance(50000)
        let second = AppModel(
            defaults: defaults, clock: clock, activity: TestActivity(),
            availability: TestAvailability(), meeting: TestMeeting(), store: store, startTimer: false)
        XCTAssertEqual(second.snapshot.tracking.screenSinceRest, 10)
        second.shutdown()
    }
    @MainActor func testLocalStoreRoundTrip() async {
        let defaults = makeDefaults()
        let store = LocalTrackingStore(defaults: defaults)
        var state = TrackingState()
        state.focusWork = 50
        state.screenSinceRest = 150
        state.hasKnownRest = true
        store.save(state)
        XCTAssertEqual(store.load(), state)
        defaults.removeObject(forKey: "trackingState.v1")
    }

    @MainActor func testAllTimingSettingsClampPersistAndRestore() async {
        let (model, clock, _, _, _, store, defaults) = fixture()
        for setting in TimingSetting.allCases {
            model.setTiming(setting, to: -100)
            XCTAssertEqual(model.timingValue(setting), setting.bounds.lowerBound)
            model.setTiming(setting, to: 9999)
            XCTAssertEqual(model.timingValue(setting), setting.bounds.upperBound)
            XCTAssertEqual(defaults.integer(forKey: setting.storageKey), setting.bounds.upperBound)
        }
        model.shutdown()
        let next = AppModel(
            defaults: defaults, clock: clock, activity: TestActivity(),
            availability: TestAvailability(), meeting: TestMeeting(), store: store, startTimer: false)
        for setting in TimingSetting.allCases { XCTAssertEqual(next.timingValue(setting), setting.bounds.upperBound) }
        next.resetTimings()
        for setting in TimingSetting.allCases { XCTAssertEqual(next.timingValue(setting), setting.defaultValue) }
        next.shutdown()
    }
    @MainActor func testCustomScheduleAndDurationChangesKeepCurrentRestDeadline() async {
        let (model, clock, _, _, _, _, _) = fixture()
        model.setTiming(.focusInterval, to: 2)
        model.setTiming(.recoveryInterval, to: 10)
        model.setTiming(.focusDuration, to: 15)
        model.setTiming(.countdown, to: 5)
        clock.advance(119)
        model.tick()
        XCTAssertEqual(model.snapshot.stage, .ambient)
        clock.advance(1)
        model.tick()
        XCTAssertEqual(model.snapshot.stage, .countdown(kind: .focusReset, remaining: 5))
        clock.advance(5)
        model.tick()
        XCTAssertEqual(model.snapshot.stage, .resting(kind: .focusReset, remaining: 15))
        model.setTiming(.focusDuration, to: 45)
        clock.advance(15)
        model.tick()
        XCTAssertEqual(model.snapshot.today.guidedBreaks, 1)
        model.startSuggestedBreak()
        XCTAssertEqual(model.snapshot.stage, .resting(kind: .focusReset, remaining: 45))
        model.skipBreak()
        let sinceRest = model.snapshot.tracking.screenSinceRest
        model.resetTimings()
        XCTAssertEqual(model.snapshot.tracking.screenSinceRest, sinceRest)
        XCTAssertEqual(model.snapshot.today.guidedBreaks, 1)
        model.shutdown()
    }
    @MainActor func testCustomRecoveryAndPauseDuration() async {
        let (model, clock, _, _, _, _, _) = fixture()
        model.setTiming(.focusInterval, to: 4)
        model.setTiming(.recoveryInterval, to: 2)
        model.setTiming(.recoveryDuration, to: 2)
        model.setTiming(.pauseMinutes, to: 7)
        model.pauseReminders()
        XCTAssertEqual(model.snapshot.tracking.pausedUntil, clock.date.addingTimeInterval(420))
        model.resumeReminders()
        clock.advance(120)
        model.tick()
        clock.advance(3)
        model.tick()
        XCTAssertEqual(model.snapshot.stage, .resting(kind: .recovery, remaining: 120))
        clock.advance(120)
        model.tick()
        XCTAssertEqual(model.snapshot.today.guidedBreaks, 1)
        model.shutdown()
    }
}
