import AppKit
import AudioToolbox
import CoreAudio
import IOBluetooth
import IOKit.ps

/// Battery level from IOKit.
enum Battery {
    static func status() -> (percent: Int, charging: Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
              let percent = description[kIOPSCurrentCapacityKey] as? Int
        else { return nil }
        return (percent, description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
    }
}

/// Watches the Mac and turns events into overlays: charger, volume, output, AirPods, lock and unlock.
/// Each one respects its switch in Settings.
@MainActor
final class SystemMonitor: NSObject {
    private let notch: NotchController
    private var wasCharging = Battery.status()?.charging ?? false
    private var lastVolume: Float?
    private var watchedDevice = AudioDeviceID(0)
    private var volumeBlock: AudioObjectPropertyListenerBlock?
    private var muteBlock: AudioObjectPropertyListenerBlock?
    private var outputBlock: AudioObjectPropertyListenerBlock?
    private var powerSource: CFRunLoopSource?

    init(notch: NotchController) {
        self.notch = notch
        super.init()
    }

    private func isOn(_ key: K) -> Bool {
        UserDefaults.standard.bool(forKey: key.rawValue)
    }

    func start() {
        // Charger plugged in.
        powerSource = IOPSNotificationCreateRunLoopSource({ _ in
            NotificationCenter.default.post(name: .ledgePowerChanged, object: nil)
        }, nil)?.takeRetainedValue()
        if let powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
        NotificationCenter.default.addObserver(forName: .ledgePowerChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.powerChanged() }
        }

        // Lock and unlock (sounds, plus a short overlay after unlocking).
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.locked(true) }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.locked(false) }
        }

        // Output device and its volume.
        outputBlock = AudioDevices.listen(AudioDevices.systemObject, kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
            Task { @MainActor in self?.outputChanged(announce: true) }
        }
        outputChanged(announce: false)

        // AirPods and other Bluetooth audio. Without the Bluetooth usage text (a `swift run` build) macOS would kill the app.
        if Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") != nil {
            IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(bluetoothConnected(_:device:)))
        }
    }

    private func powerChanged() {
        guard let battery = Battery.status() else { return }
        defer { wasCharging = battery.charging }
        guard battery.charging, !wasCharging, isOn(.chargerConnect) else { return }
        notch.flash(.charging(battery.percent))
    }

    private func locked(_ isLocked: Bool) {
        let soundOn = isOn(isLocked ? .lockSound : .unlockSound)
        if soundOn, let sound = NSSound(named: isLocked ? "Pop" : "Tink") {
            sound.volume = Float(UserDefaults.standard.double(forKey: K.soundVolume.rawValue))
            sound.play()
        }
        notch.setLocked(isLocked)
        if !isLocked { notch.flash(.lock(false), seconds: 1.5) }
    }

    private func outputChanged(announce: Bool) {
        notch.player.refreshOutputs()
        let device = AudioDevices.defaultOutput()
        if device != watchedDevice {
            if let volumeBlock { AudioDevices.stopListening(watchedDevice, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput, volumeBlock) }
            if let muteBlock { AudioDevices.stopListening(watchedDevice, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput, muteBlock) }
            watchedDevice = device
            lastVolume = AudioDevices.volume(of: device)
            volumeBlock = AudioDevices.listen(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput) { [weak self] in
                Task { @MainActor in self?.volumeChanged() }
            }
            muteBlock = AudioDevices.listen(device, kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput) { [weak self] in
                Task { @MainActor in self?.volumeChanged() }
            }
        }
        if announce, isOn(.outputChange) {
            notch.flash(.output(AudioDevices.name(of: device)))
        }
    }

    private func volumeChanged() {
        guard let volume = AudioDevices.volume(of: watchedDevice) else { return }
        let shown = AudioDevices.isMuted(watchedDevice) ? 0 : volume
        defer { lastVolume = volume }
        guard isOn(.volumeOverlay) else { return }
        notch.flash(.volume(Double(shown)))
    }

    @objc private func bluetoothConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Audio devices only (headphones, speakers): major device class 4.
        guard device.deviceClassMajor == 4, isOn(.accessoryConnect) else { return }
        let name = device.name ?? "Headphones"
        notch.flash(.accessory(name, -1))
        Task {
            if let percent = await Self.batteryPercent(of: name) { notch.flash(.accessory(name, percent)) }
        }
    }

    /// AirPods battery from `system_profiler` (public, a second or two slow). Lowest of left/right, else main.
    private nonisolated static func batteryPercent(of name: String) async -> Int? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json"]
            let pipe = Pipe()
            process.standardOutput = pipe
            guard (try? process.run()) != nil else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return SystemMonitor.parseBattery(data, name: name)
        }.value
    }

    /// Finds `name` in system_profiler's JSON and returns its battery percent.
    nonisolated static func parseBattery(_ json: Data, name: String) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        for controller in controllers {
            for entry in controller["device_connected"] as? [[String: Any]] ?? [] {
                guard let info = entry[name] as? [String: Any] else { continue }
                let percent: (String) -> Int? = { key in
                    (info[key] as? String).flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) }
                }
                let buds = [percent("device_batteryLevelLeft"), percent("device_batteryLevelRight")].compactMap { $0 }
                return buds.min() ?? percent("device_batteryLevelMain")
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let ledgePowerChanged = Notification.Name("ledgePowerChanged")
}
