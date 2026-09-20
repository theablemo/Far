import Darwin
import Foundation

#if canImport(FarCore)
    import FarCore
#endif

@MainActor protocol FarClock {
    var now: TimeInterval { get }
    var date: Date { get }
}
struct SystemClock: FarClock {
    var now: TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }
    var date: Date { Date() }
}

@MainActor protocol TrackingStore {
    func load() -> TrackingState
    func save(_ state: TrackingState)
}
final class LocalTrackingStore: TrackingStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    func load() -> TrackingState {
        guard let data = defaults.data(forKey: "trackingState.v1"),
            let state = try? JSONDecoder().decode(TrackingState.self, from: data),
            state.version == 1
        else { return TrackingState() }
        return state
    }
    func save(_ state: TrackingState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: "trackingState.v1")
    }
}
