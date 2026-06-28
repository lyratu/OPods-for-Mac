import AppKit
import SwiftUI

struct MenuBarStatusView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(headerTitle, systemImage: store.snapshot.connected ? "earbuds" : "earbuds.case")
                .font(.headline)

            Text(store.snapshot.connected ? store.text("connected") : store.text("disconnected"))
                .font(.caption)
                .foregroundStyle(store.snapshot.connected ? .green : .secondary)

            batteryRows

            if store.snapshot.connected {
                Divider()
                ancMenuSection
                featureMenuSection
            }

            Divider()

            Button(store.snapshot.connected ? store.text("disconnect") : store.text("connect")) {
                store.snapshot.connected ? store.disconnect() : store.connectAutomatically()
            }

            Button(store.text("refreshDevices")) {
                store.refreshPairedDevices()
            }

            Button(store.text("showMainWindow")) {
                showMainWindow()
            }

            Button(store.text("quit")) {
                NSApp.terminate(nil)
            }
        }
        .frame(width: 240)
        .padding(.vertical, 4)
    }

    private var headerTitle: String {
        guard store.snapshot.connected else { return "OPods" }
        let modelName = store.effectiveCapabilities.modelName
        return modelName == "Unknown" ? store.snapshot.connectedDeviceName : modelName
    }

    private var batteryRows: some View {
        ForEach(PodComponent.allCases) { component in
            HStack {
                Text(component.title(language: store.language))
                Spacer()
                Text(store.snapshot.mergedBattery(for: component).map { "\($0.clippedLevel)%" } ?? "--")
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var ancMenuSection: some View {
        if store.availableAncControlModes.isEmpty {
            EmptyView()
        } else {
            Text(store.text("noiseControl"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(store.availableAncControlModes) { mode in
                Button {
                    store.sendAnc(mode)
                } label: {
                    Label(mode.title(language: store.language), systemImage: store.snapshot.ancMode == mode ? "checkmark.circle.fill" : "circle")
                }
            }
        }
    }

    @ViewBuilder
    private var featureMenuSection: some View {
        Divider()

        Button {
            store.sendGameMode(!store.snapshot.gameMode)
        } label: {
            Label(store.text("gameMode"), systemImage: store.snapshot.gameMode ? "checkmark.circle.fill" : "circle")
        }

        if store.effectiveCapabilities.hasSpatialSound {
            Button {
                store.sendSpatialSound(!store.snapshot.spatialSound)
            } label: {
                Label(store.text("spatialSound"), systemImage: store.snapshot.spatialSound ? "checkmark.circle.fill" : "circle")
            }
        }

        if store.effectiveCapabilities.hasSpatialAudio {
            Menu(store.text("spatialAudio")) {
                ForEach(SpatialAudioMode.allCases) { mode in
                    Button {
                        store.sendSpatialAudio(mode)
                    } label: {
                        Label(mode.title(language: store.language), systemImage: store.snapshot.spatialMode == mode ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
        }

        if store.effectiveCapabilities.hasDualDevice {
            Button {
                store.sendDualDevice(!store.snapshot.dualDevice)
            } label: {
                Label(store.text("dualDevice"), systemImage: store.snapshot.dualDevice ? "checkmark.circle.fill" : "circle")
            }

            Button {
                store.refreshMultiConnectInfo()
            } label: {
                Label(store.text("dualDeviceList"), systemImage: "rectangle.connected.to.line.below")
            }
        }

        if store.effectiveCapabilities.eqPresets.count > 1 {
            Menu(store.text("eqPreset")) {
                ForEach(store.effectiveCapabilities.eqPresets.keys.sorted(), id: \.self) { name in
                    Button {
                        store.sendEqPreset(name)
                    } label: {
                        Label(shortMenuTitle(name), systemImage: store.snapshot.eqPreset == name ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
        }
    }

    private func shortMenuTitle(_ value: String) -> String {
        if value.count <= 30 { return value }
        return String(value.prefix(29)) + "..."
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title == "OPods for Mac" }?.makeKeyAndOrderFront(nil)
    }
}
