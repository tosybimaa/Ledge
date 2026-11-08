import Foundation

/// Every stored preference key. Reset All Settings walks this list.
enum K: String, CaseIterable {
    // General
    case display, hideInFullscreen, hideFromCapture, menuBarIcon, liquidGlass, glassTint
    case hapticTouch, expandOnHover, hoverDelay, backgroundBlur, liveWaveform
    case lockSound, unlockSound, soundVolume, notchWidth, notchHeight
    // Media
    case mediaPlayer, source, eq, eqSub, eqLow, eqMid, eqPres, eqAir, leftButton
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
    case lockGlass, lockFullArt, lockLyrics, lyricsSync, lockGlassArt, lockGlassCard, keepAwake
    // Accessories
    case accessoryConnect, outputChange, listeningMode, accessoryStyle, glyph3D, accessoryDuration
    // Appearance
    case uiScale, textScale, fontDesign, borderWidth, cornerRadius, accentColor
    // Updates
    case autoUpdate, crashReports, lastUpdateCheck
}

enum Preferences {
    static let appearance: [K] = [.uiScale, .textScale, .fontDesign, .borderWidth, .cornerRadius, .glassTint, .accentColor]

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
    case auto = "Auto", spotify = "Spotify", music = "Music"
    var symbol: String {
        switch self {
        case .auto: "sparkles"
        case .spotify: "music.note"
        case .music: "music.note.list"
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
