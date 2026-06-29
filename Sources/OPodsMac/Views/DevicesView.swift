import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.text("pairedBluetoothDevices"))
                        .font(.headline)
                    Spacer()
                    Button {
                        store.refreshPairedDevices()
                    } label: {
                        Label(store.text("refresh"), systemImage: "arrow.clockwise")
                    }
                }

                List(store.pairedDevices) { device in
                    HStack {
                        Image(systemName: deviceIconName(for: device))
                            .foregroundStyle(deviceIconColor(for: device))
                            .frame(width: 18)
                        VStack(alignment: .leading) {
                            Text(device.name)
                            HStack(spacing: 8) {
                                Text(device.address)
                                    .foregroundStyle(.secondary)
                                if device.isSystemConnected {
                                    Label(device.connectionStatusTitle(language: store.language), systemImage: "link")
                                        .labelStyle(.titleAndIcon)
                                        .foregroundStyle(.green)
                                }
                            }
                            .font(.caption)
                        }
                        Spacer()
                        pairedDeviceAction(for: device)
                    }
                    .padding(.vertical, 4)
                }
                .overlay {
                    if store.pairedDevices.isEmpty {
                        EmptyStateView(title: store.text("noPairedDevices"), systemImage: "dot.radiowaves.left.and.right")
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 250, maxWidth: .infinity)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(store.text("dualDeviceList"))
                        .font(.headline)
                    Spacer()
                    Button {
                        store.refreshMultiConnectInfo()
                    } label: {
                        Label(store.text("refresh"), systemImage: "arrow.clockwise")
                    }
                    .disabled(!store.snapshot.connected)
                }

                List(store.snapshot.connectedDevices) { device in
                    HStack(spacing: 10) {
                        Image(systemName: device.isCurrentDevice ? "speaker.wave.2.circle.fill" : "display")
                            .foregroundStyle(device.isCurrentDevice ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading) {
                            Text(device.deviceName)
                            Text(device.statusText(language: store.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !device.isCurrentDevice {
                            Button(store.text("switchDevice")) {
                                store.operateHandheld(address: device.address, connect: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .overlay {
                    if store.snapshot.connectedDevices.isEmpty {
                        EmptyStateView(title: store.text("noDeviceList"), systemImage: "rectangle.connected.to.line.below")
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 250, maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func pairedDeviceAction(for device: BluetoothDeviceCandidate) -> some View {
        if store.isCurrentConnectedDevice(device) {
            Button(store.text("disconnect")) {
                store.disconnect()
            }
            .controlSize(.small)
        } else if store.isConnecting(to: device) {
            Label(store.text("connecting"), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if device.likelySupported && device.isSystemConnected {
            Label(store.text("connected"), systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Button(store.text("connect")) {
                store.connect(to: device)
            }
            .controlSize(.small)
        }
    }

    private func deviceIconName(for device: BluetoothDeviceCandidate) -> String {
        if store.isCurrentConnectedDevice(device) {
            return "checkmark.circle.fill"
        }
        if device.isSystemConnected {
            return "link.circle.fill"
        }
        return device.likelySupported ? "circle" : "minus.circle"
    }

    private func deviceIconColor(for device: BluetoothDeviceCandidate) -> Color {
        if store.isCurrentConnectedDevice(device) || device.isSystemConnected {
            return .green
        }
        return device.likelySupported ? .secondary : Color.secondary.opacity(0.55)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject private var store: PodsStore

    var title: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(store.text("pairHint"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
