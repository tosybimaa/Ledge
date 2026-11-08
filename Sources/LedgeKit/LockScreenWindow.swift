import AppKit
import SwiftUI

/// Puts the mini player on the macOS lock screen while the Mac is locked (Settings › Lock Screen).
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

    private static let size = CGSize(width: 360, height: 210)
    private let player: PlayerModel
    private var window: NSPanel?
    private var unavailable = false

    init(player: PlayerModel) { self.player = player }

    func show() {
        guard UserDefaults.standard.bool(forKey: K.lockScreenPlayer.rawValue), !unavailable,
              let screen = NSScreen.main else { return }
        if window == nil { window = makeWindow() }
        guard let window else {
            unavailable = true
            return
        }
        // Card top at 57.5 % of the screen height, like the reference lock screen.
        let frame = screen.frame
        window.setFrameOrigin(NSPoint(x: frame.midX - Self.size.width / 2,
                                      y: frame.maxY - frame.height * 0.575 - Self.size.height))
        window.orderFrontRegardless()
    }

    func hide() { window?.orderOut(nil) }

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

        let panel = NotchPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                               styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let host = NSHostingView(rootView: LockScreenCard(player: player).withLook())
        host.sizingOptions = []
        panel.contentView = host
        _ = unsafeBitCast(addWindows, to: AddWindows.self)(connection, space, [panel.windowNumber] as CFArray, 7)
        return panel
    }
}

/// The mini player as it sits on the lock screen; invisible while nothing is playing.
private struct LockScreenCard: View {
    @ObservedObject var player: PlayerModel

    var body: some View {
        MiniPlayerCard(player: player) {}
            .opacity(player.hasTrack ? 1 : 0)
            .animation(.smooth, value: player.hasTrack)
            .frame(width: 360, height: 210)
            .environment(\.colorScheme, .dark)
    }
}
