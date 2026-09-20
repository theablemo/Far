import AppKit
import Combine
import ServiceManagement

#if canImport(FarCore)
    import FarCore
#endif

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: BreakSnapshot
    @Published private(set) var suppressionReason: String?
    @Published private(set) var meetingDetectionDetail = ""
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginMessage: String?
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var onboardingRequestID = 0
    @Published var endSoundEnabled: Bool { didSet { defaults.set(endSoundEnabled, forKey: "endSoundEnabled") } }
    @Published var endSound: BreakEndSound {
        didSet {
            defaults.set(endSound.rawValue, forKey: "endSound")
            soundMessage = nil
        }
    }
    @Published private(set) var soundMessage: String?
    var postponeMinutes: Int {
        get { timingValue(.postponeMinutes) }
        set { setTiming(.postponeMinutes, to: newValue) }
    }
    @Published var automaticMeetingDetection: Bool {
        didSet {
            defaults.set(automaticMeetingDetection, forKey: "automaticMeetingDetection")
            tick()
        }
    }
    @Published var manualMeetingMode = false { didSet { tick() } }

    private let defaults: UserDefaults
    private let clock: any FarClock
    private let activity: any ActivityReading
    private let availability: any AvailabilityReading
    private let meeting: any MeetingReading
    private let store: any TrackingStore
    private let soundPlayer: any BreakSoundPlaying
    private var engine: BreakEngine
    private var timer: AnyCancellable?
    private var lastSave: TimeInterval = 0
    private var lastReconcile: TimeInterval = 0
    private var ticking = false

    init(
        defaults: UserDefaults = .standard, clock: (any FarClock)? = nil,
        activity: (any ActivityReading)? = nil, availability: (any AvailabilityReading)? = nil,
        meeting: (any MeetingReading)? = nil, store: (any TrackingStore)? = nil,
        configuration: BreakConfiguration = .balanced, startTimer: Bool = true,
        soundPlayer: (any BreakSoundPlaying)? = nil
    ) {
        self.defaults = defaults
        self.clock = clock ?? SystemClock()
        self.activity = activity ?? SystemActivityReader()
        self.availability = availability ?? SystemAvailabilityMonitor()
        self.meeting = meeting ?? SystemMeetingReader()
        let store = store ?? LocalTrackingStore(defaults: defaults)
        self.store = store
        self.soundPlayer = soundPlayer ?? SystemBreakSoundPlayer()
        endSoundEnabled = defaults.object(forKey: "endSoundEnabled") as? Bool ?? true
        endSound = defaults.string(forKey: "endSound").flatMap(BreakEndSound.init(rawValue:)) ?? .glass
        automaticMeetingDetection = defaults.object(forKey: "automaticMeetingDetection") as? Bool ?? true
        let savedPostponeMinutes = min(60, max(1, defaults.object(forKey: "postponeMinutes") as? Int ?? 5))
        hasCompletedOnboarding = defaults.integer(forKey: "onboardingVersion") >= 2
        var config = configuration
        // Upgrade the old three-second default once; preserve other saved choices.
        if !defaults.bool(forKey: "countdownNotice.v2") {
            if defaults.object(forKey: TimingSetting.countdown.storageKey) as? Int == 3 {
                defaults.set(15, forKey: TimingSetting.countdown.storageKey)
            }
            defaults.set(true, forKey: "countdownNotice.v2")
        }
        config.postponeDuration = Double(savedPostponeMinutes * 60)
        for setting in TimingSetting.allCases {
            if let path = setting.keyPath, let value = defaults.object(forKey: setting.storageKey) as? Int {
                config[keyPath: path] = Double(setting.clamp(value)) * setting.scale
            }
        }
        let engine = BreakEngine(configuration: config, tracking: store.load())
        self.engine = engine
        snapshot = engine.snapshot
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.availability.onChange = { [weak self] in self?.tick(forceSave: true) }
        tick()
        if startTimer {
            timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
                .sink { [weak self] _ in self?.tick() }
        }
    }

    func timingValue(_ setting: TimingSetting) -> Int {
        if let path = setting.keyPath { return Int(snapshot.configuration[keyPath: path] / setting.scale) }
        return setting.clamp(defaults.object(forKey: setting.storageKey) as? Int ?? setting.defaultValue)
    }
    func setTiming(_ setting: TimingSetting, to value: Int) {
        let value = setting.clamp(value)
        defaults.set(value, forKey: setting.storageKey)
        if let path = setting.keyPath {
            // Current rest/countdown deadlines stay fixed; future attempts use the new duration.
            engine.configuration[keyPath: path] = Double(value) * setting.scale
        }
        publish()
    }
    func resetTimings() {
        for setting in TimingSetting.allCases { setTiming(setting, to: setting.defaultValue) }
    }
    var menuStatus: String {
        if let suppressionReason { return suppressionReason }
        if reminderPaused { return "Reminders paused" }
        switch snapshot.stage {
        case .countdown: return "Your break is about to begin"
        case .resting: return "A break is in progress"
        default: return statusTitle
        }
    }
    var pauseLabel: String { "Pause for \(timingValue(.pauseMinutes)) min" }

    var statusTitle: String {
        if let suppressionReason { return suppressionReason }
        if snapshot.tracking.pausedUntil.map({ $0 > clock.date }) == true { return "Reminders paused" }
        switch snapshot.stage {
        case .ambient: return "Next break in \(minutes(snapshot.secondsUntilNextBreak)) min"
        case .waiting: return "Finishing your typing session"
        case .countdown(_, let remaining): return "Break begins in \(Int(ceil(remaining)))"
        case .resting(let kind, _): return kind == .focusReset ? "Rest your focus" : "Step away for a while"
        case .completion: return "Break complete"
        }
    }
    var sinceRestLabel: String {
        snapshot.tracking.hasKnownRest ? "Screen time since your last break" : "Screen time since tracking began"
    }
    var sinceRestTime: String { Self.formatDuration(snapshot.tracking.screenSinceRest) }
    var postponeLabel: String { "Postpone · \(postponeMinutes) min" }
    var reminderPaused: Bool { snapshot.tracking.pausedUntil.map { $0 > clock.date } ?? false }
    var canStartBreak: Bool { suppressionReason == nil && !snapshot.stage.offersActions }
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 1 { return "Less than 1 min" }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) hr \(minutes % 60) min"
    }
    private func minutes(_ seconds: TimeInterval) -> Int { max(1, Int(ceil(seconds / 60))) }

    func tick(forceSave: Bool = false) {
        guard !ticking else { return }
        ticking = true
        defer { ticking = false }
        let now = clock.now
        if now - lastReconcile >= 5 {
            availability.reconcile()
            engine.updateCalendar(.current)
            lastReconcile = now
        }
        let input = activity.sample(now: now)
        let detected = automaticMeetingDetection ? meeting.sample(now: now) : false
        let inMeeting = detected || manualMeetingMode
        meetingDetectionDetail = meeting.statusDetail
        suppressionReason =
            availability.state.reason
            ?? (manualMeetingMode ? "Meeting mode is on" : (detected ? "Likely call — reminders held" : nil))
        let events = engine.tick(
            now: now, date: clock.date,
            context: ActivityContext(
                available: availability.state.available,
                meeting: inMeeting, intenseTyping: input.intenseTyping,
                workingOutsideFar: input.workingOutsideFar))
        if events.contains(where: {
            if case .breakCompleted = $0 { return true }
            return false
        }), endSoundEnabled {
            playEndSound()
        }
        publish()
        if forceSave || !events.isEmpty || now - lastSave >= 5 { save() }
    }
    func startSuggestedBreak() {
        tick()
        guard canStartBreak else { return }
        engine.startBreak(snapshot.dueKind ?? .focusReset, now: clock.now)
        publish()
        save()
    }
    func postponeBreak() {
        // Apply an explicit command before advancing the deadline; clicking at zero still wins.
        guard engine.postponeCurrent() != nil else { return }
        publish()
        save()
    }
    func skipBreak() {
        guard engine.skipCurrent() != nil else { return }
        publish()
        save()
    }
    func pauseReminders() {
        tick()
        engine.pauseReminders(until: clock.date.addingTimeInterval(Double(timingValue(.pauseMinutes) * 60)))
        publish()
        save()
    }
    func resumeReminders() {
        engine.resumeReminders()
        tick(forceSave: true)
    }
    func shutdown() {
        tick(forceSave: true)
        timer?.cancel()
        availability.stop()
    }
    private func publish() { snapshot = engine.snapshot }
    private func save() {
        store.save(engine.tracking)
        lastSave = clock.now
    }

    func previewEndSound() { playEndSound() }
    private func playEndSound() {
        soundMessage = soundPlayer.play(endSound) ? nil : "This sound could not play. Try another sound."
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginMessage = nil
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            launchAtLoginMessage = "Build and launch Far.app before enabling this setting."
            return
        }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { launchAtLoginMessage = error.localizedDescription }
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(2, forKey: "onboardingVersion")
    }
    func requestOnboarding() { onboardingRequestID += 1 }
}
