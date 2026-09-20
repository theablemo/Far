import AppKit
import CoreAudio
import CoreGraphics

#if canImport(FarCore)
    import FarCore
#endif

struct InputReading {
    var intenseTyping = false
    var workingOutsideFar = false
}
@MainActor protocol ActivityReading { func sample(now: TimeInterval) -> InputReading }
final class SystemActivityReader: ActivityReading {
    private var classifier = InputClassifier()
    private var lastCounters: [CGEventType: UInt32] = [:]
    private var lastSample: TimeInterval?
    private var lastOutsideInput: TimeInterval?
    func sample(now: TimeInterval) -> InputReading {
        let keyCount = CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
        let intense = classifier.sample(now: now, keyCount: keyCount)
        let types: [CGEventType] = [
            .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        ]
        let pointerInFar = Self.containsInteractiveWindow(NSApp.windows, at: NSEvent.mouseLocation)
        let farHasFocus =
            NSApp.keyWindow != nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid()
        var changedOutside = false
        for type in types {
            let count = CGEventSource.counterForEventType(.combinedSessionState, eventType: type)
            let ownInput = type == .keyDown ? farHasFocus : pointerInFar
            if let previous = lastCounters[type], count != previous, !ownInput { changedOutside = true }
            lastCounters[type] = count
        }
        let gap = lastSample.map { now - $0 } ?? 0
        lastSample = now
        // A delayed sample cannot prove sustained activity throughout the missed interval.
        if gap > 2 {
            lastOutsideInput = nil
            changedOutside = false
        }
        if changedOutside { lastOutsideInput = now }
        return InputReading(
            intenseTyping: intense,
            workingOutsideFar: lastOutsideInput.map { now - $0 < 1 } ?? false)

    }
    static func containsInteractiveWindow(_ windows: [NSWindow], at point: CGPoint) -> Bool {
        windows.contains { $0.isVisible && !$0.ignoresMouseEvents && $0.frame.contains(point) }
    }
}

@MainActor protocol MeetingReading {
    var statusDetail: String { get }
    func sample(now: TimeInterval) -> Bool
}
final class SystemMeetingReader: MeetingReading {
    private var debounce = MeetingDebouncer()
    private var lastRead: TimeInterval?
    private var cachedActive: Bool?
    private(set) var statusDetail = "Uses audio-input activity as a likely-call signal."
    func sample(now: TimeInterval) -> Bool {
        if lastRead.map({ now - $0 >= 1 }) ?? true {
            cachedActive = inputActive()
            lastRead = now
        }
        let active = cachedActive
        statusDetail =
            active == nil
            ? "Automatic detection unavailable. Use Meeting mode for calls."
            : "Audio-input detection is best effort; muted calls may need Meeting mode."
        return debounce.sample(now: now, active: active)
    }
    private func inputActive() -> Bool? {
        if #available(macOS 14.2, *) {
            if let processes = objectList(
                object: AudioObjectID(kAudioObjectSystemObject),
                selector: kAudioHardwarePropertyProcessObjectList)
            {
                var unknown = false
                for process in processes {
                    let active = uintProperty(object: process, selector: kAudioProcessPropertyIsRunningInput)
                    if active == 1 { return true }
                    if active == nil { unknown = true }
                }
                return unknown ? nil : false
            }
        }
        guard
            let devices = objectList(
                object: AudioObjectID(kAudioObjectSystemObject),
                selector: kAudioHardwarePropertyDevices)
        else { return nil }
        var unknown = false
        for device in devices {
            var input = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var size: UInt32 = 0
            let status = AudioObjectGetPropertyDataSize(device, &input, 0, nil, &size)
            guard status == noErr else {
                unknown = true
                continue
            }
            guard size > 0 else { continue }
            let running = uintProperty(object: device, selector: kAudioDevicePropertyDeviceIsRunningSomewhere)
            if running == 1 { return true }
            if running == nil { unknown = true }
        }
        return unknown ? nil : false
    }
    private func objectList(object: AudioObjectID, selector: AudioObjectPropertySelector) -> [AudioObjectID]? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        if size == 0 { return [] }
        var result = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = result.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0.baseAddress!)
        }
        guard status == noErr else { return nil }
        return Array(result.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }
    private func uintProperty(object: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var result: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result) == noErr ? result : nil
    }
}

