import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        Form {
            Section(store.text("language")) {
                Picker(store.text("language"), selection: $store.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(store.text("deviceModel")) {
                Picker(store.text("override"), selection: Binding(
                    get: { store.selectedModelOverride ?? "" },
                    set: { store.selectedModelOverride = $0.isEmpty ? nil : $0 }
                )) {
                    Text(store.text("autoDetect")).tag("")
                    ForEach(store.filteredModelNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .searchable(text: $store.modelSearch)

                LabeledContent(store.text("detected")) {
                    Text(store.detectedCapabilities.modelName)
                }
                LabeledContent(store.text("modelId")) {
                    Text(store.effectiveCapabilities.modelId.isEmpty ? "--" : store.effectiveCapabilities.modelId)
                }
            }

            Section(store.text("commandCompatibility")) {
                Toggle(store.text("legacyGameFeature"), isOn: $store.gameModeCompatible)
            }

            Section(store.text("capabilities")) {
                CapabilityRow(title: store.text("noiseControl"), enabled: !store.effectiveCapabilities.availableAncMainModes.isEmpty)
                CapabilityRow(title: store.text("anc.level"), enabled: store.effectiveCapabilities.hasAncSubModes)
                CapabilityRow(title: store.text("adaptiveAnc"), enabled: store.effectiveCapabilities.hasAdaptiveAnc)
                CapabilityRow(title: store.text("spatialSound"), enabled: store.effectiveCapabilities.hasSpatialSound)
                CapabilityRow(title: store.text("spatialAudioModes"), enabled: store.effectiveCapabilities.hasSpatialAudio)
                CapabilityRow(title: store.text("dualDevice"), enabled: store.effectiveCapabilities.hasDualDevice)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct CapabilityRow: View {
    var title: String
    var enabled: Bool

    var body: some View {
        LabeledContent(title) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(enabled ? .green : .secondary)
        }
    }
}
