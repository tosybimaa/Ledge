import AppKit
import SwiftUI

public struct LedgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app
    @AppStorage(K.menuBarIcon.rawValue) private var menuBarIcon = true

    public init() {}

    public var body: some Scene {
        MenuBarExtra("Ledge", systemImage: "capsule.fill", isInserted: $menuBarIcon) {
            AppMenu(notch: app.notch)
        }
        Settings { SettingsView() }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Lazy so both are created on the main actor at first use.
    lazy var player = PlayerModel()
    lazy var notch = NotchController(player: player)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app with no Dock icon. In an Xcode app target, set LSUIElement in Info.plist instead.
        NSApp.setActivationPolicy(.accessory)
        notch.show()
        Updater.shared.startAutomaticChecks()
    }
}

struct AppMenu: View {
    @ObservedObject var notch: NotchController
    @AppStorage(K.source.rawValue) private var source = MediaSource.auto
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(notch.isHidden ? "Show" : "Hide") { notch.toggleHidden() }
        Divider()
        Picker(selection: $source) {
            ForEach(MediaSource.allCases) { Text($0.rawValue).tag($0) }
        } label: {
            Label("Source: \(source.rawValue)", systemImage: "music.note")
        }
        Divider()
        Button("File Tray — Coming Soon") {}.disabled(true)
        Divider()
        // Preview tools for the front-end stage; remove once the system hooks fire these for real.
        Menu("Preview") {
            Button("Lock Screen") { notch.showLockPreview() }
            Menu("Overlay") {
                Button("Charging") { notch.flash(.charging(100)) }
                Button("Volume") { notch.flash(.volume(0.6)) }
                Button("Brightness") { notch.flash(.brightness(0.8)) }
                Button("Focus") { notch.flash(.focus(true)) }
                Button("Lock") { notch.flash(.lock(true)) }
                Button("AirPods") { notch.flash(.accessory("AirPods Pro", 82)) }
                Button("Output") { notch.flash(.output("MacBook Speakers")) }
            }
        }
        Divider()
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
