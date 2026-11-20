import SwiftUI

// MARK: - Hover "Chi tiết nguồn điện" (Activity Monitor POWER/ENERGY style)

struct PowerHoverRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: FS.body)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            Text(value).font(.system(size: FS.body, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}

struct HoverPowerDetailsView: View {
    @ObservedObject var power = PowerTelemetryManager.shared

    private var s: PowerSnapshot { power.snapshot }

    private func w(_ v: Double) -> String { String(format: "%.2f W", v) }
    private var isAS: Bool { HardwareInfo.isAppleSilicon }

    private func sectionHeader(_ t: String) -> some View {
        Text(t.uppercased()).font(.system(size: FS.caption, weight: .semibold)).foregroundStyle(.tertiary).padding(.top, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "bolt.shield.fill").foregroundStyle(.secondary)
                Text(tr("Nguồn điện chi tiết", "Power details")).font(.system(size: FS.caption, weight: .semibold))
                Spacer()
                Text(w(s.systemTotalW)).font(.system(size: FS.label, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
            Divider()
            sectionHeader("Power")
            PowerHoverRow(title: tr("Hệ thống", "System Total"), value: w(s.systemTotalW))
            if isAS && s.dcinW != 0 { PowerHoverRow(title: tr("DC In", "DC In"), value: w(s.dcinW)) }
            if s.batteryW != 0 {
                PowerHoverRow(title: s.batteryW > 0 ? tr("Pin (sạc)", "Battery (charge)") : tr("Pin (xả)", "Battery (discharge)"),
                              value: w(abs(s.batteryW)))
            }
            if isAS && s.averageW != 0 { PowerHoverRow(title: tr("TB hệ thống", "Avg System"), value: w(s.averageW)) }
            if s.voltage > 0 { PowerHoverRow(title: tr("Điện áp", "Voltage"), value: String(format: "%.2f V", s.voltage)) }
            sectionHeader("Energy")
            PowerHoverRow(title: isAS ? tr("Tiêu thụ từ khởi động", "Total since boot")
                                      : tr("Tổng tiêu thụ", "Total Consumption"),
                          value: isAS ? String(format: "%.1f Wh", s.consumedWh) : "—")
        }
        .frame(width: 232)
        .padding(12)
        .onAppear { PowerTelemetryManager.shared.setPopoverVisible(true) }
        .onDisappear { PowerTelemetryManager.shared.setPopoverVisible(false) }
    }
}
