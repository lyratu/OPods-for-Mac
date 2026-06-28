import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        Form {
            Section("Device Model") {
                Picker("Override", selection: Binding(
                    get: { store.selectedModelOverride ?? "" },
                    set: { store.selectedModelOverride = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Auto detect").tag("")
                    ForEach(store.filteredModelNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .searchable(text: $store.modelSearch)

                LabeledContent("Detected") {
                    Text(store.detectedCapabilities.modelName)
                }
                LabeledContent("Model ID") {
                    Text(store.effectiveCapabilities.modelId.isEmpty ? "--" : store.effectiveCapabilities.modelId)
                }
            }

            Section("Command Compatibility") {
                Toggle("Send legacy low-latency game feature too", isOn: $store.gameModeCompatible)
            }

            Section("Capabilities") {
                CapabilityRow(title: "Adaptive ANC", enabled: store.effectiveCapabilities.hasAdaptiveAnc)
                CapabilityRow(title: "Spatial sound", enabled: store.effectiveCapabilities.hasSpatialSound)
                CapabilityRow(title: "Spatial audio modes", enabled: store.effectiveCapabilities.hasSpatialAudio)
                CapabilityRow(title: "Dual-device connection", enabled: store.effectiveCapabilities.hasDualDevice)
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
