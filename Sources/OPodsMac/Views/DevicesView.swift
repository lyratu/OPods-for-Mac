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
                        Image(systemName: device.likelySupported ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(device.likelySupported ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text(device.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(store.text("connect")) {
                            store.connect(to: device)
                        }
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
