import SwiftUI

struct ControlsView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        Form {
            Section(store.text("noiseControl")) {
                if ancModes.isEmpty {
                    Text(store.text("anc.unsupported"))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(store.text("anc.mode"), selection: Binding(
                        get: {
                            ancModes.contains(store.snapshot.ancMode)
                                ? store.snapshot.ancMode
                                : (ancModes.first ?? .unknown)
                        },
                        set: { store.sendAnc($0) }
                    )) {
                        ForEach(ancModes) { mode in
                            Text(mode.title(language: store.language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section(store.text("sound")) {
                if store.effectiveCapabilities.hasSpatialSound {
                    Toggle(store.text("spatialSound"), isOn: Binding(
                        get: { store.snapshot.spatialSound },
                        set: { store.sendSpatialSound($0) }
                    ))
                }

                if store.effectiveCapabilities.hasSpatialAudio {
                    Picker(store.text("spatialAudio"), selection: Binding(
                        get: { store.snapshot.spatialMode },
                        set: { store.sendSpatialAudio($0) }
                    )) {
                        ForEach(SpatialAudioMode.allCases) { mode in
                            Text(mode.title(language: store.language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Picker(store.text("eqPreset"), selection: Binding(
                    get: { store.snapshot.eqPreset.isEmpty ? firstEqName : store.snapshot.eqPreset },
                    set: { store.sendEqPreset($0) }
                )) {
                    ForEach(eqNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
            }

            Section(store.text("connection")) {
                Toggle(store.text("gameMode"), isOn: Binding(
                    get: { store.snapshot.gameMode },
                    set: { store.sendGameMode($0) }
                ))

                if store.effectiveCapabilities.hasDualDevice {
                    Toggle(store.text("dualDevice"), isOn: Binding(
                        get: { store.snapshot.dualDevice },
                        set: { store.sendDualDevice($0) }
                    ))
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var ancModes: [AncMode] {
        store.availableAncControlModes
    }

    private var eqNames: [String] {
        store.effectiveCapabilities.eqPresets.keys.sorted()
    }

    private var firstEqName: String {
        eqNames.first ?? "Default"
    }
}
