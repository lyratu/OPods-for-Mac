import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                connectionHeader
                BatteryOverview()
                WearingOverview()
                CapabilitiesOverview()
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var connectionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: store.snapshot.connected ? "earbuds" : "earbuds.case")
                    .font(.system(size: 32))
                    .foregroundStyle(store.snapshot.connected ? .green : .secondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(deviceTitle)
                        .font(.title2.weight(.semibold))
                    Text(store.statusMessage)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.snapshot.connected ? store.disconnect() : store.connectAutomatically()
                } label: {
                            Label(store.snapshot.connected ? store.text("disconnect") : store.text("connect"), systemImage: store.snapshot.connected ? "xmark.circle" : "link")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var deviceTitle: String {
        if store.snapshot.connected {
            let caps = store.effectiveCapabilities
            return caps.modelName == "Unknown" ? store.snapshot.connectedDeviceName : caps.modelName
        }
        return "OPPO / OnePlus / realme earbuds"
    }
}

struct BatteryOverview: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.text("battery"))
                .font(.headline)

            HStack(spacing: 14) {
                ForEach(PodComponent.allCases) { component in
                    BatteryTile(component: component, reading: store.snapshot.mergedBattery(for: component))
                }
            }
        }
    }
}

struct BatteryTile: View {
    @EnvironmentObject private var store: PodsStore

    var component: PodComponent
    var reading: BatteryReading?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                EarbudAssetImage(name: component.assetName)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.title(language: store.language))
                        .font(.headline)
                    Text(reading?.charging == true ? store.text("charging") : store.text("ready"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(reading?.clippedLevel ?? 0), total: 100)
                .progressViewStyle(.linear)

            Text(reading.map { "\($0.clippedLevel)%" } ?? "--")
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding(14)
        .frame(width: 180, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct WearingOverview: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.text("wearDetection"))
                .font(.headline)

            HStack(spacing: 12) {
                ForEach([PodComponent.left, .right]) { component in
                    Label {
                        Text(store.snapshot.wearing[component]?.title(language: store.language) ?? store.text("noReport"))
                    } icon: {
                        Image(systemName: component == .left ? "l.circle" : "r.circle")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct EarbudAssetImage: View {
    var name: String

    var body: some View {
        Group {
            if let image = Bundle.module.opodsImage(named: name) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "earbuds")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHidden(true)
    }
}

struct CapabilitiesOverview: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.text("capabilities"))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(store.capabilityDisplayItems) { item in
                    CapabilityBadge(title: item.title, enabled: item.enabled)
                }
            }
        }
    }
}

private struct CapabilityBadge: View {
    var title: String
    var enabled: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(enabled ? .green : .secondary)
                .font(.system(size: 12))
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(enabled ? .primary : .secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
