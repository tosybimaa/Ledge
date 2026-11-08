import AppKit
import SwiftUI

/// The music apps Ledge can read and control.
enum MusicApp: String {
    case music = "Music", spotify = "Spotify"

    var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    /// Asking a closed app over AppleScript would launch it, so always check first.
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }

    /// state ␟ title ␟ artist ␟ position ␟ duration ␟ favourite ␟ artwork URL. Whole seconds, so the
    /// numbers never depend on the Mac's decimal separator.
    var statusScript: String {
        switch self {
        case .music:
            """
            tell application "Music"
                if player state is stopped then return "stopped"
                set t to current track
                set fav to false
                try
                    set fav to favorited of t
                end try
                set d to character id 31
                return (player state as text) & d & (name of t) & d & (artist of t) & d & (((player position) div 1) as text) & d & (((duration of t) div 1) as text) & d & (fav as text) & d & ""
            end tell
            """
        case .spotify:
            """
            tell application "Spotify"
                if player state is stopped then return "stopped"
                set t to current track
                set d to character id 31
                return (player state as text) & d & (name of t) & d & (artist of t) & d & (((player position) div 1) as text) & d & (((duration of t) div 1000) as text) & d & "false" & d & (artwork url of t)
            end tell
            """
        }
    }
}

/// Now playing from Music or Spotify (Settings › Media › Source), read and controlled with AppleScript.
/// shortcut: only Music and Spotify; browsers and other players need Apple's private MediaRemote framework.
@MainActor
final class PlayerModel: ObservableObject {
    @Published var title = "Nothing Playing"
    @Published var artist = ""
    @Published var isPlaying = false
    @Published var isLiked = false
    @Published var hasTrack = false
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var artwork: NSImage?
    @Published var output = ""
    @Published var outputs: [String] = []
    @Published var lyrics: [String] = []
    @Published var lyricIndex = 0

    private(set) var app: MusicApp?
    private var lyricTimes: [TimeInterval] = []
    private var trackKey = ""
    private var pausedAt: Date?
    private var timer: Timer?
    private var scripts: [String: NSAppleScript] = [:]

    /// `preview: true` shows a fixed sample song and talks to nothing (settings preview, Xcode previews).
    init(preview: Bool = false) {
        if preview {
            (title, artist, isPlaying, hasTrack, elapsed, duration) = ("Song Title", "Artist Name", true, true, 84, 251)
            lyrics = ["Earlier lyric line", "The line just before", "The current line is bright and large", "The next line waits here"]
            lyricIndex = 2
            return
        }
        refreshOutputs()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    var progress: Double { duration > 0 ? min(1, elapsed / duration) : 0 }
    var canLike: Bool { app == .music }

    /// Closed pill shows the song while playing, and for the Hide After time once paused.
    var showsInPill: Bool {
        guard hasTrack else { return false }
        guard !isPlaying, let pausedAt else { return true }
        let steps: [TimeInterval] = [0, 5, 15, 60, .infinity]
        let index = min(max(Int(UserDefaults.standard.double(forKey: K.hideAfter.rawValue)), 0), steps.count - 1)
        return Date().timeIntervalSince(pausedAt) < steps[index]
    }

    // MARK: - Controls

    func togglePlay() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }
    func seek(to seconds: TimeInterval) { command("set player position to \(Int(seconds))") }

    func seekToLyric(_ index: Int) {
        guard lyricTimes.indices.contains(index) else { return }
        seek(to: lyricTimes[index])
    }

    func toggleLike() {
        guard app == .music else { return }
        let value = isLiked ? "false" : "true"
        command("""
            try
                set favorited of current track to \(value)
            on error
                set loved of current track to \(value)
            end try
            """)
        isLiked.toggle()
    }

    func toggleShuffle() {
        command(app == .music ? "set shuffle enabled to not shuffle enabled" : "set shuffling to not shuffling")
    }

    func toggleRepeat() {
        command(app == .music ? "if song repeat is off then\nset song repeat to all\nelse\nset song repeat to off\nend if"
                              : "set repeating to not repeating")
    }

    func selectOutput(_ name: String) {
        guard let device = AudioDevices.outputs().first(where: { $0.name == name }) else { return }
        AudioDevices.setDefaultOutput(device.id)
        refreshOutputs()
    }

    func refreshOutputs() {
        outputs = AudioDevices.outputs().map(\.name)
        output = AudioDevices.name(of: AudioDevices.defaultOutput())
    }

    // MARK: - Reading

