import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PodsStore
    @SceneStorage("selectedAppSection") private var selectionRawValue = AppSection.overview.rawValue

    private var selectedSection: AppSection {
        AppSection(rawValue: selectionRawValue) ?? .overview
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectionRawValue) { section in
                Label(section.title(language: store.language), systemImage: section.systemImage)
                    .tag(section.rawValue)
            }
            .listStyle(.sidebar)
            .navigationTitle("OPods")
            .safeAreaInset(edge: .bottom) {
                SidebarStatusView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
        } detail: {
            Group {
                switch selectedSection {
                case .overview:
                    OverviewView()
                case .controls:
                    ControlsView()
                case .devices:
                    DevicesView()
                case .settings:
                    SettingsView()
                case .about:
                    AboutView()
                }
            }
            .navigationTitle(selectedSection.title(language: store.language))
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        store.refreshPairedDevices()
                    } label: {
                        Label(store.text("refresh"), systemImage: "arrow.clockwise")
                    }
                    .help("Refresh paired Bluetooth devices")

                    if store.snapshot.connected {
                        Button {
                            store.disconnect()
                        } label: {
                            Label(store.text("disconnect"), systemImage: "bolt.horizontal.circle")
                        }
                        .help("Disconnect earbuds")
                    } else {
                        Button {
                            store.connectAutomatically()
                        } label: {
                            Label(store.text("connect"), systemImage: "dot.radiowaves.left.and.right")
                        }
                        .help("Connect to a supported paired device")
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        .onAppear {
            store.syncNow()
        }
    }
}

struct SidebarStatusView: View {
    @EnvironmentObject private var store: PodsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(store.phase.title(language: store.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        switch store.phase {
        case .connected: .green
        case .connecting: .orange
        case .failed: .red
        case .disconnected: .secondary
        }
    }
}
