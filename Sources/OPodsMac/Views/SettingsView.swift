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
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
