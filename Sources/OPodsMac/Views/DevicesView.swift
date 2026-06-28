import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Paired Bluetooth Devices")
                        .font(.headline)
                    Spacer()
                    Button {
                        store.refreshPairedDevices()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                List(store.pairedDevices) { device in
                    HStack {
                        Image(systemName: device.likelySupported ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(device.likelySupported ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Connect") {
                            store.connect(to: device)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .overlay {
                    if store.pairedDevices.isEmpty {
                        EmptyStateView(title: "No Paired Devices", systemImage: "dot.radiowaves.left.and.right")
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dual-device List")
                        .font(.headline)
                    Spacer()
                    Button {
                        store.refreshMultiConnectInfo()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!store.snapshot.connected)
                }

                List(store.snapshot.connectedDevices) { device in
                    HStack(spacing: 10) {
                        Image(systemName: device.isCurrentDevice ? "speaker.wave.2.circle.fill" : "display")
                            .foregroundStyle(device.isCurrentDevice ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading) {
                            Text(device.deviceName)
                            Text(device.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !device.isCurrentDevice {
                            Button("Switch") {
                                store.operateHandheld(address: device.address, connect: true)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .overlay {
                    if store.snapshot.connectedDevices.isEmpty {
                        EmptyStateView(title: "No Device List", systemImage: "rectangle.connected.to.line.below")
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 360)
        }
    }
}

struct EmptyStateView: View {
    var title: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text("Use macOS Bluetooth settings to pair earbuds first.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
