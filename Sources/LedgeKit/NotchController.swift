import AppKit
import Combine
import SwiftUI

/// Owns the pill panels (one per display, per Settings › Display), the overlay that is showing,
/// and the edge slider for Sensory › Apple Style.
@MainActor
final class NotchController: ObservableObject {
    @Published var expanded = false {
        didSet { if expanded, !oldValue { haptic() } }
    }
    @Published var isHidden = false
    @Published var hud: NotchHUD?
    @Published var edgeHUD: NotchHUD?

    let player: PlayerModel
    private var panels: [NotchPanel] = []
    private var edgePanel: NotchPanel?
    private var hudTask: Task<Void, Never>?
    private var lockPreview: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var pauseWatch: AnyCancellable?
    private var shownDisplay = ""

    /// Each panel stays at the largest size the pill grows to. Transparent pixels let clicks through.
    /// shortcut: if clicks under the pill get swallowed on some macOS version, resize the panel to the pill instead.
    static let canvas = CGSize(width: 760, height: 340)  // room for the size sliders up to 140–160 %

    init(player: PlayerModel) { self.player = player }

    private static func isOn(_ key: K) -> Bool {
        UserDefaults.standard.bool(forKey: key.rawValue)
    }

    func show() {
        rebuildPanels()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildPanels() }
        })
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.settingsChanged() }
        })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateFullscreen() }
            })
        }
        // After sleep the window server can drop or move the pill windows; rebuild them on wake.
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.rebuildPanels() }
            })
        }
        // Settings › Media › Collapse on Pause.
        pauseWatch = player.$isPlaying.removeDuplicates().sink { [weak self] playing in
            guard let self, !playing, self.expanded, Self.isOn(.collapseOnPause) else { return }
            self.expanded = false
        }
    }

    func toggleHidden() {
        isHidden.toggle()
        if isHidden { expanded = false }
    }

    /// Shows an overlay in the pill (or on the screen edge for Apple Style volume), then hides it.
    func flash(_ hud: NotchHUD, seconds: Double? = nil) {
        hudTask?.cancel()
        let onEdge = hud.level != nil
            && UserDefaults.standard.string(forKey: K.sensoryStyle.rawValue) == SensoryStyle.apple.rawValue
        if onEdge { showEdge(hud) } else { self.hud = hud }
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds ?? hud.duration))
            guard !Task.isCancelled else { return }
            self?.hud = nil
            self?.edgeHUD = nil
        }
    }

    // MARK: - Panels

    private func rebuildPanels() {
        panels.forEach { $0.orderOut(nil) }
        let choice = DisplayChoice(rawValue: UserDefaults.standard.string(forKey: K.display.rawValue) ?? "") ?? .all
        shownDisplay = choice.rawValue
        let screens: [NSScreen] = switch choice {
        case .all: NSScreen.screens
        case .builtIn: NSScreen.screens.filter { CGDisplayIsBuiltin($0.displayID) != 0 }
        case .main: NSScreen.main.map { [$0] } ?? []
        }
        panels = screens.map { screen in
            let c = Self.canvas
            let frame = NSRect(x: screen.frame.midX - c.width / 2, y: screen.frame.maxY - c.height, width: c.width, height: c.height)
            let view = NotchView(player: player, notch: self, notchSize: NotchGeometry.notchSize(for: screen)).withLook()
            let panel = Self.makePanel(frame: frame, root: view)
            panel.screenFrame = screen.frame
            return panel
        }
        applyCapture()
        updateFullscreen()
    }

    private func settingsChanged() {
        if (UserDefaults.standard.string(forKey: K.display.rawValue) ?? DisplayChoice.all.rawValue) != shownDisplay { rebuildPanels() }
        applyCapture()
        updateFullscreen()
    }

    /// Settings › Hide from Screen Capture.
    private func applyCapture() {
        let hidden = Self.isOn(.hideFromCapture)
        (panels + [edgePanel].compactMap { $0 }).forEach { $0.sharingType = hidden ? .none : .readOnly }
    }

    /// Settings › Hide in Fullscreen: a front-app window as big as the screen means that screen is full screen.
    private func updateFullscreen() {
        let sizes = Self.isOn(.hideInFullscreen) ? Self.frontWindowSizes() : []
        for panel in panels {
            let covered = sizes.contains { abs($0.width - panel.screenFrame.width) < 1 && abs($0.height - panel.screenFrame.height) < 1 }
            if covered { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        }
    }

    private static func frontWindowSizes() -> [CGSize] {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return windows.compactMap { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat]
            else { return nil }
            return CGSize(width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
        }
    }

    private func showEdge(_ hud: NotchHUD) {
        edgeHUD = hud
        guard let screen = NSScreen.main else { return }
        let size = CGSize(width: 64, height: 160)
        let right = UserDefaults.standard.string(forKey: K.edgeSide.rawValue) == ScreenEdge.right.rawValue
        let height = UserDefaults.standard.double(forKey: K.edgeHeight.rawValue)
        let area = screen.visibleFrame
        let frame = NSRect(x: right ? area.maxX - size.width - 8 : area.minX + 8,
                           y: area.maxY - size.height - (area.height - size.height) * height,
                           width: size.width, height: size.height)
        if edgePanel == nil {
            edgePanel = Self.makePanel(frame: frame, root: EdgeHUDView(notch: self).withLook())
            applyCapture()
        }
        edgePanel?.setFrame(frame, display: true)
        edgePanel?.orderFrontRegardless()
    }

    private static func makePanel<Root: View>(frame: NSRect, root: Root) -> NotchPanel {
        let panel = NotchPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []  // keep the panel fixed; SwiftUI would otherwise resize it as the pill grows
        panel.contentView = host
        panel.orderFrontRegardless()
        return panel
    }

    /// Settings › Haptic Touch: a tap on the trackpad when the player opens.
    private func haptic() {
        guard Self.isOn(.hapticTouch) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    /// Lock screen layout in a normal window. Drawing over the real lock screen needs Apple's private APIs.
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
    var screenFrame = NSRect.zero
    override var canBecomeKey: Bool { true }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
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
