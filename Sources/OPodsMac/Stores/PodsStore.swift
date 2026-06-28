import Foundation

enum ConnectionPhase: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var title: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .failed: "Needs attention"
        }
    }
}

@MainActor
final class PodsStore: ObservableObject {
    @Published private(set) var snapshot = PodSnapshot()
    @Published private(set) var detectedCapabilities = DeviceCapabilities.fallback
    @Published private(set) var pairedDevices: [BluetoothDeviceCandidate] = []
    @Published private(set) var phase: ConnectionPhase = .disconnected
    @Published var statusMessage = "Pair OPPO, OnePlus, or realme earbuds in macOS Bluetooth settings, then connect."
    @Published var modelSearch = ""
    @Published var selectedModelOverride: String? {
        didSet {
            if selectedModelOverride == oldValue { return }
            UserDefaults.standard.set(selectedModelOverride, forKey: Self.modelOverrideKey)
        }
    }
    @Published var gameModeCompatible: Bool {
        didSet {
            UserDefaults.standard.set(gameModeCompatible, forKey: Self.gameModeCompatibleKey)
        }
    }

    private static let modelOverrideKey = "modelOverride"
    private static let gameModeCompatibleKey = "gameModeCompatible"

    private let service = RfcommService()

    init() {
        selectedModelOverride = UserDefaults.standard.string(forKey: Self.modelOverrideKey)
        gameModeCompatible = UserDefaults.standard.bool(forKey: Self.gameModeCompatibleKey)
        service.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        refreshPairedDevices()
    }

    var effectiveCapabilities: DeviceCapabilities {
        if let selectedModelOverride, !selectedModelOverride.isEmpty {
            return DeviceCapabilities.ForceModel(selectedModelOverride)
        }
        return detectedCapabilities
    }

    var modelNames: [String] {
        DeviceCapabilities.GetModelNames()
    }

    var filteredModelNames: [String] {
        guard !modelSearch.isEmpty else { return modelNames }
        return modelNames.filter { $0.localizedCaseInsensitiveContains(modelSearch) }
    }

    var menuBarTitle: String {
        guard snapshot.connected else { return "OPods" }
        let parts = [PodComponent.left, .right, .case].compactMap { component -> String? in
            guard let reading = snapshot.mergedBattery(for: component) else { return nil }
            return "\(component.rawValue)\(reading.clippedLevel)"
        }
        return parts.isEmpty ? "OPods" : parts.joined(separator: " ")
    }

    func refreshPairedDevices() {
        pairedDevices = service.pairedDevices()
    }

    func connectAutomatically() {
        connect(to: nil)
    }

    func connect(to device: BluetoothDeviceCandidate?) {
        phase = .connecting
        statusMessage = device.map { "Connecting to \($0.name)..." } ?? "Searching for a supported paired device..."

        Task {
            do {
                try await service.connect(to: device)
            } catch {
                phase = .failed(error.localizedDescription)
                statusMessage = error.localizedDescription
            }
        }
    }

    func disconnect() {
        service.disconnect()
    }

    func sendAnc(_ mode: AncMode) {
        snapshot.ancMode = mode
        service.sendAnc(mode)
    }

    func sendSpatialSound(_ enabled: Bool) {
        snapshot.spatialSound = enabled
        service.sendSpatialSound(enabled)
    }

    func sendSpatialAudio(_ mode: SpatialAudioMode) {
        snapshot.spatialMode = mode
        service.sendSpatialAudio(mode)
    }

    func sendDualDevice(_ enabled: Bool) {
        snapshot.dualDevice = enabled
        service.sendDualDevice(enabled)
    }

    func sendGameMode(_ enabled: Bool) {
        snapshot.gameMode = enabled
        service.sendGameMode(enabled, compatible: gameModeCompatible)
    }

    func sendEqPreset(_ name: String) {
        snapshot.eqPreset = name
        service.sendEqPreset(name, capabilities: effectiveCapabilities)
    }

    func refreshMultiConnectInfo() {
        service.refreshMultiConnectInfo()
    }

    func operateHandheld(address: String, connect: Bool) {
        service.operateHandheld(address: address, connect: connect)
    }

    private func handle(_ event: PodsServiceEvent) {
        switch event {
        case .connected(let deviceName, let capabilities, let snapshot):
            self.snapshot = snapshot
            detectedCapabilities = capabilities
            phase = .connected
            statusMessage = "Connected to \(capabilities.modelName == "Unknown" ? deviceName : capabilities.modelName)."
        case .snapshot(let snapshot):
            self.snapshot = snapshot
            phase = snapshot.connected ? .connected : .disconnected
        case .disconnected(let reason):
            snapshot.connected = false
            phase = .disconnected
            statusMessage = reason ?? "Disconnected."
        case .error(let message):
            phase = .failed(message)
            statusMessage = message
        }
    }
}
