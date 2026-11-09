import AppKit
import SwiftUI

// shortcut: pages store every preference, but most are not acted on yet; the system step reads them.

struct GeneralPage: View {
    @AppStorage(K.display.rawValue) private var display = DisplayChoice.all
    @AppStorage(K.hideInFullscreen.rawValue) private var hideInFullscreen = true
    @AppStorage(K.hideFromCapture.rawValue) private var hideFromCapture = false
    @AppStorage(K.menuBarIcon.rawValue) private var menuBarIcon = true
    @AppStorage(K.liquidGlass.rawValue) private var liquidGlass = true
    @AppStorage(K.hapticTouch.rawValue) private var hapticTouch = true
    @AppStorage(K.expandOnHover.rawValue) private var expandOnHover = true
    @AppStorage(K.hoverDelay.rawValue) private var hoverDelay = 0.0
    @AppStorage(K.backgroundBlur.rawValue) private var backgroundBlur = true
    @AppStorage(K.liveWaveform.rawValue) private var liveWaveform = false
    @AppStorage(K.lockSound.rawValue) private var lockSound = true
    @AppStorage(K.unlockSound.rawValue) private var unlockSound = true
    @AppStorage(K.soundVolume.rawValue) private var soundVolume = 1.0
    @AppStorage(K.notchWidth.rawValue) private var notchWidth = 0.0
    @AppStorage(K.notchHeight.rawValue) private var notchHeight = 0.0
    @State private var confirmReset = false

    var body: some View {
        SettingsScroll {
            ProfileHeader()
            SettingsCard { LaunchAtLoginToggle() }
            SettingsCard(title: "Permissions", footer: "macOS asks the first time Ledge needs each one. If you said no, turn it on in System Settings.") {
                PermissionRow(title: "Music, Spotify and browsers", detail: "Read and control the song", pane: "Privacy_Automation")
                PermissionRow(title: "Location", detail: "Local weather", pane: "Privacy_LocationServices")
                PermissionRow(title: "Bluetooth", detail: "AirPods connect and battery", pane: "Privacy_Bluetooth")
                PermissionRow(title: "Calendar", detail: "Events on the calendar page", pane: "Privacy_Calendars")
            }
            SettingsCard(title: "Display", footer: "Choose which screens show the pill.") {
                MenuRow(title: "Display", symbol: "display", selection: $display)
            }
            SettingsCard(title: "Visibility") {
                ToggleRow("Hide in Fullscreen", isOn: $hideInFullscreen)
                ToggleRow("Hide from Screen Capture", isOn: $hideFromCapture)
                ToggleRow("Menu Bar Icon", isOn: $menuBarIcon)
            }
            SettingsCard(title: "Glass", footer: "Transparency, size, font, border, corners and accent color are in Appearance.") {
                ToggleRow("Liquid Glass View", isOn: $liquidGlass)
            }
            SettingsCard(title: "Behavior") {
                ToggleRow("Haptic Touch", isOn: $hapticTouch)
                ToggleRow("Expand on Hover", isOn: $expandOnHover)
                if expandOnHover {
                    SettingSlider(value: $hoverDelay, range: 0...10, low: "Instant", high: "Slow", lowSymbol: "bolt.fill", highSymbol: "tortoise.fill")
                }
                ToggleRow("Background Blur", isOn: $backgroundBlur)
                ToggleRow(title: "Live Waveform", isOn: $liveWaveform) {
                    Button("Allow Access ›") {
                        // System audio capture is granted under Screen & System Audio Recording.
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.plain)
                    .ledgeFont(9, .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.7)))
                }
            }
            SettingsCard(title: "Sounds") {
                ToggleRow("Lock Sound", isOn: $lockSound)
                ToggleRow("Unlock Sound", isOn: $unlockSound)
                SettingSlider(title: "Volume", value: $soundVolume, range: 0...1, display: "\(Int(soundVolume * 100))%", low: "Quiet", high: "Loud")
            }
            SettingsCard(title: "Tuning", footer: "Nudge the pill’s size until it lines up with your physical notch exactly.") {
                SettingSlider(title: "Notch Width", value: $notchWidth, range: -40...40, step: 5, display: "\(Int(notchWidth))", unit: "px", low: "", high: "")
                SettingSlider(title: "Notch Height", value: $notchHeight, range: -10...10, step: 2, display: "\(Int(notchHeight))", unit: "px", low: "", high: "")
            }
            SettingsCard(footer: "Returns every preference to its default. Launch at Login is not affected.") {
                Button { confirmReset = true } label: {
                    Text("Reset All Settings").ledgeFont(13, .semibold).foregroundStyle(.red).frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.smooth, value: expandOnHover)
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) { Preferences.resetAll() }
        }
    }
}

