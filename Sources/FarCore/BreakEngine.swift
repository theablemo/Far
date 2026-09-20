import Foundation

/// Deterministic scheduling and accounting; system effects belong to the app adapters.
public struct BreakEngine: Sendable {
    public var configuration: BreakConfiguration
    public private(set) var tracking: TrackingState
    private var stage: BreakStage = .ambient
    private var previousTime: TimeInterval?
    private var previousContext = ActivityContext(available: false)
    private var currentDate = Date()
    private var eligibleDeferral: TimeInterval = 0
    private var countdownEnds: TimeInterval?
    private var countdownLength: TimeInterval = 0
    private var restEnds: TimeInterval?
    private var completionEnds: TimeInterval?
    private var outsideWork: TimeInterval = 0
    private var awayStarted: TimeInterval?
    private var awayShortCredited = false
    private var awayRecoveryCredited = false
    private var calendar: Calendar

    public init(
        configuration: BreakConfiguration = .balanced,
        tracking: TrackingState = TrackingState(), calendar: Calendar = .current
    ) {
        self.configuration = configuration
        self.tracking = tracking.version == 1 ? tracking : TrackingState()
        self.calendar = calendar
    }
    public var snapshot: BreakSnapshot {
        BreakSnapshot(
            stage: stage, tracking: tracking,
            today: tracking.days[dayKey(currentDate)] ?? DailyTotals(), configuration: configuration,
            countdownLength: countdownLength)
    }

    @discardableResult
    public mutating func tick(now: TimeInterval, date: Date, context: ActivityContext) -> [BreakEvent] {
        let elapsed = previousTime.map { max(0, now - $0) } ?? 0
        let oldTime = previousTime ?? now
        let oldContext = previousContext
        previousTime = now
        previousContext = context
        currentDate = date
        var events: [BreakEvent] = []

        // Attribute elapsed time to the state before the boundary. Wall-clock jumps never
        // change elapsed duration; calendar dates only determine which daily bucket receives it.
        if oldContext.available {
            if case .resting = stage {
                if context.workingOutsideFar {
                    outsideWork += elapsed
                } else {
                    outsideWork = 0
                }
            } else {
                addScreenTime(elapsed, ending: date)
            }
        }

        if !context.available {
            if awayStarted == nil { awayStarted = now }
            if case .countdown = stage { events.append(.countdownCancelled) }
            if case .resting(let kind, _) = stage { events.append(.interrupted(kind)) }
            stage = .ambient
            countdownEnds = nil
            restEnds = nil
            completionEnds = nil
            outsideWork = 0
            eligibleDeferral = 0
            creditAway(now: now, date: date, events: &events)
            return events
        }
        if awayStarted != nil {
            creditAway(now: now, date: date, events: &events)
            awayStarted = nil
            awayShortCredited = false
            awayRecoveryCredited = false
        }

        if case .resting(let kind, _) = stage {
            if context.meeting || outsideWork >= configuration.interruptionDuration {
                // Sustained work was never a completed rest. Include the observed work burst.
                addScreenTime(outsideWork, ending: date)
                postpone(kind)
                events.append(.interrupted(kind))
                return events
            }
            let remaining = max(0, (restEnds ?? now) - now)
            if remaining == 0 {
                let end = restEnds ?? now
                recordRest(kind)
                mutateDay(date.addingTimeInterval(end - now)) { $0.guidedBreaks += 1 }
                // A delayed timer must not discard available screen time after the break ended.
                addScreenTime(max(0, now - max(end, oldTime)), ending: date)
                stage = .completion(kind)
                completionEnds = now + configuration.completionDuration
                restEnds = nil
                events.append(.breakCompleted(kind))
            } else {
                stage = .resting(kind: kind, remaining: remaining)
            }
            return events
        }

        if context.meeting || tracking.pausedUntil.map({ date < $0 }) == true {
            if case .countdown = stage { events.append(.countdownCancelled) }
            stage = .ambient
            countdownEnds = nil
            completionEnds = nil
            eligibleDeferral = 0
            return events
        }
        if let until = tracking.pausedUntil, date >= until { tracking.pausedUntil = nil }

        if case .completion = stage {
            if now < (completionEnds ?? now) { return events }
            stage = .ambient
            completionEnds = nil
        }
        if case .countdown(let kind, _) = stage {
            let remaining = max(0, (countdownEnds ?? now) - now)
            if remaining == 0 {
                startBreak(kind, now: now)
                events.append(.breakStarted(kind))
            } else {
                stage = .countdown(kind: kind, remaining: remaining)
            }
            return events
        }
        guard tracking.postponeRemaining <= 0, let kind = snapshot.dueKind else {
            stage = .ambient
            eligibleDeferral = 0
            return events
        }
        if case .waiting = stage, oldContext.available, !oldContext.meeting {
            eligibleDeferral += elapsed
        }
        stage = .waiting(kind)
        if !context.intenseTyping || eligibleDeferral >= configuration.maximumTypingDeferral {
            stage = .countdown(kind: kind, remaining: configuration.countdownDuration)
            countdownLength = configuration.countdownDuration
            countdownEnds = now + configuration.countdownDuration
            events.append(.countdownStarted(kind))
        }
        return events
    }

