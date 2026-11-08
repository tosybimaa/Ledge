import AudioToolbox
import CoreAudio
import Foundation

/// Speakers and headphones from Core Audio: list them, read and switch the default output, read its volume.
enum AudioDevices {
    struct Device {
        let id: AudioDeviceID
        let name: String
    }

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector,
                        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func outputs() -> [Device] {
        var where_ = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &where_, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &where_, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter(hasOutput).map { Device(id: $0, name: name(of: $0)) }
    }

    static func defaultOutput() -> AudioDeviceID {
        var where_ = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(system, &where_, 0, nil, &size, &id)
        return id
    }

    static func setDefaultOutput(_ id: AudioDeviceID) {
        var where_ = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = id
        AudioObjectSetPropertyData(system, &where_, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
    }

    static func name(of id: AudioDeviceID) -> String {
        var where_ = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &where_, 0, nil, &size, &name) == noErr, let name else { return "Unknown" }
        return name.takeRetainedValue() as String
    }

    /// 0…1, or nil when the device has no software volume (some HDMI and USB outputs).
    static func volume(of id: AudioDeviceID) -> Float? {
        var where_ = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectHasProperty(id, &where_),
              AudioObjectGetPropertyData(id, &where_, 0, nil, &size, &volume) == noErr else { return nil }
        return volume
    }

    static func isMuted(_ id: AudioDeviceID) -> Bool {
        var where_ = address(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectHasProperty(id, &where_),
              AudioObjectGetPropertyData(id, &where_, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var where_ = address(kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &where_, 0, nil, &size) == noErr && size > 0
    }

    /// Calls `handler` on the main queue whenever the property changes.
    static func listen(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                       _ handler: @escaping () -> Void) -> AudioObjectPropertyListenerBlock {
        var where_ = address(selector, scope)
        let block: AudioObjectPropertyListenerBlock = { _, _ in handler() }
        AudioObjectAddPropertyListenerBlock(id, &where_, .main, block)
        return block
    }

    static func stopListening(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                              _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                              _ block: @escaping AudioObjectPropertyListenerBlock) {
        var where_ = address(selector, scope)
        AudioObjectRemovePropertyListenerBlock(id, &where_, .main, block)
    }

    static var systemObject: AudioObjectID { system }
}
