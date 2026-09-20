import Foundation

/// Keyboard counters contain no characters. Pointer movement is deliberately absent.
public struct InputClassifier: Sendable {
    private var samples: [(time: TimeInterval, count: UInt32)] = []
    private var lastKeyTime: TimeInterval?
    private var lastCount: UInt32?
    private var typing = false
    public init() {}
    public mutating func sample(now: TimeInterval, keyCount: UInt32) -> Bool {
        if let lastCount, keyCount != lastCount { lastKeyTime = now }
        if let last = samples.last, now < last.time {
            samples.removeAll()
            typing = false
        }
        if let lastCount, keyCount < lastCount {
            samples.removeAll()
            typing = false
        }
        lastCount = keyCount
        samples.append((now, keyCount))
        while samples.count > 1 && samples[1].time <= now - 5 { samples.removeFirst() }
        if let first = samples.first, keyCount &- first.count >= 10 { typing = true }
        if lastKeyTime.map({ now - $0 >= 3 }) ?? true { typing = false }
        return typing
    }
}

public struct MeetingDebouncer: Sendable {
    public private(set) var suppressed = false
    private var began: TimeInterval?
    private var ended: TimeInterval?
    public init() {}
    public mutating func sample(now: TimeInterval, active: Bool?) -> Bool {
        // Unknown is surfaced by the adapter; it cannot suppress reminders indefinitely.
        if active == true {
            ended = nil
            if began == nil { began = now }
            if now - (began ?? now) >= 2 { suppressed = true }
        } else {
            began = nil
            if ended == nil { ended = now }
            if now - (ended ?? now) >= 15 { suppressed = false }
        }
        return suppressed
    }
}

public struct SessionAvailability: Equatable, Sendable {
    public var locked = false
    public var sleeping = false
    public var screensOff = false
    public var screenSaver = false
    public var inactiveSession = false
    public init() {}
    public var available: Bool { !locked && !sleeping && !screensOff && !screenSaver && !inactiveSession }
    public var reason: String? {
        if locked { return "Mac locked" }
        if sleeping { return "Mac asleep" }
        if inactiveSession { return "Inactive login session" }
        if screenSaver { return "Screen saver active" }
        if screensOff { return "Displays asleep" }
        return nil
    }
}
