import Foundation

public enum BreakKind: String, Codable, Sendable {
    case focusReset, recovery
    public var duration: TimeInterval { self == .focusReset ? 30 : 300 }
}

public enum BreakStage: Equatable, Sendable {
    case ambient
    case waiting(BreakKind)
    case countdown(kind: BreakKind, remaining: TimeInterval)
    case resting(kind: BreakKind, remaining: TimeInterval)
    case completion(BreakKind)

    public var kind: BreakKind? {
        switch self {
        case .ambient: nil
        case .waiting(let kind), .completion(let kind): kind
        case .countdown(let kind, _), .resting(let kind, _): kind
        }
    }
    public var offersActions: Bool {
        switch self {
        case .countdown, .resting: true
        default: false
        }
    }
}

public enum BreakEvent: Equatable, Sendable {
    case countdownStarted(BreakKind)
    case countdownCancelled
    case breakStarted(BreakKind)
    case breakCompleted(BreakKind)
    case postponed(BreakKind)
    case skipped(BreakKind)
    case interrupted(BreakKind)
    case awayRestCredited(BreakKind)
}

public struct BreakConfiguration: Equatable, Sendable {
    public var focusResetThreshold: TimeInterval = 1200
    public var recoveryThreshold: TimeInterval = 3600
    public var focusResetDuration: TimeInterval = 30
    public var recoveryDuration: TimeInterval = 300
    public var maximumTypingDeferral: TimeInterval = 120
    public var countdownDuration: TimeInterval = 15
    public var postponeDuration: TimeInterval = 300
    public var interruptionDuration: TimeInterval = 3
    public var completionDuration: TimeInterval = 4
    public init() {}
    public static let balanced = BreakConfiguration()
    public func duration(for kind: BreakKind) -> TimeInterval {
        kind == .focusReset ? focusResetDuration : recoveryDuration
    }
}

public struct ActivityContext: Equatable, Sendable {
    public var available: Bool
    public var meeting: Bool
    public var intenseTyping: Bool
    /// Input in the interval since the previous sample, excluding Far's own controls.
    public var workingOutsideFar: Bool
    public init(
        available: Bool = true, meeting: Bool = false,
        intenseTyping: Bool = false, workingOutsideFar: Bool = false
    ) {
        self.available = available
        self.meeting = meeting
        self.intenseTyping = intenseTyping
        self.workingOutsideFar = workingOutsideFar
    }
}

public struct DailyTotals: Codable, Equatable, Sendable {
    public var screenTime: TimeInterval = 0
    public var guidedBreaks: Int = 0
    public var awayShortRests: Int = 0
    public var awayRecoveries: Int = 0
    public init() {}
    /// A long absence also earns short-rest credit; count that absence only once.
    public var restCount: Int { guidedBreaks + awayShortRests }
}

/// Only measured totals and schedule progress are persisted. No event history or input contents.
public struct TrackingState: Codable, Equatable, Sendable {
    public var version = 1
    public var focusWork: TimeInterval = 0
    public var recoveryWork: TimeInterval = 0
    public var screenSinceRest: TimeInterval = 0
    public var hasKnownRest = false
    public var postponeRemaining: TimeInterval = 0
    public var pausedUntil: Date?
    public var days: [String: DailyTotals] = [:]
    public init() {}
}

public struct BreakSnapshot: Equatable, Sendable {
    public let stage: BreakStage
    public let tracking: TrackingState
    public let today: DailyTotals
    public let configuration: BreakConfiguration
    public let countdownLength: TimeInterval
    public var dueKind: BreakKind? {
        if tracking.recoveryWork >= configuration.recoveryThreshold { return .recovery }
        if tracking.focusWork >= configuration.focusResetThreshold { return .focusReset }
        return nil
    }
    public var secondsUntilNextBreak: TimeInterval {
        max(
            tracking.postponeRemaining,
            min(
                max(0, configuration.focusResetThreshold - tracking.focusWork),
                max(0, configuration.recoveryThreshold - tracking.recoveryWork)))
    }
}