struct AppearancePage: View {
    @AppStorage(K.uiScale.rawValue) private var uiScale = Look().uiScale
    @AppStorage(K.pillScale.rawValue) private var pillScale = Look().pillScale
    @AppStorage(K.textScale.rawValue) private var textScale = Look().textScale
    @AppStorage(K.fontDesign.rawValue) private var font = FontChoice.system
    @AppStorage(K.borderWidth.rawValue) private var border = Look().border
    @AppStorage(K.cornerRadius.rawValue) private var radius = Look().radius
    @AppStorage(K.glassTint.rawValue) private var glassTint = Look().glassTint
    @AppStorage(K.accentColor.rawValue) private var accent = AccentChoice.system
    @StateObject private var sample = PlayerModel(preview: true)

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    var body: some View {
        SettingsScroll {
            AppearancePreview(player: sample)
            SettingsCard(title: "Size", footer: "Closed Pill Size is the pill before you hover, and the overlays in it. Interface Size is the open player and the lock screen player. Text Size changes every label, here too.") {
                SettingSlider(title: "Closed Pill Size", value: $pillScale, range: 0.8...1.6, step: 0.05, display: percent(pillScale), low: "Smaller", high: "Larger")
                SettingSlider(title: "Interface Size", value: $uiScale, range: 0.8...1.4, step: 0.05, display: percent(uiScale), low: "Smaller", high: "Larger")
                SettingSlider(title: "Text Size", value: $textScale, range: 0.85...1.5, step: 0.05, display: percent(textScale), low: "Smaller", high: "Larger")
            }
            SettingsCard(title: "Font") {
                MenuRow(title: "Font", symbol: "textformat", selection: $font)
            }
            SettingsCard(title: "Shape") {
                SettingSlider(title: "Border", value: $border, range: 0...3, step: 0.5, display: String(format: "%.1f", border), unit: "pt", low: "None", high: "Thick")
                SettingSlider(title: "Corner Radius", value: $radius, range: 0...1.5, step: 0.1, display: percent(radius), low: "Square", high: "Round")
            }
            SettingsCard(title: "Glass", footer: "Higher transparency shows more of what is behind the pill and cards.") {
                SettingSlider(title: "Glass Transparency",
                              value: Binding(get: { 1 - glassTint }, set: { glassTint = 1 - $0 }),
                              range: 0...1, step: 0.05, display: percent(1 - glassTint),
                              low: "Dark", high: "Clear", lowSymbol: "circle.fill", highSymbol: "circle")
            }
            SettingsCard(title: "Accent Color", footer: "Used for switches, sliders, the waveform and the progress bar.") {
                AccentPicker(selection: $accent)
            }
            SettingsCard(footer: "Puts size, font, border, corners, transparency and color back to their defaults.") {
                Button { Preferences.reset(Preferences.appearance) } label: {
                    Text("Reset Appearance").ledgeFont(13, .semibold).foregroundStyle(.red).frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The open notch player, redrawn live with the current appearance.
struct AppearancePreview: View {
    @ObservedObject var player: PlayerModel
    @Environment(\.look) private var look

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.r(28), style: .continuous)
        PlayerCardContent(player: player, art: 56, artGap: 17, timeInset: 4)
            .frame(width: 318)
            .background { Color.clear.glass(in: shape, tint: .black.opacity(look.glassDarkness)) }
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: look.border))
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Appearance preview")
    }
}

/// Row of color dots; the chosen one gets a ring.
struct AccentPicker: View {
    @Binding var selection: AccentChoice

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AccentChoice.allCases) { choice in
                let selected = selection == choice
                Button { selection = choice } label: {
                    Circle()
                        .fill(choice.color ?? Color.accentColor)
                        .overlay {
                            if choice == .system {
                                Image(systemName: "gearshape.fill").ledgeFont(9, .bold).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 22, height: 22)
                        .padding(3)
                        .overlay(Circle().strokeBorder(.white.opacity(selected ? 0.9 : 0), lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(.smooth, value: selection)
    }
}

struct MediaPage: View {
    @AppStorage(K.mediaPlayer.rawValue) private var mediaPlayer = true
    @AppStorage(K.pageLyrics.rawValue) private var pageLyrics = true
    @AppStorage(K.pagePrayer.rawValue) private var pagePrayer = true
    @AppStorage(K.pageCalendar.rawValue) private var pageCalendar = true
    @AppStorage(K.source.rawValue) private var source = MediaSource.auto
    @AppStorage(K.eq.rawValue) private var eq = false
    @AppStorage(K.leftButton.rawValue) private var leftButton = LeftButton.like
    @AppStorage(K.explicitTag.rawValue) private var explicitTag = true
    @AppStorage(K.explicitColor.rawValue) private var explicitColor = true
    @AppStorage(K.animatedArtwork.rawValue) private var animatedArtwork = true
    @AppStorage(K.heartMatchColor.rawValue) private var heartMatchColor = false
    @AppStorage(K.collapseOnPause.rawValue) private var collapseOnPause = true
    @AppStorage(K.hideAfter.rawValue) private var hideAfter = 0.0

    private let hideSteps = ["Instant", "5 s", "15 s", "1 min", "Never"]

    var body: some View {
        SettingsScroll {
            SettingsCard { ToggleRow("Media Player", isOn: $mediaPlayer) }
            SettingsCard(title: "Notch Pages", footer: "Extra pages in the open pill. Switch with the arrows at its sides or the dots along the bottom. Prayer times use your weather location (Kemenag method).") {
                ToggleRow("Lyrics", symbol: "quote.bubble", isOn: $pageLyrics)
                ToggleRow("Prayer Times", symbol: "sun.horizon.fill", isOn: $pagePrayer)
                ToggleRow("Calendar", symbol: "calendar", isOn: $pageCalendar)
            }
            SettingsCard(footer: "Auto shows whatever is playing music: Music, Spotify, or a Chrome or Safari tab. Pick one to only ever show that.") {
                ChoiceCards(title: "Source", selection: $source) { $0.symbol }
            }
            SettingsCard { ToggleRow("EQ", isOn: $eq) }
            if eq {
                SettingsCard { EqualizerView() }
            }
            Hint("Shape how your music sounds — tune the lows, mids, and presence for each app.")
                .padding(.horizontal, 6)
                .padding(.top, -16)
                .padding(.bottom, 24)
            SettingsCard(footer: "Pick what the player’s left button does, or None to leave the slot empty. The right button always switches your audio output.") {
                ChoiceButtons(title: "Left Button", selection: $leftButton) { $0.symbol }
            }
            SettingsCard(title: "Appearance") {
                ToggleRow("Explicit Tag", isOn: $explicitTag)
                ToggleRow("Explicit Color Match", isOn: $explicitColor)
                ToggleRow("Animated Artwork", isOn: $animatedArtwork)
                ToggleRow(title: "Heart Match Song Color", isOn: $heartMatchColor) { StateBadge(on: heartMatchColor) }
            }
            SettingsCard(title: "Behavior", footer: "Hide the player when music pauses — instantly, after a delay, or never.") {
                ToggleRow("Collapse on Pause", isOn: $collapseOnPause)
                SettingSlider(title: "Hide After", value: $hideAfter, range: 0...4, step: 1,
                              display: hideSteps[min(max(Int(hideAfter), 0), hideSteps.count - 1)],
                              low: "Instant", high: "Never")
            }
        }
        .animation(.smooth, value: eq)
    }
}

struct SensoryPage: View {
    @AppStorage(K.sensoryStyle.rawValue) private var style = SensoryStyle.notch
    @AppStorage(K.edgeSide.rawValue) private var edge = ScreenEdge.left
    @AppStorage(K.edgeHeight.rawValue) private var edgeHeight = 0.5
    @AppStorage(K.brightnessOverlay.rawValue) private var brightness = true
    @AppStorage(K.volumeOverlay.rawValue) private var volume = true
    @AppStorage(K.sensoryMatchColor.rawValue) private var matchColor = false
    @AppStorage(K.overlayLabel.rawValue) private var label = OverlayLabel.icon
    @AppStorage(K.sensoryDuration.rawValue) private var duration = 3.0

    var body: some View {
        SettingsScroll {
            SettingsCard(title: "Style") {
                SegmentRow(title: "Style", selection: $style)
            }
            if style == .apple {
                SettingsCard(title: "Position", footer: "Apple Style shows a vertical slider on the edge of the screen. Pick the edge and how high it sits.") {
                    EdgePreview(edge: edge, height: edgeHeight)
                    SegmentRow(title: "Screen Edge", selection: $edge)
                    SettingSlider(title: "Height on Screen", value: $edgeHeight, range: 0...1, display: "\(Int(edgeHeight * 100))%", low: "Top", high: "Bottom")
                }
            }
            SettingsCard(title: "Overlays") {
                ToggleRow("Brightness", symbol: "display", isOn: $brightness)
                ToggleRow("Volume", symbol: "speaker.wave.2.fill", isOn: $volume)
            }
            SettingsCard(title: "Appearance", footer: "Icon shows the display / speaker symbol in the overlay; Name shows “Display” or “Volume” as text.") {
                ToggleRow(title: "Match Song Color", isOn: $matchColor) { StateBadge(on: matchColor) }
                SegmentRow(title: "Label Style", selection: $label)
            }
            SettingsCard {
                SettingSlider(title: "Overlay Duration", value: $duration, range: 1...6, step: 1, display: "\(Int(duration))", unit: "sec", low: "1", high: "6")
            }
        }
        .animation(.smooth, value: style)
    }
}

struct BatteryPage: View {
    @AppStorage(K.chargerConnect.rawValue) private var chargerConnect = true
    @AppStorage(K.batteryStyle.rawValue) private var style = BatteryStyle.classic
    @AppStorage(K.batteryDuration.rawValue) private var duration = 5.0

    var body: some View {
        SettingsScroll {
            SettingsCard { ToggleRow("Charger Connect", isOn: $chargerConnect) }
            SettingsCard { ChoiceCards(title: "Battery Style", selection: $style) { $0.symbol } }
            SettingsCard {
                SettingSlider(title: "Overlay Duration", value: $duration, range: 2...8, step: 1, display: "\(Int(duration))", unit: "sec", low: "2", high: "8")
            }
        }
    }
}

struct FocusPage: View {
    @AppStorage(K.focusOverlay.rawValue) private var focusOverlay = true
    @AppStorage(K.focusShowBattery.rawValue) private var showBattery = true
    @AppStorage(K.focusShowAirPods.rawValue) private var showAirPods = true
    @AppStorage(K.focusShowSensory.rawValue) private var showSensory = true
    @AppStorage(K.focusWidget.rawValue) private var focusWidget = true

    var body: some View {
        SettingsScroll {
            SettingsCard(footer: "Show an overlay in the pill when a Focus mode turns on or off.") {
                ToggleRow("Focus Overlay", isOn: $focusOverlay)
            }
            SettingsCard(title: "While in Focus, also show", footer: "Overlays switched off here stay hidden while a Focus mode is active.") {
                ToggleRow("Battery Overlay", symbol: "bolt.fill", isOn: $showBattery)
                ToggleRow("AirPods Overlay", symbol: "airpodspro", isOn: $showAirPods)
                ToggleRow("Sensory Overlay", symbol: "sun.max.fill", isOn: $showSensory)
            }
            SettingsCard(title: "Lock Screen", footer: "Show the active Focus mode on the lock screen.") {
                ToggleRow("Focus Widget", symbol: "lock.fill", isOn: $focusWidget)
            }
        }
    }
}

struct WeatherPage: View {
    @AppStorage(K.weather.rawValue) private var weather = true
    @AppStorage(K.weatherDetailed.rawValue) private var detailed = false
    @AppStorage(K.preciseLocation.rawValue) private var preciseLocation = true

    var body: some View {
        SettingsScroll {
            WeatherPreview()
            SettingsCard(footer: "Swipe left across the expanded pill to flip between the player and the weather page.") {
                ToggleRow("Weather", isOn: $weather)
            }
            SettingsCard(title: "Appearance", footer: "Show the weather page in an alternate layout instead of the default widget style.") {
                ToggleRow("Detailed View", symbol: "cloud.sun.fill", isOn: $detailed)
            }
            SettingsCard(title: "Location", footer: "Uses your Mac’s location for accurate local weather. When off, the app estimates your city from your IP address instead.") {
                ToggleRow(title: "Precise Location", symbol: "location.fill", isOn: $preciseLocation) { StateBadge(on: preciseLocation) }
            }
        }
        .onChange(of: weather) { WeatherModel.shared.refresh() }
        .onChange(of: preciseLocation) { WeatherModel.shared.refresh() }
    }
}

struct LockScreenPage: View {
    @AppStorage(K.lockScreenPlayer.rawValue) private var onLockScreen = true
    @AppStorage(K.lockGlass.rawValue) private var glass = GlassStyle.frosted
    @AppStorage(K.lockFullArt.rawValue) private var fullArt = true
    @AppStorage(K.lockLyrics.rawValue) private var lyrics = true
    @AppStorage(K.lyricsSync.rawValue) private var sync = 0.0
    @AppStorage(K.lockGlassArt.rawValue) private var glassArt = false
    @AppStorage(K.lockGlassCard.rawValue) private var glassCard = true
    @AppStorage(K.keepAwake.rawValue) private var keepAwake = false

    var body: some View {
        SettingsScroll {
            LockPreview()
            SettingsCard(footer: "Experimental: uses a private part of macOS, so a macOS update can stop it from showing. Nothing else breaks if it does.") {
                ToggleRow("Show Player on Lock Screen", isOn: $onLockScreen)
            }
            SettingsCard { ChoiceButtons(title: "Glass Style", selection: $glass) }
            SettingsCard(title: "Behavior") {
                ToggleRow("Full Art", isOn: $fullArt)
                ToggleRow("Lyrics", isOn: $lyrics)
                SettingSlider(title: "Sync", value: $sync, range: -500...500, step: 50, display: "\(Int(sync)) ms", low: "Later", high: "Earlier")
                ToggleRow("Glass Art", isOn: $glassArt)
                ToggleRow("Glass Card", isOn: $glassCard)
            }
            SettingsCard { ToggleRow("Keep Display Awake", isOn: $keepAwake) }
        }
    }
}

struct AccessoriesPage: View {
    @AppStorage(K.accessoryConnect.rawValue) private var accessoryConnect = true
    @AppStorage(K.outputChange.rawValue) private var outputChange = true
    @AppStorage(K.listeningMode.rawValue) private var listeningMode = true
    @AppStorage(K.accessoryStyle.rawValue) private var style = AccessoryStyle.single
    @AppStorage(K.glyph3D.rawValue) private var glyph3D = true
    @AppStorage(K.accessoryDuration.rawValue) private var duration = 4.0

    var body: some View {
        SettingsScroll {
            SettingsCard { ToggleRow("Accessory Connect", isOn: $accessoryConnect) }
            SettingsCard { ToggleRow("Output Change", isOn: $outputChange) }
            SettingsCard { ToggleRow("Listening Mode", isOn: $listeningMode) }
            SettingsCard { ChoiceCards(title: "Accessory Style", selection: $style, showNames: false) { $0.symbol } }
            SettingsCard { ToggleRow("3D Glyph in Media Player", isOn: $glyph3D) }
            SettingsCard {
                SettingSlider(title: "Overlay Duration", value: $duration, range: 2...8, step: 1, display: "\(Int(duration))", unit: "sec", low: "2", high: "8")
            }
        }
    }
}

struct UpdatePage: View {
    @ObservedObject private var updater = Updater.shared
    @AppStorage(K.autoUpdate.rawValue) private var autoUpdate = true
    @AppStorage(K.crashReports.rawValue) private var crashReports = true
    @AppStorage(K.lastUpdateCheck.rawValue) private var lastCheck = 0.0
    @State private var showNotes = false

    private var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "dev" }

    private var lastChecked: String {
        lastCheck == 0 ? "Not checked yet"
            : "Last checked " + Date(timeIntervalSince1970: lastCheck).formatted(date: .abbreviated, time: .shortened)
    }

    private var statusTitle: String {
        switch updater.status {
        case .idle, .upToDate: "You’re up to date"
        case .checking: "Checking…"
        case .downloading(let v): "Downloading Ledge \(v)…"
        case .installing(let v): "Installing Ledge \(v) — Ledge will reopen"
        case .notInstalled: "Updates work in the installed app"
        case .failed: "Update failed"
        }
    }

    private var statusSubtitle: String {
        switch updater.status {
        case .failed(let message): message
        case .notInstalled: "Build it with scripts/build-app.sh and open Ledge.app."
        default: lastChecked
        }
    }

    var body: some View {
        SettingsScroll {
            SettingsCard(title: "Current Version") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ledge \(updater.currentVersion)").ledgeFont(13, .bold, mono: true)
                        Text("Build \(build)").ledgeFont(10, mono: true).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "gearshape.fill").ledgeFont(18).foregroundStyle(.secondary)
                }
            }
            SettingsCard(title: "Updates", footer: "Ledge updates itself from github.com/\(Updater.repository). Each download must carry your signature, or it is not installed.") {
                ActionRow(title: statusTitle, subtitle: statusSubtitle, button: "Check",
                          ok: updater.status == .upToDate || updater.status == .idle) {
                    Task { await updater.checkAndInstall() }
                }
            }
            SettingsCard {
                ToggleRow("Automatically install updates", isOn: $autoUpdate)
                ToggleRow("Send crash reports", isOn: $crashReports)
                ActionRow(title: "Changelog", subtitle: "What’s new in the latest release", button: "View") { showNotes = true }
            }
        }
        .animation(.smooth, value: updater.status)
        .sheet(isPresented: $showNotes) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Changelog").ledgeFont(17, .bold)
                ScrollView {
                    Text(updater.notes.isEmpty ? "Press Check to load the latest release notes." : updater.notes)
                        .ledgeFont(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                Button("Done") { showNotes = false }
                    .keyboardShortcut(.defaultAction)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
            .frame(width: 420, height: 360)
        }
    }
}
