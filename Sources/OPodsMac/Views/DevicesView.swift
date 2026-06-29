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
                    let state = store.connectionState(for: device)
                    HStack {
                        Image(systemName: deviceIconName(for: state))
                            .foregroundStyle(deviceIconColor(for: state))
                            .frame(width: 18)
                        VStack(alignment: .leading) {
                            Text(device.name)
                            HStack(spacing: 8) {
                                Text(device.address)
                                    .foregroundStyle(.secondary)
                                Label(state.title(language: store.language), systemImage: statusIconName(for: state))
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(statusColor(for: state))
                            }
                            .font(.caption)
                        }
                        Spacer()
                        pairedDeviceAction(for: device, state: state)
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
    private func pairedDeviceAction(for device: BluetoothDeviceCandidate, state: PairedDeviceConnectionState) -> some View {
        switch state {
        case .controlled:
            Button(store.text("disconnect")) {
                store.disconnect()
            }
            .controlSize(.small)
        case .connecting:
            Label(store.text("connecting"), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .systemConnected:
            Button(store.text("takeControl")) {
                store.connect(to: device, automatic: true)
            }
            .controlSize(.small)
        case .paired:
            Button(store.text("connect")) {
                store.connect(to: device)
            }
            .controlSize(.small)
        case .unsupported:
            Label(store.text("unsupportedDevice"), systemImage: "minus.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func deviceIconName(for state: PairedDeviceConnectionState) -> String {
        switch state {
        case .controlled: "checkmark.circle.fill"
        case .connecting: "clock"
        case .systemConnected: "link.circle.fill"
        case .paired: "circle"
        case .unsupported: "minus.circle"
        }
    }

    private func deviceIconColor(for state: PairedDeviceConnectionState) -> Color {
        switch state {
        case .controlled, .systemConnected: .green
        case .connecting: .orange
        case .paired: .secondary
        case .unsupported: Color.secondary.opacity(0.55)
        }
    }

    private func statusIconName(for state: PairedDeviceConnectionState) -> String {
        switch state {
        case .controlled: "checkmark.circle.fill"
        case .connecting: "clock"
        case .systemConnected: "link"
        case .paired: "checkmark"
        case .unsupported: "minus.circle"
        }
    }

    private func statusColor(for state: PairedDeviceConnectionState) -> Color {
        switch state {
        case .controlled, .systemConnected: .green
        case .connecting: .orange
        case .paired, .unsupported: .secondary
        }
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