@MainActor protocol AvailabilityReading: AnyObject {
    var state: SessionAvailability { get }
    var onChange: (@MainActor () -> Void)? { get set }
    func reconcile()
    func stop()
}

final class SystemAvailabilityMonitor: AvailabilityReading {
    private(set) var state = SessionAvailability()
    var onChange: (@MainActor () -> Void)?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    init(
        workspace: NotificationCenter = NSWorkspace.shared.notificationCenter,
        distributed: NotificationCenter = DistributedNotificationCenter.default(),
        application: NotificationCenter = .default,
        systemReconciliation: (@MainActor (inout SessionAvailability) -> Void)? = nil
    ) {
        self.systemReconciliation = systemReconciliation
        state.screensOff = true
        reconcile()
        observe(workspace, NSWorkspace.willSleepNotification) { $0.sleeping = true }
        observe(workspace, NSWorkspace.didWakeNotification, reconcileAfter: true) { $0.sleeping = false }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensOff = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification, reconcileAfter: true) { $0.screensOff = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.inactiveSession = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, reconcileAfter: true) {
            $0.inactiveSession = false
        }
        observe(distributed, .init("com.apple.screenIsLocked")) { $0.locked = true }
        observe(distributed, .init("com.apple.screenIsUnlocked"), reconcileAfter: true) { $0.locked = false }
        observe(distributed, .init("com.apple.screensaver.didstart")) { $0.screenSaver = true }
        observe(distributed, .init("com.apple.screensaver.didstop")) { $0.screenSaver = false }
        // Some saver transitions emit willstop without a matching didstop. End away time
        // at that boundary; independent lock/sleep flags still hold availability closed.
        observe(distributed, .init("com.apple.screensaver.willstop")) { $0.screenSaver = false }
        observe(
            application, NSApplication.didChangeScreenParametersNotification,
            reconcileAfter: true
        ) { _ in }
    }
    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name,
        reconcileAfter: Bool = false,
        change: @escaping @MainActor (inout SessionAvailability) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                change(&self.state)
                if reconcileAfter { self.reconcile() }
                self.onChange?()
            }
        }
        observers.append((center, token))
    }
    func reconcile() {
        let previous = state
        if let systemReconciliation {
            systemReconciliation(&state)
            if state != previous { onChange?() }
            return
        }
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any] {
            // The lock-state dictionary field and distributed notifications are OS conventions,
            // not a promised lock API. Keep them here and cover with real-device validation.
            if let locked = session["CGSSessionScreenIsLocked"] as? Bool { state.locked = locked }
            if let console = session[kCGSessionOnConsoleKey as String] as? Bool { state.inactiveSession = !console }
        }
        var count: UInt32 = 0
        if CGGetOnlineDisplayList(0, nil, &count) == .success {
            state.screensOff = count == 0
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
            if CGGetOnlineDisplayList(count, &displays, &count) == .success {
                state.screensOff = displays.prefix(Int(count)).allSatisfy { CGDisplayIsAsleep($0) != 0 }
            }
        }
        // Establish startup state; subsequent notifications own stop/start transitions.
        if needsStartupReconciliation {
            state.screenSaver = NSWorkspace.shared.runningApplications.contains {
                ["com.apple.ScreenSaver.Engine", "com.apple.ScreenSaver.Engine.legacyScreenSaver"].contains(
                    $0.bundleIdentifier ?? "")
            }
            needsStartupReconciliation = false
        }
        if state != previous { onChange?() }
    }
    private var needsStartupReconciliation = true
    private let systemReconciliation: (@MainActor (inout SessionAvailability) -> Void)?
    func stop() {
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        onChange = nil
    }
}
