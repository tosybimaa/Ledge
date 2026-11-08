import AppKit
import SwiftUI

/// Owns the borderless panel that sits over the notch, plus the overlay that is showing.
@MainActor
final class NotchController: ObservableObject {
    @Published var expanded = false
    @Published var isHidden = false
    @Published var hud: NotchHUD?

    let player: PlayerModel
    private var panel: NSPanel?
    private var hudTask: Task<Void, Never>?
    private var lockPreview: NSWindow?

    /// The panel stays at the largest size the pill grows to. Transparent pixels let clicks through.
    /// shortcut: if clicks under the pill get swallowed on some macOS version, resize the panel to the pill instead.
    static let canvas = CGSize(width: 760, height: 340)  // room for Interface Size up to 140 %

    init(player: PlayerModel) { self.player = player }

    func show() {
        // shortcut: one panel on the notched (or main) screen; the Display setting needs one panel per screen later.
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let c = Self.canvas
        let frame = NSRect(x: screen.frame.midX - c.width / 2, y: screen.frame.maxY - c.height, width: c.width, height: c.height)
        let panel = NotchPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingView(rootView: NotchView(player: player, notch: self, notchSize: NotchGeometry.notchSize(for: screen)).withLook())
        host.sizingOptions = []  // keep the panel fixed; SwiftUI would otherwise resize it as the pill grows
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func toggleHidden() {
        isHidden.toggle()
        if isHidden { expanded = false }
    }

    /// Shows an overlay in the pill, then shrinks back.
    func flash(_ hud: NotchHUD, seconds: Double = 3) {
        hudTask?.cancel()
        expanded = false
        self.hud = hud
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hud = nil
        }
    }

    /// Lock screen layout in a normal window. Drawing over the real lock screen needs private APIs (system step).
    func showLockPreview() {
        if lockPreview == nil {
            // Fill the screen so the layout matches a real lock screen.
            let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 860)
            let window = NSWindow(contentRect: frame,
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "Lock Screen Preview"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: LockScreenPlayerView(player: player).withLook())
            lockPreview = window
        }
        NSApp.activate()
        lockPreview?.makeKeyAndOrderFront(nil)
    }
}

/// Borderless panels refuse key status by default, which blocks the output popover and first clicks.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

enum NotchGeometry {
    /// Physical notch size, or nil on screens without one (the pill then floats as a capsule).
    static func notchSize(for screen: NSScreen) -> CGSize? {
        let top = screen.safeAreaInsets.top
        guard top > 0,
              let left = screen.auxiliaryTopLeftArea?.width,
              let right = screen.auxiliaryTopRightArea?.width
        else { return nil }
        return CGSize(width: screen.frame.width - left - right, height: top)
    }
}
