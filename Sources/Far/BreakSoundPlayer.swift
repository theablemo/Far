import AppKit

enum BreakEndSound: String, CaseIterable, Identifiable {
    case glass = "Glass"
    case tink = "Tink"
    case pop = "Pop"
    case purr = "Purr"
    case ping = "Ping"
    case submarine = "Submarine"
    var id: String { rawValue }
}

@MainActor protocol BreakSoundPlaying {
    @discardableResult func play(_ sound: BreakEndSound) -> Bool
}

@MainActor final class SystemBreakSoundPlayer: BreakSoundPlaying {
    private var current: NSSound?
    func play(_ sound: BreakEndSound) -> Bool {
        current?.stop()
        current = NSSound(named: NSSound.Name(sound.rawValue))
        return current?.play() ?? false
    }
}
