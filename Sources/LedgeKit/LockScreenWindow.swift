import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Puts the planned lock-screen layout (weather row, mini player, artwork and lyrics views, side buttons)
/// over the macOS lock screen while the Mac is locked (Settings › Lock Screen).
/// Normal windows sit under the lock screen; this one is moved into a SkyLight window space that
/// macOS draws above it, the same way Canopy does.
/// shortcut: SkyLight is private to Apple. If a macOS update renames these calls, the player just doesn't
/// appear on the lock screen (nothing crashes); check the symbol names again after big macOS updates.
@MainActor
final class LockScreenWindow {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindows = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    private let player: PlayerModel
    private var window: NSPanel?
    private var unavailable = false
    private var awake: IOPMAssertionID = 0

    init(player: PlayerModel) { self.player = player }

    func show() {
        guard UserDefaults.standard.bool(forKey: K.lockScreenPlayer.rawValue), !unavailable,
              let screen = NSScreen.main else { return }
        if window == nil { window = makeWindow() }
        guard let window else {
            unavailable = true
            return
        }
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        // Settings › Lock Screen › Keep Display Awake, while music plays.
        if UserDefaults.standard.bool(forKey: K.keepAwake.rawValue), player.isPlaying, awake == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "Ledge lock screen player" as CFString, &awake)
        }
    }

    func hide() {
        window?.orderOut(nil)
        if awake != 0 {
            IOPMAssertionRelease(awake)
            awake = 0
        }
    }

    private func makeWindow() -> NSPanel? {
        guard let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
              let mainConnection = dlsym(sky, "SLSMainConnectionID"),
              let spaceCreate = dlsym(sky, "SLSSpaceCreate"),
              let spaceSetLevel = dlsym(sky, "SLSSpaceSetAbsoluteLevel"),
              let showSpaces = dlsym(sky, "SLSShowSpaces"),
              let addWindows = dlsym(sky, "SLSSpaceAddWindowsAndRemoveFromSpaces")
        else { return nil }

        let connection = unsafeBitCast(mainConnection, to: MainConnection.self)()
        let space = unsafeBitCast(spaceCreate, to: SpaceCreate.self)(connection, 1, 0)
        _ = unsafeBitCast(spaceSetLevel, to: SpaceSetLevel.self)(connection, space, 400)
        _ = unsafeBitCast(showSpaces, to: ShowSpaces.self)(connection, [space] as CFArray)

        // A plain borderless panel never becomes key, so your typing still goes to the password field.
        // Transparent areas let clicks through to the login controls underneath.
        let panel = NSPanel(contentRect: NSScreen.main?.frame ?? .zero,
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: LockScreenPlayerView(player: player, onLockScreen: true).withLook())
        host.sizingOptions = []
        panel.contentView = host
        _ = unsafeBitCast(addWindows, to: AddWindows.self)(connection, space, [panel.windowNumber] as CFArray, 7)
        return panel
    }
}
