import AppKit
import SwiftUI

@main
struct OPodsMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PodsStore()

    var body: some Scene {
        WindowGroup("OPods for Mac") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 840, minHeight: 560)
        }
        .commands {
            CommandMenu("Pods") {
                Button("Connect") {
                    store.connectAutomatically()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Refresh Paired Devices") {
                    store.refreshPairedDevices()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Disconnect") {
                    store.disconnect()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarStatusView()
                .environmentObject(store)
        } label: {
            Label(store.menuBarTitle, systemImage: store.snapshot.connected ? "earbuds" : "earbuds.case")
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
