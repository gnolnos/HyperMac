import Foundation
import CoreAudio

// MARK: - Quản lý loa/thiết bị âm thanh (Core Audio native, 0 subprocess) — tổng hợp cách AudioSwitcher "Multi-Output"
// + cách MA đẩy audio đồng bộ. macOS không có API tạo AirPlay2 group; Multi-Output device (audio ảo gộp nhiều
// output) là cơ chế khả thi native: mọi app phát → tất cả loa trong group cùng kêu (loose-sync local).

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    var name: String
    var transport: String      // Built-in / AirPlay / Bluetooth / HDMI / USB / Aggregate…
    var isDefault: Bool
    var isAlive: Bool
    var isMultiOutput: Bool
    var volume01: Float        // 0–1, -1 = không hỗ trợ
}

// Private Core Audio funcs (cùng kỹ thuật Audio MIDI Setup / macos-audio-devices để tạo Multi-Output ảo)
@_silgen_name("AudioHardwareCreateAggregateDevice")
private func audioHwCreateAggregate(_ desc: CFDictionary, _ out: UnsafeMutablePointer<AudioObjectID>) -> Int32
@_silgen_name("AudioHardwareDestroyAggregateDevice")
private func audioHwDestroyAggregate(_ id: AudioObjectID) -> Int32

@MainActor
final class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    @Published private(set) var devices: [AudioOutputDevice] = []
    @Published private(set) var lastError: String?

    private let system: AudioObjectID = AudioObjectID(kAudioObjectSystemObject)

    private init() { refresh() }

    // MARK: helpers
    private var devicesAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private var defaultAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)

    func refresh() {
        // default output
        var def: AudioDeviceID = 0
        var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(system, &defaultAddr, 0, nil, &sz, &def)

        // all devices
        var listSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &devicesAddr, 0, nil, &listSize) == noErr else { return }
        let count = Int(listSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard ids.count > 0,
              AudioObjectGetPropertyData(system, &devicesAddr, 0, nil, &listSize, &ids) == noErr else { return }

        var out: [AudioOutputDevice] = []
        for id in ids where isOutput(id) {
            out.append(snapshot(id, isDefault: id == def))
        }
        out.sort { $0.isDefault && !$1.isDefault ? true : ($1.isDefault && !$0.isDefault ? false : $0.name.lowercased() < $1.name.lowercased()) }
        if out != devices { devices = out }
    }

    func setDefault(_ id: AudioDeviceID) -> Bool {
        var v = id
        let ok = AudioObjectSetPropertyData(system, &defaultAddr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &v) == noErr
        if ok { refresh() } else { lastError = "Không đổi được loa mặc định" }
        return ok
    }

    // MARK: snapshot một thiết bị
    private var nameAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private var transportAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private var aliveAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsAlive, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private var volumeAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioObjectPropertyScopeOutput, mElement: 1)

    private func isOutput(_ id: AudioDeviceID) -> Bool {
        var streamsAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var sz: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &streamsAddr, 0, nil, &sz) == noErr, sz > 0 else { return false }
        return true
    }

    private func snapshot(_ id: AudioDeviceID, isDefault: Bool) -> AudioOutputDevice {
        var name: CFString? = nil
        var nsz = UInt32(MemoryLayout<CFString?>.size)
        if AudioObjectHasProperty(id, &nameAddr) {
            AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nsz, &name)
        }
        var transport: UInt32 = 0
        var tsz = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &transportAddr, 0, nil, &tsz, &transport)
        var alive: UInt32 = 0
        var asz = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &aliveAddr, 0, nil, &asz, &alive)
        var vol: Float32 = 0
        var vsz = UInt32(MemoryLayout<Float32>.size)
        let hasVol = AudioObjectHasProperty(id, &volumeAddr) &&
            AudioObjectGetPropertyData(id, &volumeAddr, 0, nil, &vsz, &vol) == noErr

        return AudioOutputDevice(
            id: id,
            name: name as String? ?? "(loa \(id))",
            transport: transportName(transport),
            isDefault: isDefault,
            isAlive: alive != 0,
            isMultiOutput: transport == kAudioDeviceTransportTypeAggregate,
            volume01: hasVol ? vol : -1
        )
    }

    private func transportName(_ t: UInt32) -> String {
        switch t {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeAirPlay: return "AirPlay"
        case kAudioDeviceTransportTypeBluetooth: return "Bluetooth"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeAggregate: return "Multi-Output"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        default: return "Khác"
        }
    }

    // MARK: Multi-Output group (AudioSwitcher style) — tạo audio ảo gộp các loa, phát đồng thời
    func toggleGroup(memberIDs: [AudioDeviceID]) -> Bool {
        // Nếu group hiện hữu → hủy trước (idempotent). Tìm aggregate device hiện có do HyperMac tạo.
        if let old = devices.first(where: { $0.isMultiOutput && $0.name.hasPrefix("HyperMac") }) {
            _ = destroy(old.id)
        }
        guard memberIDs.count >= 2 else { return false }
        // lấy UID của từng loa thành viên
        var uids: [CFString] = []
        for id in memberIDs {
            var uid: CFString? = nil
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var sz = UInt32(MemoryLayout<CFString?>.size)
            if AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &sz, &uid) == noErr, let u = uid { uids.append(u) }
        }
        guard uids.count >= 2 else { lastError = "Không đọc được UID 1 trong các loa"; return false }

        let subDevs: [CFDictionary] = uids.enumerated().map { i, uid in
            [kAudioSubDeviceUIDKey as String: uid,
             kAudioAggregateDeviceMasterSubDeviceKey as String: i == 0 ? kCFBooleanTrue : kCFBooleanFalse] as CFDictionary
        }
        let aggUID = CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "HyperMac Multi-Output",
            kAudioAggregateDeviceUIDKey as String: "com.opensource.hypermac.aggregate.\(aggUID)",
            kAudioAggregateDeviceSubDeviceListKey as String: subDevs,
            kAudioAggregateDeviceIsStackedKey as String: kCFBooleanFalse! as Any, // Multi-Output: gửi cùng stream ra mọi loa
            kAudioAggregateDeviceIsPrivateKey as String: kCFBooleanFalse! as Any,
        ]
        var out: AudioObjectID = 0
        let st = audioHwCreateAggregate(desc as CFDictionary, &out)
        if st != 0 { lastError = "Không tạo được Multi-Output (code \(st))"; return false }
        _ = setDefault(out)
        return true
    }

    func destroy(_ id: AudioDeviceID) -> Bool {
        let ok = audioHwDestroyAggregate(id) == 0
        if ok { refresh() } else { lastError = "Không hủy được group" }
        return ok
    }

    func destroyAllHyperMac() {
        for d in devices where d.isMultiOutput && d.name.hasPrefix("HyperMac") {
            _ = audioHwDestroyAggregate(d.id)
        }
        refresh()
    }
}
