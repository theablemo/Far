import AppKit
import FarCore
import SwiftUI
import XCTest

@testable import Far

@MainActor final class TestClock: FarClock {
    var now: TimeInterval = 0
    var date = Date(timeIntervalSince1970: 1_700_000_000)
    func advance(_ seconds: TimeInterval) {
        now += seconds
        date.addTimeInterval(seconds)
    }
}
@MainActor final class TestActivity: ActivityReading {
    var value = InputReading()
    func sample(now: TimeInterval) -> InputReading { value }
}
@MainActor final class TestAvailability: AvailabilityReading {
    var state = SessionAvailability()
    var onChange: (@MainActor () -> Void)?
    func reconcile() {}
    func stop() {}
}
@MainActor final class TestMeeting: MeetingReading {
    var statusDetail = "Test signal"
    var active = false
    func sample(now: TimeInterval) -> Bool { active }
}
@MainActor final class TestStore: TrackingStore {
    var value = TrackingState()
    func load() -> TrackingState { value }
    func save(_ state: TrackingState) { value = state }
}

@MainActor final class TestSound: BreakSoundPlaying {
    var played: [BreakEndSound] = []
    var succeeds = true
    func play(_ sound: BreakEndSound) -> Bool {
        played.append(sound)
        return succeeds
    }
}

/// Shared deterministic dependencies. Every test owns and removes its preference suite.
class FarTestCase: XCTestCase {
    @MainActor func makeDefaults() -> UserDefaults {
        let name = "FarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
    @MainActor func fixture() -> (
        AppModel, TestClock, TestActivity, TestAvailability, TestMeeting, TestStore, UserDefaults
    ) {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "endSoundEnabled")
        let clock = TestClock()
        let activity = TestActivity()
        let availability = TestAvailability()
        let meeting = TestMeeting()
        let store = TestStore()
        var config = BreakConfiguration()
        config.countdownDuration = 3
        config.focusResetThreshold = 10
        config.recoveryThreshold = 30
        config.focusResetDuration = 4
        config.recoveryDuration = 8
        let model = AppModel(
            defaults: defaults, clock: clock, activity: activity, availability: availability,
            meeting: meeting, store: store, configuration: config, startTimer: false)
        return (model, clock, activity, availability, meeting, store, defaults)
    }
}
