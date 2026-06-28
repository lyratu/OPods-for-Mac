import AppKit
import SwiftUI

@main
struct OPodsMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = PodsStore()

    var body: some Scene {
        Window("OPods for Mac", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 840, minHeight: 560)
        }
        .commands {
            CommandMenu("Pods") {
                Button(store.text("connect")) {
                    store.connectAutomatically()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button(store.text("refreshDevices")) {
                    store.refreshPairedDevices()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button(store.text("disconnect")) {
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
        .menuBarExtraStyle(.window)
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
