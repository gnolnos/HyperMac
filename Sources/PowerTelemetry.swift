import Foundation
import IOKit
import Combine
import AppKit

// MARK: - Power telemetry (Activity Monitor-style POWER/ENERGY) — read AppleSmartBattery in-process.
//
// Nguồn (đã verify trên M1 + Intel):
//  - Apple Silicon: `PowerTelemetryData` (SystemLoad mW, SystemPowerIn mW, BatteryPower signed mW,
//    AccumulatedSystemLoad / SystemLoadAccumulatorCount, AccumulatedSystemEnergyConsumed µWh).
//  - Intel: `BatteryData` (SystemPower mA, Amperage mA) + `Voltage` mV → W = mA·mV/1e6.
// Không spawn subprocess, không cần root, @MainActor singleton (khớp style BatteryManager).

public struct PowerSnapshot: Equatable {
    public var systemTotalW: Double = 0        // System Total (W)
    public var dcinW: Double = 0               // DC In / adapter (W) — AS only
    public var batteryW: Double = 0            // +sạc / −xả (W)
    public var averageW: Double = 0            // Average System Total (W) — AS only
    public var consumedWh: Double = 0          // Total System Consumption (Wh) — AS only
    public var voltage: Double = 0             // V
    public var amperage: Int = 0               // mA (âm = xả)
    public var isPluggedIn: Bool = false
    public var timestamp: Date = Date()
}

@MainActor
public final class PowerTelemetryManager: ObservableObject {
    public static let shared = PowerTelemetryManager()

    @Published public private(set) var snapshot = PowerSnapshot()

    private var timer: Timer?

    private init() {
        // đọc 1 lần khi khởi tạo để UI có số ngay
        if HardwareInfo.isAppleSilicon { refresh() }
    }

    /// Bật timer chạy khi popover hover đang mở; tự tắt khi đóng. Không loop khi ẩn.
    public func setPopoverVisible(_ v: Bool) {
        timer?.invalidate(); timer = nil
        guard v else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    private func readProps() -> ([String: Any], [String: Any], [String: Any])? {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != 0 else { return nil }
        defer { IOObjectRelease(svc) }
        func dict(_ key: String) -> [String: Any] {
            IORegistryEntryCreateCFProperty(svc, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] ?? [:]
        }
        var top: [String: Any] = [:]
        if let d = IORegistryEntryCreateCFProperty(svc, "ExternalConnected" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool { top["ExternalConnected"] = d }
        if let d = IORegistryEntryCreateCFProperty(svc, "IsCharging" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool { top["IsCharging"] = d }
        let bd = dict("BatteryData")
        let td = dict("PowerTelemetryData")
        if bd.isEmpty && td.isEmpty { return nil }
        return (top, bd, td)
    }

    public func refresh() {
        guard let (top, battery, tele) = readProps() else { return }
        var s = PowerSnapshot()
        let isAS = HardwareInfo.isAppleSilicon

        s.isPluggedIn = top["ExternalConnected"] as? Bool ?? false
        s.voltage = (battery["Voltage"] as? Int).map { Double($0) / 1000.0 }
            ?? (tele["SystemVoltageIn"] as? Int).map { Double($0) / 1000.0 }
            ?? 0
        s.amperage = (battery["Amperage"] as? Int) ?? (battery["InstantAmperage"] as? Int) ?? (tele["SystemCurrentIn"] as? Int) ?? 0

        if isAS {
            // mW → W; µWh → Wh
            if let v = tele["SystemLoad"] as? Int { s.systemTotalW = Double(v) / 1000.0 }
            if let v = tele["SystemPowerIn"] as? Int { s.dcinW = Double(v) / 1000.0 }
            // BatteryPower có thể là UInt64 bọc dấu (xả = 2^64 − n) — ép về Int64.
            if let v = tele["BatteryPower"] as? Int { s.batteryW = Double(v) / 1000.0 }
            else if let v = tele["BatteryPower"] as? UInt64 { s.batteryW = Double(Int64(bitPattern: v)) / 1000.0 }
            if let acc = tele["AccumulatedSystemLoad"] as? Int,
               let cnt = tele["SystemLoadAccumulatorCount"] as? Int, cnt > 0 {
                s.averageW = Double(acc) / Double(cnt) / 1000.0
            }
            if let v = tele["AccumulatedSystemEnergyConsumed"] as? Int { s.consumedWh = Double(v) / 1_000_000.0 }
            else if let v = tele["AccumulatedSystemEnergyConsumed"] as? UInt64 { s.consumedWh = Double(Int64(bitPattern: v)) / 1_000_000.0 }
        } else {
            // Intel: SystemPower (mA) × Voltage (V) = mW → /1000 = W ; Amperage × V = battery W
            if let sp = battery["SystemPower"] as? Int, s.voltage > 0 {
                s.systemTotalW = Double(sp) * s.voltage / 1_000.0
            }
            if s.amperage != 0, s.voltage > 0 {
                s.batteryW = Double(s.amperage) * s.voltage / 1_000.0
            }
        }
        s.timestamp = Date()
        if s != snapshot { snapshot = s }
    }
}
