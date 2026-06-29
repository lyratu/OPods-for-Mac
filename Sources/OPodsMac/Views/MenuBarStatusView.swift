import AppKit
import SwiftUI

struct MenuBarExtraLabel: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        Label(title, systemImage: store.snapshot.connected ? "earbuds" : "earbuds.case")
    }

    private var title: String {
        guard store.snapshot.connected else { return "OPods" }
        return "L \(batteryText(for: .left)) R \(batteryText(for: .right))"
    }

    private func batteryText(for component: PodComponent) -> String {
        guard let reading = store.snapshot.mergedBattery(for: component) else { return "--%" }
        return "\(reading.clippedLevel)%"
    }
}

struct MenuBarStatusView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            headerSection
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if store.snapshot.connected {
                Divider().padding(.horizontal, 14)

                // ── Battery Cards ──
                batterySection
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                // ── ANC Pills ──
                if !store.availableAncControlModes.isEmpty {
                    Divider().padding(.horizontal, 14)
                    ancSection
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                // ── EQ Pills ──
                if store.effectiveCapabilities.eqPresets.count > 1 {
                    Divider().padding(.horizontal, 14)
                    eqSection
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                // ── Quick Toggles ──
                if hasAnyToggles {
                    Divider().padding(.horizontal, 14)
                    featuresSection
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
            } else {
                disconnectedHint
                    .padding(.horizontal, 14)
                    .padding(.vertical, 20)
            }

            Divider().padding(.horizontal, 14)

            // ── Actions ──
            actionsSection
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .frame(width: 278)
        .onAppear {
            store.syncNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.syncNow()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: store.snapshot.connected ? "earbuds" : "earbuds.case")
                .font(.system(size: 26))
                .foregroundStyle(store.snapshot.connected ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(store.snapshot.connected ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text(store.snapshot.connected
                        ? store.text("connected")
                        : store.text("disconnected"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.syncNow()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(store.text("refreshDevices"))

            if store.snapshot.connected {
                Button {
                    store.disconnect()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.connectAutomatically()
                } label: {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var headerTitle: String {
        guard store.snapshot.connected else { return "OPods" }
        let name = store.effectiveCapabilities.modelName
        return name == "Unknown" ? store.snapshot.connectedDeviceName : name
    }

    // MARK: - Battery

    private var batterySection: some View {
        HStack(spacing: 8) {
            ForEach(PodComponent.allCases) { component in
                batteryCard(component: component)
            }
        }
    }

    private func batteryCard(component: PodComponent) -> some View {
        let reading = store.snapshot.mergedBattery(for: component)
        let level = Double(reading?.clippedLevel ?? 0) / 100.0

        return VStack(spacing: 4) {
            EarbudAssetImage(name: component.assetName)
                .frame(width: 24, height: 24)

            Text(reading.map { "\($0.clippedLevel)%" } ?? "--")
                .font(.system(size: 16, weight: .bold, design: .monospaced))

            ProgressView(value: level)
                .progressViewStyle(.linear)
                .tint(.green)

            HStack(spacing: 3) {
                Text(component.title(language: store.language))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                if reading?.charging == true {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - ANC

    private var ancSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.featureTitle("noiseControl"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            ancPillsGrid
        }
    }

    private var ancPillsGrid: some View {
        HStack(spacing: 5) {
            ForEach(store.availableAncControlModes) { mode in
                ancPill(mode: mode)
            }
        }
    }

    private func ancPill(mode: AncMode) -> some View {
        Button {
            store.sendAnc(mode)
        } label: {
            Text(mode.title(language: store.language))
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(store.snapshot.ancMode == mode
                    ? Color.accentColor
                    : Color.primary.opacity(0.08))
                .foregroundStyle(store.snapshot.ancMode == mode
                    ? .white
                    : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Features

    private var hasAnyToggles: Bool {
        store.effectiveCapabilities.hasGameMode
        || store.effectiveCapabilities.hasSpatialSound
        || store.effectiveCapabilities.hasDualDevice
    }

    private var featuresSection: some View {
        HStack(spacing: 5) {
            featureChip(
                icon: "gamecontroller",
                title: store.featureTitle("gameMode"),
                isOn: store.snapshot.gameMode,
                action: { store.sendGameMode(!store.snapshot.gameMode) }
            )

            if store.effectiveCapabilities.hasSpatialSound {
                featureChip(
                    icon: "hifispeaker",
                    title: store.featureTitle("spatialSound"),
                    isOn: store.snapshot.spatialSound,
                    action: { store.sendSpatialSound(!store.snapshot.spatialSound) }
                )
            }

            if store.effectiveCapabilities.hasDualDevice {
                featureChip(
                    icon: "rectangle.connected.to.line.below",
                    title: store.featureTitle("dualDevice"),
                    isOn: store.snapshot.dualDevice,
                    action: { store.sendDualDevice(!store.snapshot.dualDevice) }
                )
            }
        }
    }

    private func featureChip(icon: String, title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isOn ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.06))
            .foregroundStyle(isOn ? Color.accentColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disconnected

    private var disconnectedHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "earbuds.case")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text(store.text("pairHint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - EQ

    private var eqSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.featureTitle("eqPreset"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            eqPillsGrid
        }
    }

    private var eqPillsGrid: some View {
        let options = store.effectiveCapabilities.eqOptions
        let current = store.snapshot.eqPreset.isEmpty
            ? (options.first?.name ?? store.defaultEqName())
            : store.snapshot.eqPreset

        return HStack(spacing: 5) {
            ForEach(options) { option in
                Button {
                    store.sendEqPreset(option.name)
                } label: {
                    Text(option.name)
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(current == option.name
                            ? Color.accentColor
                            : Color.primary.opacity(0.08))
                        .foregroundStyle(current == option.name
                            ? .white
                            : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 1) {
            if store.effectiveCapabilities.hasSpatialAudio {
                spatialPicker
                Divider().padding(.vertical, 3)
            }

            powerSavingToggle

            Divider().padding(.vertical, 3)

            actionButton(icon: "rectangle.on.rectangle", title: store.text("showMainWindow")) {
                showMainWindow()
            }

            actionButton(icon: "xmark", title: store.text("quit")) {
                NSApp.terminate(nil)
            }
        }
    }

    private var powerSavingToggle: some View {
        Button {
            store.isPowerSaving.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.isPowerSaving ? "bolt.slash.circle.fill" : "bolt.circle")
                    .frame(width: 16)
                    .foregroundStyle(store.isPowerSaving ? .green : .secondary)
                Text("省电模式")
                    .font(.system(size: 12))
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }

    private var spatialPicker: some View {
        Picker(selection: Binding(
            get: { store.snapshot.spatialMode },
            set: { store.sendSpatialAudio($0) }
        )) {
            ForEach(SpatialAudioMode.allCases) { mode in
                Text(mode.title(language: store.language)).tag(mode)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "headphones")
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(store.featureTitle("spatialAudio"))
                    .font(.system(size: 12))
            }
        }
        .pickerStyle(.menu)
        .padding(.vertical, 1)
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        MenuActionRow(icon: icon, title: title, action: action)
    }

    // MARK: - Helpers

    private func showMainWindow() {
        store.syncNow()
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Action Row

private struct MenuActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
