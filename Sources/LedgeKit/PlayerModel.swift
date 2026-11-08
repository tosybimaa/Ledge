import AppKit
import SwiftUI

/// The music apps Ledge can read and control. Browsers play through web pages (YouTube, Spotify web, …).
enum MusicApp: String {
    case music = "Music", spotify = "Spotify", chrome = "Google Chrome", safari = "Safari"

    var isBrowser: Bool { self == .chrome || self == .safari }

    var bundleID: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        case .chrome: "com.google.Chrome"
        case .safari: "com.apple.Safari"
        }
    }
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
        case .chrome, .safari:
            // Only tabs on music sites run the page script; a playing tab wins over a paused one.
            // The tab's URL goes last so controls can find the same tab again.
            """
            tell application "\(rawValue)"
                set d to character id 31
                set found to "stopped"
                repeat with w in windows
                    try
                        set links to URL of tabs of w
                    on error
                        set links to {}
                    end try
                    repeat with i from 1 to count of links
                        set u to item i of links
                        if \(Self.musicSites) then
                            try
                                set r to \(runJS(Self.statusJS, in: "(tab i of w)"))
                            on error
                                set r to ""
                            end try
                            if r starts with "playing" then return r & d & u
                            if r starts with "paused" and found is "stopped" then set found to r & d & u
                        end if
                    end repeat
                end repeat
                return found
            end tell
            """
        }
    }

    /// AppleScript that runs `javascript` in a browser tab and returns its result.
    func runJS(_ javascript: String, in tab: String) -> String {
        self == .chrome ? "execute \(tab) javascript \"\(javascript)\"" : "do JavaScript \"\(javascript)\" in \(tab)"
    }

    private static let musicSites = ["youtube.com", "spotify.com", "soundcloud.com", "music.apple.com", "deezer.com",
                                     "tidal.com", "bandcamp.com", "music.amazon", "pandora.com"]
        .map { "u contains \"\($0)\"" }.joined(separator: " or ")

    /// Page script (no double quotes or backslashes, so it fits inside an AppleScript string).
    /// Picks the playing <video>/<audio>, else the first one with a length; `m` is that element.
    static func pageJS(_ body: String) -> String {
        "(function(){var els=[].slice.call(document.querySelectorAll('video,audio')).filter(function(e){return e.duration>0;});"
            + "var m=els.filter(function(e){return !e.paused;})[0]||els[0];" + body + "})()"
    }

    /// Same fields as the apps, from the page's media element and Media Session info.
    /// Spotify's web player keeps its audio element out of the page, so without one the state comes from
    /// Media Session and the times from Spotify's own position/duration labels.
    static let statusJS = pageJS("var ms=navigator.mediaSession;var md=ms&&ms.metadata;var st=ms?ms.playbackState:'none';"
        + "if(!m&&!md)return '';"
        + "var label=function(id){var e=document.querySelector('[data-testid='+id+']');if(!e)return 0;"
        + "return e.textContent.split(':').map(Number).reduce(function(a,b){return a*60+b;},0)||0;};"
        + "var a=md&&md.artwork&&md.artwork.length?md.artwork[md.artwork.length-1].src:'';"
        + "var pos=m?Math.floor(m.currentTime):label('playback-position');"
        // Spotify often leaves playbackState at 'none'; then "playing" means the time label moved in the last 2.5 s.
        + "if(pos!==window.__ledgePos){window.__ledgePos=pos;window.__ledgeMoved=Date.now();}"
        + "var playing=m?!m.paused:(st==='playing'||(st==='none'&&Date.now()-(window.__ledgeMoved||0)<2500));"
        + "var dur=m?(isFinite(m.duration)?Math.floor(m.duration):0):label('playback-duration');"
        + "return [playing?'playing':'paused',(md&&md.title)||document.title,(md&&md.artist)||'',pos,dur,'false',a]"
        + ".join(String.fromCharCode(31));")
}

/// Now playing from Music, Spotify, Chrome or Safari (Settings › Media › Source), read and controlled with AppleScript.
/// Browsers need "Allow JavaScript from Apple Events" turned on once.
/// shortcut: other apps (Podcasts, VLC, …) need Apple's private MediaRemote framework.
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
    private var tabURL = ""
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

    func togglePlay() {
        if app?.isBrowser == true {
            pageCommand("if(m){m.paused?m.play():m.pause();}else{var b=document.querySelector('[data-testid=control-button-playpause]');if(b)b.click();}return '';")
        } else {
            command("playpause")
        }
    }

    func next() {
        if app?.isBrowser == true {
            // The site's own Next button (YouTube, YouTube Music, Spotify web, SoundCloud); nothing if the site has none.
            pageCommand("var b=document.querySelector('.ytp-next-button,.next-button,[data-testid=control-button-skip-forward],.skipControl__next');if(b)b.click();return '';")
        } else {
            command("next track")
        }
    }

    func previous() {
        if app?.isBrowser == true {
            pageCommand("var b=document.querySelector('.previous-button,[data-testid=control-button-skip-back],.skipControl__previous');if(b){b.click();}else if(m){m.currentTime=0;}return '';")
        } else {
            command("previous track")
        }
    }

    func seek(to seconds: TimeInterval) {
        if app?.isBrowser == true { pageCommand("if(m)m.currentTime=\(Int(seconds));return '';") } else { command("set player position to \(Int(seconds))") }
    }

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

    /// Runs a page script in the browser tab that is playing (found again by its URL).
    private func pageCommand(_ body: String) {
        guard let app, app.isBrowser, app.isRunning, !tabURL.isEmpty else { return }
        let url = tabURL.replacingOccurrences(of: "\"", with: "%22").replacingOccurrences(of: "\\", with: "%5C")
        run("""
            tell application "\(app.rawValue)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t is "\(url)" then
                            \(app.runJS(MusicApp.pageJS(body), in: "t"))
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """)
        poll()
    }

    private func poll() {
        let choice = MediaSource(rawValue: UserDefaults.standard.string(forKey: K.source.rawValue) ?? "") ?? .auto
        let candidates: [MusicApp] = switch choice {
        case .music: [.music]
        case .spotify: [.spotify]
        case .browser: [.chrome, .safari]
        case .auto: [.music, .spotify, .chrome, .safari]
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
        tabURL = f.count > 7 ? f[7] : ""
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
