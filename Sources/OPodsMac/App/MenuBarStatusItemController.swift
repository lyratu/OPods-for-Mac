import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarStatusItemController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private weak var store: PodsStore?
    private weak var statusButton: NSStatusBarButton?
    private var popover: NSPopover?
    private var hostingController: NSHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()
    private let popoverWidth: CGFloat = 278

    func configure(store: PodsStore) {
        if self.store === store {
            refreshStatusLabel()
            return
        }

        self.store = store
        installStatusItemIfNeeded()
        configurePopover(with: store)
        observeStore(store)
        refreshStatusLabel()
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }

        button.cell = CenteredStatusButtonCell(textCell: "")
        button.title = ""
        button.imagePosition = .imageLeft
        button.alignment = .left
        button.setButtonType(.momentaryPushIn)
        button.target = self
        button.action = #selector(statusButtonClicked(_:))

        if let cell = button.cell as? NSButtonCell {
            cell.imageDimsWhenDisabled = false
            cell.usesSingleLineMode = false
            cell.lineBreakMode = .byClipping
        }

        statusItem = item
        statusButton = button
    }

    private func configurePopover(with store: PodsStore) {
        let contentSize = popoverContentSize(for: store)
        let rootView = popoverRootView(for: store, size: contentSize)
        let controller = NSHostingController(
            rootView: rootView
        )
        controller.preferredContentSize = contentSize

        let nextPopover = NSPopover()
        nextPopover.behavior = .transient
        nextPopover.contentSize = contentSize
        nextPopover.contentViewController = controller

        popover = nextPopover
        hostingController = controller
    }

    private func popoverRootView(for store: PodsStore, size: NSSize) -> AnyView {
        AnyView(
            MenuBarStatusView()
                .environmentObject(store)
                .frame(width: size.width, height: size.height, alignment: .top)
        )
    }

    private func popoverContentSize(for store: PodsStore) -> NSSize {
        NSSize(width: popoverWidth, height: popoverContentHeight(for: store))
    }

    private func popoverContentHeight(for store: PodsStore) -> CGFloat {
        guard store.snapshot.connected else { return 232 }

        var height: CGFloat = 58
        height += 1 + 104

        if !store.availableAncControlModes.isEmpty {
            height += 1 + 64
        }

        if store.effectiveCapabilities.eqPresets.count > 1 {
            height += 1 + 64
        }

        if hasAnyToggles(in: store) {
            height += 1 + 42
        }

        height += 1 + actionsContentHeight(for: store)
        return ceil(height)
    }

    private func actionsContentHeight(for store: PodsStore) -> CGFloat {
        var height: CGFloat = 94
        if store.effectiveCapabilities.hasSpatialAudio {
            height += 34
        }
        return height
    }

    private func hasAnyToggles(in store: PodsStore) -> Bool {
        store.effectiveCapabilities.hasGameMode
        || store.effectiveCapabilities.hasSpatialSound
        || store.effectiveCapabilities.hasDualDevice
    }

    private func refreshPopoverSize() {
        guard let store, let popover, let hostingController else { return }

        let contentSize = popoverContentSize(for: store)
        hostingController.rootView = popoverRootView(for: store, size: contentSize)
        hostingController.preferredContentSize = contentSize
        popover.contentSize = contentSize
    }

    private func observeStore(_ store: PodsStore) {
        cancellables.removeAll()
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshStatusLabel()
                    self?.refreshPopoverSize()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshStatusLabel() {
        guard let store, let statusButton, let statusItem else { return }

        statusButton.image = statusImage(named: store.snapshot.connected ? "earbuds" : "earbuds.case")
        statusButton.title = statusTitle(for: store)
        statusButton.font = statusFont(for: store)
        statusItem.length = store.snapshot.connected ? 82 : 74
    }

    private func batteryText(for component: PodComponent, in store: PodsStore) -> String {
        guard let reading = store.snapshot.mergedBattery(for: component) else { return "--%" }
        return "\(reading.clippedLevel)%"
    }

    private func statusImage(named name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        let configured = image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        )
        configured?.isTemplate = true
        return configured ?? image
    }

    private func statusTitle(for store: PodsStore) -> String {
        if store.snapshot.connected {
            return "Ⓛ \(batteryText(for: .left, in: store))\nⓇ \(batteryText(for: .right, in: store))"
        }

        return "OPods"
    }

    private func statusFont(for store: PodsStore) -> NSFont {
        store.snapshot.connected
            ? NSFont.monospacedDigitSystemFont(ofSize: 8.3, weight: .semibold)
            : NSFont.systemFont(ofSize: 11, weight: .medium)
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        togglePopover()
    }

    private func togglePopover() {
        guard let popover, let statusButton else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        store?.syncNow()
        popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
    }
}

private final class CenteredStatusButtonCell: NSButtonCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        guard drawsMultilineTitle else { return titleRect }

        let centeredHeight: CGFloat = 20
        titleRect.size.height = centeredHeight
        titleRect.origin.y = max(0, floor((rect.height - centeredHeight) / 2) - 2)
        return titleRect
    }

    override func imageRect(forBounds rect: NSRect) -> NSRect {
        var imageRect = super.imageRect(forBounds: rect)
        guard drawsMultilineTitle else { return imageRect }

        imageRect.origin.y = floor((rect.height - imageRect.height) / 2)
        return imageRect
    }

    private var drawsMultilineTitle: Bool {
        title.contains("\n") || attributedTitle.string.contains("\n")
    }
}
