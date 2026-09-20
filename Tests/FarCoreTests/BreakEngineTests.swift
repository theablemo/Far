import XCTest

@testable import FarCore

final class BreakEngineTests: XCTestCase {
    private var config: BreakConfiguration {
        var c = BreakConfiguration()
        c.countdownDuration = 3
        c.focusResetThreshold = 10
        c.recoveryThreshold = 30
        c.focusResetDuration = 4
        c.recoveryDuration = 8
        c.maximumTypingDeferral = 6
        c.postponeDuration = 5
        return c
    }
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    @discardableResult private func tick(
        _ engine: inout BreakEngine, _ seconds: Double,
        _ context: ActivityContext = ActivityContext()
    ) -> [BreakEvent] {
        engine.tick(now: seconds, date: epoch.addingTimeInterval(seconds), context: context)
    }
    private func due() -> BreakEngine {
        var engine = BreakEngine(configuration: config)
        tick(&engine, 0)
        tick(&engine, 10)
        return engine
    }
    func testReadingCountsAndCountdownAutomaticallyStartsBreak() {
        var engine = due()
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
        tick(&engine, 11, ActivityContext(workingOutsideFar: true))
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 2))
        tick(&engine, 12, ActivityContext(intenseTyping: true, workingOutsideFar: true))
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 1))
        let events = tick(&engine, 13)
        XCTAssertTrue(events.contains(.breakStarted(.focusReset)))
        XCTAssertEqual(engine.snapshot.stage, .resting(kind: .focusReset, remaining: 4))
        XCTAssertEqual(engine.snapshot.today.screenTime, 13)
    }
    func testTypingCannotDeferForever() {
        var engine = BreakEngine(configuration: config)
        let typing = ActivityContext(intenseTyping: true)
        tick(&engine, 0, typing)
        tick(&engine, 10, typing)
        XCTAssertEqual(engine.snapshot.stage, .waiting(.focusReset))
        tick(&engine, 15, typing)
        XCTAssertEqual(engine.snapshot.stage, .waiting(.focusReset))
        tick(&engine, 16, typing)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
    }
    func testTypingPauseReleasesBeforeBound() {
        var engine = BreakEngine(configuration: config)
        tick(&engine, 0)
        tick(&engine, 10, ActivityContext(intenseTyping: true))
        tick(&engine, 11)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
    }
    func testPostponeUsesCountedTimeAndPreservesTrueStatistics() {
        var engine = due()
        XCTAssertEqual(engine.postponeCurrent(), .postponed(.focusReset))
        tick(&engine, 12)
        XCTAssertEqual(engine.snapshot.tracking.postponeRemaining, 3)
        tick(&engine, 12, ActivityContext(available: false))
        tick(&engine, 14, ActivityContext(available: false))
        tick(&engine, 14)
        XCTAssertEqual(engine.snapshot.tracking.postponeRemaining, 3)
        tick(&engine, 17)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 15)
        XCTAssertEqual(engine.snapshot.today.guidedBreaks, 0)
    }
    func testSkipOnlyChangesTheSelectedSchedule() {
        var engine = due()
        XCTAssertEqual(engine.skipCurrent(), .skipped(.focusReset))
        XCTAssertEqual(engine.snapshot.tracking.focusWork, 0)
        XCTAssertEqual(engine.snapshot.tracking.recoveryWork, 10)
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 10)
        tick(&engine, 19)
        XCTAssertEqual(engine.snapshot.stage, .ambient)
        tick(&engine, 20)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
    }
    func testRecoveryTakesPriorityAndSkipLeavesShortBreakDue() {
        var engine = BreakEngine(configuration: config)
        tick(&engine, 0, ActivityContext(meeting: true))
        tick(&engine, 30, ActivityContext(meeting: true))
        tick(&engine, 30)
        XCTAssertEqual(engine.snapshot.stage.kind, .recovery)
        engine.skipCurrent()
        XCTAssertEqual(engine.snapshot.dueKind, .focusReset)
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 30)
    }
    func testIncidentalActivityDoesNotCancelRestButSustainedWorkDoes() {
        var engine = due()
        tick(&engine, 13)
        tick(&engine, 13.5, ActivityContext(workingOutsideFar: true))
        tick(&engine, 14)
        XCTAssertEqual(engine.snapshot.stage, .resting(kind: .focusReset, remaining: 3))
        tick(&engine, 15, ActivityContext(workingOutsideFar: true))
        tick(&engine, 16, ActivityContext(workingOutsideFar: true))
        let events = tick(&engine, 17, ActivityContext(workingOutsideFar: true))
        XCTAssertTrue(events.contains(.interrupted(.focusReset)))
        XCTAssertEqual(engine.snapshot.today.guidedBreaks, 0)
        XCTAssertEqual(engine.snapshot.today.screenTime, 16)
        XCTAssertEqual(engine.snapshot.tracking.postponeRemaining, 5)
    }
    func testCompletionPreservesRecoveryProgress() {
        var engine = due()
        tick(&engine, 13)
        let events = tick(&engine, 17)
        XCTAssertEqual(engine.snapshot.stage, .completion(.focusReset))
        XCTAssertTrue(events.contains(.breakCompleted(.focusReset)))
        XCTAssertEqual(engine.snapshot.tracking.focusWork, 0)
        XCTAssertEqual(engine.snapshot.tracking.recoveryWork, 13)
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 0)
        XCTAssertEqual(engine.snapshot.today.guidedBreaks, 1)
        tick(&engine, 18)
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 1)
    }
    func testPostponeAndSkipDuringRestDoNotComplete() {
        for skip in [false, true] {
            var engine = due()
            tick(&engine, 13)
            if skip { engine.skipCurrent() } else { engine.postponeCurrent() }
            tick(&engine, 17)
            XCTAssertEqual(engine.snapshot.today.guidedBreaks, 0)
            XCTAssertFalse(engine.snapshot.tracking.hasKnownRest)
        }
    }
    func testMeetingCancelsCountdownAndRestWithoutCredit() {
        var engine = due()
        let meeting = ActivityContext(meeting: true)
        XCTAssertTrue(tick(&engine, 11, meeting).contains(.countdownCancelled))
        tick(&engine, 40, meeting)
        XCTAssertEqual(engine.snapshot.today.screenTime, 40)
        tick(&engine, 41)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .recovery, remaining: 3))
        tick(&engine, 44)
        XCTAssertTrue(tick(&engine, 45, meeting).contains(.interrupted(.recovery)))
        XCTAssertEqual(engine.snapshot.today.guidedBreaks, 0)
    }
    func testAwayCreditOncePerContinuousAbsenceAndNoGuidedCompletion() {
        var engine = due()
        let away = ActivityContext(available: false)
        tick(&engine, 11, away)
        XCTAssertTrue(tick(&engine, 41, away).contains(.awayRestCredited(.focusReset)))
        XCTAssertFalse(tick(&engine, 42, away).contains(.awayRestCredited(.focusReset)))
        XCTAssertTrue(tick(&engine, 311).contains(.awayRestCredited(.recovery)))
        XCTAssertEqual(engine.snapshot.today.screenTime, 11)
        XCTAssertEqual(engine.snapshot.today.guidedBreaks, 0)
        XCTAssertEqual(engine.snapshot.today.awayShortRests, 1)
        XCTAssertEqual(engine.snapshot.today.awayRecoveries, 1)
        XCTAssertEqual(engine.snapshot.tracking.recoveryWork, 0)
    }
    func testLockDuringRestDoesNotCompleteStaleTimerAfterWake() {
        var engine = due()
        tick(&engine, 13)
        tick(&engine, 14, ActivityContext(available: false))
        tick(&engine, 314)
        XCTAssertEqual(engine.snapshot.today.guidedBreaks, 0)
        XCTAssertEqual(engine.snapshot.today.awayRecoveries, 1)
        XCTAssertEqual(engine.snapshot.stage, .ambient)
    }
    func testMidnightSplitAndClockJumpUseMonotonicElapsedTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15))!
        var engine = BreakEngine(configuration: config, calendar: calendar)
        engine.tick(now: 0, date: midnight.addingTimeInterval(-5), context: ActivityContext())
        engine.tick(now: 10, date: midnight.addingTimeInterval(5), context: ActivityContext())
        XCTAssertEqual(engine.tracking.days["2026-09-14"]?.screenTime, 5)
        XCTAssertEqual(engine.tracking.days["2026-09-15"]?.screenTime, 5)
        engine.tick(now: 11, date: midnight.addingTimeInterval(3605), context: ActivityContext())
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 11)
    }
    func testRelaunchDoesNotInventDowntimeOrCompletion() throws {
        var first = due()
        tick(&first, 13)
        let data = try JSONEncoder().encode(first.tracking)
        var second = BreakEngine(
            configuration: config, tracking: try JSONDecoder().decode(TrackingState.self, from: data))
        tick(&second, 1_000_000)
        XCTAssertEqual(second.snapshot.today.screenTime, 0)  // a different calendar day
        XCTAssertEqual(second.snapshot.tracking.screenSinceRest, 13)
        XCTAssertEqual(second.snapshot.stage, .countdown(kind: .focusReset, remaining: 3))
        XCTAssertEqual(second.tracking.days.values.reduce(0) { $0 + $1.guidedBreaks }, 0)
    }
    func testNoTickCapAndDelayedRestCompletionCountsOnlyTail() {
        var engine = BreakEngine(configuration: config)
        tick(&engine, 0)
        tick(&engine, 10)
        XCTAssertEqual(engine.snapshot.today.screenTime, 10)
        tick(&engine, 13)
        tick(&engine, 22)
        XCTAssertEqual(engine.snapshot.today.screenTime, 18)
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 5)
    }
    func testAvailabilityConditionsAreIndependent() {
        var availability = SessionAvailability()
        availability.locked = true
        availability.sleeping = true
        availability.screenSaver = true
        availability.screensOff = true
        availability.sleeping = false
        availability.screensOff = false
        XCTAssertFalse(availability.available)
        availability.locked = false
        XCTAssertFalse(availability.available)
        availability.screenSaver = false
        XCTAssertTrue(availability.available)
    }
    func testInputClassifierThresholdPauseAndCounterReset() {
        var classifier = InputClassifier()
        XCTAssertFalse(classifier.sample(now: 0, keyCount: 100))
        XCTAssertFalse(classifier.sample(now: 1, keyCount: 105))
        XCTAssertTrue(classifier.sample(now: 2, keyCount: 110))
        XCTAssertTrue(classifier.sample(now: 4, keyCount: 110))
        XCTAssertFalse(classifier.sample(now: 5, keyCount: 110))
        XCTAssertFalse(classifier.sample(now: 6, keyCount: 0))
    }
    func testMeetingDebounceAndUnknownSignalEventuallyRelease() {
        var meeting = MeetingDebouncer()
        XCTAssertFalse(meeting.sample(now: 0, active: true))
        XCTAssertFalse(meeting.sample(now: 1, active: true))
        XCTAssertTrue(meeting.sample(now: 2, active: true))
        XCTAssertTrue(meeting.sample(now: 3, active: false))
        XCTAssertTrue(meeting.sample(now: 17, active: nil))
        XCTAssertFalse(meeting.sample(now: 18, active: nil))
    }
    func testNormalScheduleAcrossAnHourOfCountedTime() {
        var engine = BreakEngine()
        var completed: [BreakKind] = []
        for second in 0...3675 {
            for event in tick(&engine, Double(second)) {
                if case .breakCompleted(let kind) = event { completed.append(kind) }
            }
        }
        XCTAssertEqual(completed, [.focusReset, .focusReset])
        XCTAssertEqual(engine.snapshot.stage, .resting(kind: .recovery, remaining: 300))
        XCTAssertEqual(engine.snapshot.today.screenTime, 3615)
    }

    func testCountdownUsesElapsedTimeAndKeepsItsLengthDuringSettingsChanges() {
        var engine = BreakEngine()
        tick(&engine, 0)
        tick(&engine, 1200)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 15))
        XCTAssertEqual(engine.snapshot.countdownLength, 15)
        engine.configuration.countdownDuration = 60
        tick(&engine, 1204.25)
        XCTAssertEqual(engine.snapshot.stage, .countdown(kind: .focusReset, remaining: 10.75))
        XCTAssertEqual(engine.snapshot.countdownLength, 15)
        tick(&engine, 1215)
        XCTAssertEqual(engine.snapshot.stage, .resting(kind: .focusReset, remaining: 30))
    }

    func testScreenSaverAwayCreditIgnoresCustomGuidedDurationsAndDoesNotDoubleCount() {
        var configuration = config
        configuration.focusResetDuration = 5
        configuration.recoveryDuration = 60
        var engine = BreakEngine(configuration: configuration)
        tick(&engine, 0)
        var availability = SessionAvailability()
        availability.screenSaver = true
        let away = ActivityContext(available: availability.available)
        tick(&engine, 10, away)
        tick(&engine, 39, away)
        XCTAssertEqual(engine.snapshot.today.restCount, 0)
        tick(&engine, 40, away)
        XCTAssertEqual(engine.snapshot.today.restCount, 1)
        tick(&engine, 70, away)
        XCTAssertEqual(engine.snapshot.today.awayRecoveries, 0)
        tick(&engine, 310, away)
        tick(&engine, 400)
        XCTAssertEqual(engine.snapshot.today.awayRecoveries, 1)
        XCTAssertEqual(engine.snapshot.today.restCount, 1)
        XCTAssertEqual(engine.snapshot.today.screenTime, 10)
        XCTAssertEqual(engine.snapshot.tracking.screenSinceRest, 0)
        tick(&engine, 405)
        XCTAssertEqual(engine.snapshot.today.screenTime, 15)
    }

    func testPanelFitsNegativeCoordinatesAndSmallDisplays() {
        for visible in [
            CGRect(x: -1920, y: 40, width: 1920, height: 1040), CGRect(x: 80, y: 52, width: 300, height: 180),
        ] {
            for centered in [true, false] {
                let frame = PanelPlacement.frame(
                    panelSize: CGSize(width: 440, height: 330), visibleFrame: visible, centered: centered)
                XCTAssertTrue(visible.contains(frame))
                XCTAssertEqual(frame.midX, visible.midX)
                if centered { XCTAssertEqual(frame.midY, visible.midY) }
            }
        }
    }
}