    public mutating func startBreak(_ kind: BreakKind, now: TimeInterval) {
        stage = .resting(kind: kind, remaining: configuration.duration(for: kind))
        restEnds = now + configuration.duration(for: kind)
        countdownEnds = nil
        completionEnds = nil
        outsideWork = 0
        eligibleDeferral = 0
    }
    @discardableResult public mutating func postponeCurrent() -> BreakEvent? {
        guard stage.offersActions, let kind = stage.kind else { return nil }
        postpone(kind)
        return .postponed(kind)
    }
    @discardableResult public mutating func skipCurrent() -> BreakEvent? {
        guard stage.offersActions, let kind = stage.kind else { return nil }
        if kind == .focusReset { tracking.focusWork = 0 } else { tracking.recoveryWork = 0 }
        clearPresentation()
        tracking.postponeRemaining = 0
        return .skipped(kind)
    }
    public mutating func pauseReminders(until: Date) {
        tracking.pausedUntil = until
        if stage.offersActions { clearPresentation() }
    }
    public mutating func resumeReminders() {
        tracking.pausedUntil = nil
    }
    public mutating func updateCalendar(_ calendar: Calendar) { self.calendar = calendar }

    private mutating func postpone(_ kind: BreakKind) {
        // Manual early breaks also retry after the requested delay.
        if kind == .focusReset {
            tracking.focusWork = max(tracking.focusWork, configuration.focusResetThreshold)
        } else {
            tracking.recoveryWork = max(tracking.recoveryWork, configuration.recoveryThreshold)
        }
        tracking.postponeRemaining = configuration.postponeDuration
        clearPresentation()
    }
    private mutating func clearPresentation() {
        stage = .ambient
        countdownEnds = nil
        restEnds = nil
        completionEnds = nil
        outsideWork = 0
        eligibleDeferral = 0
    }
    private mutating func recordRest(_ kind: BreakKind) {
        tracking.focusWork = 0
        if kind == .recovery { tracking.recoveryWork = 0 }
        tracking.screenSinceRest = 0
        tracking.hasKnownRest = true
        tracking.postponeRemaining = 0
        eligibleDeferral = 0
    }
    private mutating func creditAway(now: TimeInterval, date: Date, events: inout [BreakEvent]) {
        guard let start = awayStarted else { return }
        let duration = max(0, now - start)
        if duration >= BreakKind.focusReset.duration, !awayShortCredited {
            recordRest(.focusReset)
            awayShortCredited = true
            mutateDay(date.addingTimeInterval(start + BreakKind.focusReset.duration - now)) { $0.awayShortRests += 1 }
            events.append(.awayRestCredited(.focusReset))
        }
        if duration >= BreakKind.recovery.duration, !awayRecoveryCredited {
            recordRest(.recovery)
            awayRecoveryCredited = true
            mutateDay(date.addingTimeInterval(start + BreakKind.recovery.duration - now)) { $0.awayRecoveries += 1 }
            events.append(.awayRestCredited(.recovery))
        }
    }
    private mutating func addScreenTime(_ duration: TimeInterval, ending: Date) {
        guard duration > 0, duration.isFinite else { return }
        tracking.focusWork += duration
        tracking.recoveryWork += duration
        tracking.screenSinceRest += duration
        tracking.postponeRemaining = max(0, tracking.postponeRemaining - duration)
        var cursor = ending.addingTimeInterval(-duration)
        while cursor < ending {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor)) ?? ending
            let end = min(ending, tomorrow)
            guard end > cursor else { break }
            let part = end.timeIntervalSince(cursor)
            mutateDay(cursor) { $0.screenTime += part }
            cursor = end
        }
    }
    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    private mutating func mutateDay(_ date: Date, _ action: (inout DailyTotals) -> Void) {
        let key = dayKey(date)
        var day = tracking.days[key] ?? DailyTotals()
        action(&day)
        tracking.days[key] = day
    }
}
