import SwiftUI

struct MenuBarStatusView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.snapshot.connected ? store.effectiveCapabilities.modelName : "OPods")
                .font(.headline)

            ForEach(PodComponent.allCases) { component in
                HStack {
                    Text(component.title)
                    Spacer()
                    Text(store.snapshot.mergedBattery(for: component).map { "\($0.clippedLevel)%" } ?? "--")
                        .monospacedDigit()
                }
            }

            Divider()

            Button(store.snapshot.connected ? "Disconnect" : "Connect") {
                store.snapshot.connected ? store.disconnect() : store.connectAutomatically()
            }

            Button("Refresh Devices") {
                store.refreshPairedDevices()
            }
        }
        .frame(width: 220)
        .padding(.vertical, 4)
    }
}
