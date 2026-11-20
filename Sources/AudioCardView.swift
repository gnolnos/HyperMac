import SwiftUI
import CoreAudio

// MARK: - Âm thanh & Loa — quản lý thiết bị xuất âm + Multi-Output group (Core Audio, kiểu AudioSwitcher)

struct AudioCardView: View {
    @ObservedObject var audio = AudioDeviceManager.shared
    @State private var groupMode = false
    @State private var chosen = Set<AudioDeviceID>()
    @State private var chosenMaster: AudioDeviceID?
    @State private var rateChoice = 0   // 0 = Tự động (theo loa chính), 1 = 44.1k, 2 = 48k

    var visibleDevices: [AudioOutputDevice] { Array(audio.devices.prefix(9)) }
    var extraCount: Int { max(0, audio.devices.count - 9) }
    var group: AudioOutputDevice? { audio.devices.first(where: { $0.isMultiOutput && $0.name.hasPrefix("HyperMac") }) }
    var pickable: [AudioOutputDevice] { audio.devices.filter { !$0.isMultiOutput } }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.3.fill").font(.system(size: FS.label)).foregroundStyle(.secondary)
                Text(tr("Âm thanh & Loa", "Audio & Speakers")).font(.system(size: FS.label, weight: .semibold))
                Spacer()
                Button { audio.scan() } label: {
                    HStack(spacing: 4) {
                        if audio.scanning {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: FS.caption))
                        }
                        Text(tr("Quét loa", "Scan")).font(.system(size: FS.caption, weight: .medium))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(audio.scanning)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(visibleDevices) { d in
                        deviceRow(d)
                    }
                    if extraCount > 0 {
                        Text(tr("+\(extraCount) thiết bị khác…", "+\(extraCount) more…")).font(.system(size: FS.caption)).foregroundStyle(.tertiary).padding(.top, 3)
                    }
                }
            }
            .frame(maxHeight: 172)

            Divider()

            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { groupMode.toggle() }
                } label: {
                    Label(groupMode ? tr("Xong", "Done") : tr("Gom loa (Multi-Output)", "Group speakers"), systemImage: "rectangle.stack.badge.plus")
                        .font(.system(size: FS.body, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                Spacer()
                if let grp = group {
                    Button(role: .destructive) { _ = audio.destroy(grp.id) } label: {
                        Label(tr("Hủy group", "Remove group"), systemImage: "xmark.circle")
                            .font(.system(size: FS.body, weight: .medium))
                    }.buttonStyle(.plain).foregroundStyle(Tone.bad)
                }
            }

            if groupMode {
                VStack(alignment: .leading, spacing: 5) {
                    Text(tr("Chọn loa để phát đồng thời (loose-sync local):", "Pick outputs to play together (loose-sync local):"))
                        .font(.system(size: FS.caption)).foregroundStyle(.secondary)
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            ForEach(pickable) { d in
                                Button {
                                    if chosen.contains(d.id) { chosen.remove(d.id) } else { chosen.insert(d.id) }
                                } label: {
                                    HStack {
                                        Image(systemName: chosen.contains(d.id) ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(chosen.contains(d.id) ? Color.accentColor : .secondary)
                                        Text(d.name).font(.system(size: FS.body)).foregroundStyle(.primary).lineLimit(1)
                                        Spacer()
                                        Text(d.transport).font(.system(size: FS.caption)).foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                    // Loa chính (master clock sync) — như AudioSwitcher
                    if chosen.count >= 1 {
                        Picker(tr("Loa chính (clock)", "Master (clock sync)"), selection: $chosenMaster) {
                            ForEach(Array(chosen), id: \.self) { id in
                                Text(nameOf(id)).tag(Optional(id))
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: FS.caption))
                    }
                    // Sample rate chung — như AudioSwitcher (tránh lệch giữa 2 thiết bị)
                    Picker(tr("Sample rate", "Sample rate"), selection: $rateChoice) {
                        Text(tr("Tự động (theo loa chính)", "Auto (follow master)")).tag(0)
                        Text("44,1 kHz").tag(1)
                        Text("48 kHz").tag(2)
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: FS.caption))
                    if let err = audio.lastError {
                        Text(err).font(.system(size: FS.caption)).foregroundStyle(Tone.bad)
                    }
                    Button {
                        let rate: Double = rateChoice == 1 ? 44100 : (rateChoice == 2 ? 48000 : 0)
                        _ = audio.toggleGroup(memberIDs: Array(chosen), masterID: chosenMaster, sampleRate: rate)
                        groupMode = false; chosen.removeAll(); chosenMaster = nil
                    } label: {
                        Text(tr("Tạo Multi-Output", "Create Multi-Output"))
                            .font(.system(size: FS.body, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chosen.count < 2)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Rad.md).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: Rad.md).strokeBorder(Color.primary.opacity(0.06)))
    }

    private func nameOf(_ id: AudioDeviceID) -> String {
        audio.devices.first(where: { $0.id == id })?.name ?? "\(id)"
    }

    private func transportIcon(_ t: String) -> String? {
        switch t {
        case "AirPlay": return "airplayaudio"
        case "Bluetooth": return "hksign.bluetooth.topology.center"
        case "HDMI": return "rectangle.inset.filled"
        case "DisplayPort": return "display"
        case "USB": return "cable.connector"
        case "Built-in": return "laptopcomputer"
        case "Multi-Output": return "square.stack.3d.forward.dottedline"
        default: return nil
        }
    }

    private func deviceRow(_ d: AudioOutputDevice) -> some View {
        Button {
            if !d.isMultiOutput { _ = audio.setDefault(d.id) }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: d.isDefault ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .font(.system(size: FS.caption))
                    .foregroundStyle(d.isDefault ? Color.accentColor : .secondary)
                if let ico = transportIcon(d.transport) {
                    Image(systemName: ico).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 13)
                }
                Text(d.name).font(.system(size: FS.body)).lineLimit(1).foregroundStyle(.primary)
                Spacer(minLength: 4)
                if !d.isAlive { Text("off").font(.system(size: FS.caption)).foregroundStyle(Tone.bad) }
                Text(d.transport).font(.system(size: FS.caption)).foregroundStyle(.tertiary)
                if d.isDefault {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: FS.caption)).foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(d.isMultiOutput)
    }
}
