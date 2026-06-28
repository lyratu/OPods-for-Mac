import SwiftUI

struct ControlsView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        Form {
            Section("Noise Control") {
                Picker("ANC mode", selection: Binding(
                    get: { store.snapshot.ancMode },
                    set: { store.sendAnc($0) }
                )) {
                    Text("Off").tag(AncMode.off)
                    Text("Smart").tag(AncMode.smart)
                    Text("Light").tag(AncMode.light)
                    Text("Medium").tag(AncMode.medium)
                    Text("Deep").tag(AncMode.deep)
                    if store.effectiveCapabilities.hasAdaptiveAnc {
                        Text("Adaptive").tag(AncMode.adaptive)
                    }
                    Text("Transparency").tag(AncMode.transparency)
                }
                .pickerStyle(.segmented)
            }

            Section("Sound") {
                Toggle("Spatial sound", isOn: Binding(
                    get: { store.snapshot.spatialSound },
                    set: { store.sendSpatialSound($0) }
                ))
                .disabled(!store.effectiveCapabilities.hasSpatialSound)

                Picker("Spatial audio", selection: Binding(
                    get: { store.snapshot.spatialMode },
                    set: { store.sendSpatialAudio($0) }
                )) {
                    Text("Off").tag(SpatialAudioMode.off)
                    Text("Fixed").tag(SpatialAudioMode.fixed)
                    Text("Head Tracking").tag(SpatialAudioMode.tracking)
                }
                .pickerStyle(.segmented)
                .disabled(!store.effectiveCapabilities.hasSpatialAudio)

                Picker("EQ preset", selection: Binding(
                    get: { store.snapshot.eqPreset.isEmpty ? firstEqName : store.snapshot.eqPreset },
                    set: { store.sendEqPreset($0) }
                )) {
                    ForEach(eqNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }

            Section("Connection") {
                Toggle("Game mode", isOn: Binding(
                    get: { store.snapshot.gameMode },
                    set: { store.sendGameMode($0) }
                ))

                Toggle("Dual-device connection", isOn: Binding(
                    get: { store.snapshot.dualDevice },
                    set: { store.sendDualDevice($0) }
                ))
                .disabled(!store.effectiveCapabilities.hasDualDevice)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var eqNames: [String] {
        store.effectiveCapabilities.eqPresets.keys.sorted()
    }

    private var firstEqName: String {
        eqNames.first ?? "Default"
    }
}
