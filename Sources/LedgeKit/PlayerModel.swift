import SwiftUI

/// Now-playing state shared by the notch, lock screen and menus.
/// shortcut: mock track that ticks on a local timer; swap in MediaRemote / ScriptingBridge in the system step.
@MainActor
final class PlayerModel: ObservableObject {
    @Published var title = "Song Title"
    @Published var artist = "Artist Name"
    @Published var isPlaying = true
    @Published var isLiked = false
    @Published var elapsed: TimeInterval = 84
    @Published var duration: TimeInterval = 251
    @Published var output = "MacBook Speakers"
    @Published var lyricIndex = 2

    let outputs = ["MacBook Speakers", "AirPods Pro"]
    let lyrics = [
        "Earlier lyric line",
        "The line just before",
        "The current line is bright and large",
        "The next line waits here",
        "Lines move as the song plays",
    ]

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    var progress: Double { duration > 0 ? elapsed / duration : 0 }

    func togglePlay() { isPlaying.toggle() }
    func next() { elapsed = 0 }
    func previous() { elapsed = 0 }

    private func tick() {
        guard isPlaying else { return }
        elapsed = elapsed >= duration ? 0 : elapsed + 1
        if Int(elapsed) % 3 == 0 { lyricIndex = (lyricIndex + 1) % lyrics.count }
    }

    /// 84 -> "1:24". Negative values clamp to "0:00".
    nonisolated static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
