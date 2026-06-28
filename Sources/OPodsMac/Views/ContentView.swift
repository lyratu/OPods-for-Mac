import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PodsStore
    @State private var selection: AppSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
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
                switch selection ?? .overview {
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
            .navigationTitle((selection ?? .overview).title)
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        store.refreshPairedDevices()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh paired Bluetooth devices")

                    if store.snapshot.connected {
                        Button {
                            store.disconnect()
                        } label: {
                            Label("Disconnect", systemImage: "bolt.horizontal.circle")
                        }
                        .help("Disconnect earbuds")
                    } else {
                        Button {
                            store.connectAutomatically()
                        } label: {
                            Label("Connect", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .help("Connect to a supported paired device")
                    }
                }
            }
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
                Text(store.phase.title)
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
