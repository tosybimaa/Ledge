import Foundation

/// Every stored preference key. Reset All Settings walks this list.
enum K: String, CaseIterable {
    // General
    case display, hideInFullscreen, hideFromCapture, menuBarIcon, liquidGlass, glassTint
    case hapticTouch, expandOnHover, hoverDelay, backgroundBlur, liveWaveform
    case lockSound, unlockSound, soundVolume, notchWidth, notchHeight
    // Media
    case mediaPlayer, source, eq, eqSub, eqLow, eqMid, eqPres, eqAir, leftButton
    case pageLyrics, pagePrayer, pageCalendar
    case explicitTag, explicitColor, animatedArtwork, heartMatchColor, collapseOnPause, hideAfter
    // Sensory
    case sensoryStyle, edgeSide, edgeHeight, brightnessOverlay, volumeOverlay, sensoryMatchColor, overlayLabel, sensoryDuration
    // Battery
    case chargerConnect, batteryStyle, batteryDuration
    // Focus
    case focusOverlay, focusShowBattery, focusShowAirPods, focusShowSensory, focusWidget
    // Weather
    case weather, weatherDetailed, preciseLocation
    // Lock Screen
    case lockScreenPlayer, lockGlass, lockFullArt, lockLyrics, lyricsSync, lockGlassArt, lockGlassCard, keepAwake
    // Accessories
    case accessoryConnect, outputChange, listeningMode, accessoryStyle, glyph3D, accessoryDuration
    // Appearance
    case uiScale, pillScale, textScale, fontDesign, borderWidth, cornerRadius, accentColor
    // Updates
    case autoUpdate, crashReports, lastUpdateCheck
}

enum Preferences {
    /// The one place default values live. Registered at launch, so every reader (Settings, pill, monitors)
    /// gets the same value; the literals next to each @AppStorage are only a compile-time fallback.
    static let defaults: [K: Any] = [
        .display: DisplayChoice.all.rawValue, .hideInFullscreen: true, .hideFromCapture: false, .menuBarIcon: true,
        .liquidGlass: true, .glassTint: 0.1, .hapticTouch: true, .expandOnHover: true, .hoverDelay: 0.0,
        .backgroundBlur: true, .liveWaveform: false, .lockSound: true, .unlockSound: true, .soundVolume: 1.0,
        .notchWidth: 0.0, .notchHeight: 0.0,
        .mediaPlayer: true, .source: MediaSource.auto.rawValue, .eq: false,
        .eqSub: 0.0, .eqLow: 0.0, .eqMid: 0.0, .eqPres: 0.0, .eqAir: 0.0, .leftButton: LeftButton.like.rawValue,
        .pageLyrics: true, .pagePrayer: true, .pageCalendar: true,
        .explicitTag: true, .explicitColor: true, .animatedArtwork: true, .heartMatchColor: false,
        .collapseOnPause: true, .hideAfter: 0.0,
        .sensoryStyle: SensoryStyle.notch.rawValue, .edgeSide: ScreenEdge.left.rawValue, .edgeHeight: 0.5,
        .brightnessOverlay: true, .volumeOverlay: true, .sensoryMatchColor: false, .overlayLabel: OverlayLabel.icon.rawValue,
        .sensoryDuration: 3.0,
        .chargerConnect: true, .batteryStyle: BatteryStyle.classic.rawValue, .batteryDuration: 5.0,
        .focusOverlay: true, .focusShowBattery: true, .focusShowAirPods: true, .focusShowSensory: true, .focusWidget: true,
        .weather: true, .weatherDetailed: false, .preciseLocation: true,
        .lockScreenPlayer: true, .lockGlass: GlassStyle.frosted.rawValue, .lockFullArt: true, .lockLyrics: true, .lyricsSync: 0.0,
        .lockGlassArt: false, .lockGlassCard: true, .keepAwake: false,
        .accessoryConnect: true, .outputChange: true, .listeningMode: true, .accessoryStyle: AccessoryStyle.single.rawValue,
        .glyph3D: true, .accessoryDuration: 4.0,
        .uiScale: 1.0, .pillScale: 1.0, .textScale: 1.0, .fontDesign: FontChoice.system.rawValue, .borderWidth: 1.0,
        .cornerRadius: 1.0, .accentColor: AccentChoice.system.rawValue,
        .autoUpdate: true, .crashReports: true,
    ]

    static func registerDefaults(_ store: UserDefaults = .standard) {
        store.register(defaults: Dictionary(uniqueKeysWithValues: defaults.map { ($0.key.rawValue, $0.value) }))
    }

    static let appearance: [K] = [.uiScale, .pillScale, .textScale, .fontDesign, .borderWidth, .cornerRadius, .glassTint, .accentColor]

    /// Launch at Login lives in SMAppService, not here, so it survives a reset.
    static func resetAll(_ defaults: UserDefaults = .standard) { reset(K.allCases, defaults) }

    static func reset(_ keys: [K], _ defaults: UserDefaults = .standard) {
        keys.forEach { defaults.removeObject(forKey: $0.rawValue) }
    }
}

/// A settings option stored by its name, shown in pickers and segmented controls.
protocol Choice: CaseIterable, Hashable, Identifiable, RawRepresentable
where RawValue == String, AllCases: RandomAccessCollection {}

extension Choice {
    var id: String { rawValue }
}

enum DisplayChoice: String, Choice { case all = "All Displays", builtIn = "Built-in", main = "Main Display" }
enum ScreenEdge: String, Choice { case left = "Left", right = "Right" }
enum SensoryStyle: String, Choice { case notch = "Notch", apple = "Apple Style" }
enum OverlayLabel: String, Choice { case icon = "Icon", name = "Name" }
enum GlassStyle: String, Choice { case clear = "Clear", frosted = "Frosted" }

enum MediaSource: String, Choice {
    case auto = "Auto", spotify = "Spotify", music = "Music", browser = "Browser"
    var symbol: String {
        switch self {
        case .auto: "sparkles"
        case .spotify: "music.note"
        case .music: "music.note.list"
        case .browser: "globe"
        }
    }
}

enum LeftButton: String, Choice {
    case like = "Like", shuffle = "Shuffle", repeatMode = "Repeat", none = "None"
    var symbol: String {
        switch self {
        case .like: "heart.fill"
        case .shuffle: "shuffle"
        case .repeatMode: "repeat"
        case .none: "nosign"
        }
    }
}

enum BatteryStyle: String, Choice {
    case classic = "Classic", bold = "Bold"
    var symbol: String { self == .classic ? "battery.100" : "battery.100.bolt" }
}

enum AccessoryStyle: String, Choice {
    case single = "Single", pair = "Pair"
    var symbol: String { self == .single ? "airpod.right" : "airpodspro" }
}
