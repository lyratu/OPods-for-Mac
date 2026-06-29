import SwiftUI

struct ControlsView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        Form {
            Section(store.controlGroupTitle("noise")) {
                if ancModes.isEmpty {
                    Text(store.text("anc.unsupported"))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(store.featureTitle("ancMode"), selection: Binding(
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

            Section(store.controlGroupTitle("sound")) {
                if store.effectiveCapabilities.hasSpatialSound {
                    Toggle(store.featureTitle("spatialSound"), isOn: Binding(
                        get: { store.snapshot.spatialSound },
                        set: { store.sendSpatialSound($0) }
                    ))
                }

                if store.effectiveCapabilities.hasSpatialAudio {
                    Picker(store.featureTitle("spatialAudio"), selection: Binding(
                        get: { store.snapshot.spatialMode },
                        set: { store.sendSpatialAudio($0) }
                    )) {
                        ForEach(SpatialAudioMode.allCases) { mode in
                            Text(mode.title(language: store.language)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Picker(store.featureTitle("eqPreset"), selection: Binding(
                    get: { store.snapshot.eqPreset.isEmpty ? firstEqName : store.snapshot.eqPreset },
                    set: { store.sendEqPreset($0) }
                )) {
                    ForEach(eqOptions) { option in
                        Text(option.name).tag(option.name)
                    }
                }
            }

            Section(store.controlGroupTitle("connection")) {
                Toggle(store.featureTitle("gameMode"), isOn: Binding(
                    get: { store.snapshot.gameMode },
                    set: { store.sendGameMode($0) }
                ))

                if store.effectiveCapabilities.hasDualDevice {
                    Toggle(store.featureTitle("dualDevice"), isOn: Binding(
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

    private var eqOptions: [EqPresetOption] {
        store.effectiveCapabilities.eqOptions
    }

    private var firstEqName: String {
        eqOptions.first?.name ?? store.defaultEqName()
    }
}