    private func command(_ body: String) {
        guard let app, app.isRunning else { return }
        run("tell application \"\(app.rawValue)\"\n\(body)\nend tell")
        poll()
    }

    private func poll() {
        let choice = MediaSource(rawValue: UserDefaults.standard.string(forKey: K.source.rawValue) ?? "") ?? .auto
        let candidates: [MusicApp] = switch choice {
        case .music: [.music]
        case .spotify: [.spotify]
        case .auto: [.music, .spotify]
        }
        var found: [(app: MusicApp, fields: [String])] = []
        for candidate in candidates where candidate.isRunning {
            guard let text = run(candidate.statusScript)?.stringValue, text != "stopped" else { continue }
            let fields = text.components(separatedBy: "\u{1F}")
            if fields.count >= 7 { found.append((candidate, fields)) }
        }
        // Auto: whichever app is playing; otherwise the paused one.
        guard let pick = found.first(where: { $0.fields[0] == "playing" }) ?? found.first else {
            clear()
            return
        }
        let f = pick.fields
        let playing = f[0] == "playing"
        if isPlaying, !playing { pausedAt = Date() }
        if playing { pausedAt = nil }
        app = pick.app
        isPlaying = playing
        title = f[1]
        artist = f[2]
        elapsed = TimeInterval(f[3]) ?? 0
        duration = TimeInterval(f[4]) ?? 0
        isLiked = f[5] == "true"
        hasTrack = true

        let key = pick.app.rawValue + f[1] + f[2]
        if key != trackKey {
            trackKey = key
            loadArtwork(from: pick.app, url: f[6])
            loadLyrics()
        }
        updateLyricIndex()
    }

    private func clear() {
        guard hasTrack else { return }
        (app, hasTrack, isPlaying, title, artist, artwork, trackKey) = (nil, false, false, "Nothing Playing", "", nil, "")
        (elapsed, duration, lyrics, lyricTimes) = (0, 0, [], [])
    }

    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        let script = scripts[source] ?? {
            let compiled = NSAppleScript(source: source)
            scripts[source] = compiled
            return compiled
        }()
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    private func loadArtwork(from app: MusicApp, url: String) {
        artwork = nil
        if app == .music {
            if let data = run("tell application \"Music\" to get raw data of artwork 1 of current track")?.data {
                artwork = NSImage(data: data)
            }
            return
        }
        guard let link = URL(string: url), link.scheme == "https" else { return }
        let key = trackKey
        Task {
            guard let result = try? await URLSession.shared.data(from: link), key == trackKey else { return }
            artwork = NSImage(data: result.0)
        }
    }

    /// Synced lyrics from lrclib.net (free, no account).
    private func loadLyrics() {
        lyrics = []
        lyricTimes = []
        lyricIndex = 0
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(Int(duration))),
        ]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url)
        request.setValue("Ledge (https://github.com/tosybimaa/Ledge)", forHTTPHeaderField: "User-Agent")
        let key = trackKey
        Task {
            guard let result = try? await URLSession.shared.data(for: request),
                  (result.1 as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any],
                  let synced = json["syncedLyrics"] as? String,
                  key == trackKey
            else { return }
            let lines = Self.parseLRC(synced)
            lyricTimes = lines.map(\.time)
            lyrics = lines.map(\.text)
            updateLyricIndex()
        }
    }

    private func updateLyricIndex() {
        // Settings › Lock Screen › Sync: positive shows lines earlier.
        let now = elapsed + UserDefaults.standard.double(forKey: K.lyricsSync.rawValue) / 1000
        lyricIndex = max(0, (lyricTimes.lastIndex { $0 <= now }) ?? 0)
    }

    /// "[01:02.50]Hello" lines into (62.5, "Hello"), sorted by time. Lines without words are skipped.
    nonisolated static func parseLRC(_ text: String) -> [(time: TimeInterval, text: String)] {
        var lines: [(time: TimeInterval, text: String)] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [TimeInterval] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let parts = rest[rest.index(after: rest.startIndex)..<close].split(separator: ":")
                if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
                    times.append(minutes * 60 + seconds)
                }
                rest = rest[rest.index(after: close)...]
            }
            let words = rest.trimmingCharacters(in: .whitespaces)
            guard !words.isEmpty else { continue }
            lines += times.map { (time: $0, text: words) }
        }
        return lines.sorted { $0.time < $1.time }
    }

    /// 84 -> "1:24". Negative values clamp to "0:00".
    nonisolated static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
