import Foundation

#if canImport(FarCore)
    import FarCore
#endif

/// User-facing units and bounds live in one place for storage, controls, and tests.
enum TimingSetting: String, CaseIterable, Identifiable {
    case focusInterval, focusDuration, recoveryInterval, recoveryDuration
    case postponeMinutes, countdown, typingDeferral, interruption, pauseMinutes
    var id: String { rawValue }
    var storageKey: String { self == .postponeMinutes ? rawValue : "timing." + rawValue }
    var unit: String {
        switch self {
        case .focusDuration, .countdown, .typingDeferral, .interruption: "sec"
        default: "min"
        }
    }
    var scale: Double { unit == "min" ? 60 : 1 }
    var bounds: ClosedRange<Int> {
        switch self {
        case .focusInterval: 1...180
        case .recoveryInterval: 1...480
        case .focusDuration: 5...600
        case .recoveryDuration: 1...60
        case .postponeMinutes: 1...60
        case .countdown: 5...60
        case .typingDeferral: 0...120
        case .interruption: 1...15
        case .pauseMinutes: 1...240
        }
    }
    var defaultValue: Int {
        switch self {
        case .focusInterval: 20
        case .focusDuration: 30
        case .recoveryInterval: 60
        case .recoveryDuration, .postponeMinutes: 5
        case .countdown: 15
        case .interruption: 3
        case .typingDeferral: 120
        case .pauseMinutes: 60
        }
    }
    var keyPath: WritableKeyPath<BreakConfiguration, TimeInterval>? {
        switch self {
        case .focusInterval: \.focusResetThreshold
        case .focusDuration: \.focusResetDuration
        case .recoveryInterval: \.recoveryThreshold
        case .recoveryDuration: \.recoveryDuration
        case .postponeMinutes: \.postponeDuration
        case .countdown: \.countdownDuration
        case .typingDeferral: \.maximumTypingDeferral
        case .interruption: \.interruptionDuration
        case .pauseMinutes: nil
        }
    }
    func clamp(_ value: Int) -> Int { min(bounds.upperBound, max(bounds.lowerBound, value)) }
}
