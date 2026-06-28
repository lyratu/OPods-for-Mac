import Foundation

enum ConnectionPhase: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    func title(language: AppLanguage) -> String {
        switch self {
        case .disconnected: AppStrings.text("phase.disconnected", language: language)
        case .connecting: AppStrings.text("phase.connecting", language: language)
        case .connected: AppStrings.text("phase.connected", language: language)
        case .failed: AppStrings.text("phase.failed", language: language)
        }
    }
}

@MainActor
final class PodsStore: ObservableObject {
    @Published private(set) var snapshot = PodSnapshot()
    @Published private(set) var detectedCapabilities = DeviceCapabilities.fallback
    @Published private(set) var pairedDevices: [BluetoothDeviceCandidate] = []
    @Published private(set) var phase: ConnectionPhase = .disconnected
    @Published var statusMessage: String
    @Published var modelSearch = ""
    @Published var language: AppLanguage {
        didSet {
            if language == oldValue { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
            refreshLocalizedStatusMessage()
        }
    }
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
    private static let languageKey = "appLanguage"

    private let service = RfcommService()
    private var statusMessageKey = "status.initial"
    private var statusMessageArgument: String?
    private var gameModeUserSetAt = Date.distantPast
    private var ancUserSetAt = Date.distantPast
    private var spatialSoundUserSetAt = Date.distantPast
    private var dualDeviceUserSetAt = Date.distantPast
    private var eqPresetUserSetAt = Date.distantPast

    init() {
        let initialLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: Self.languageKey) ?? "") ?? .english
        language = initialLanguage
        statusMessage = AppStrings.text("status.initial", language: initialLanguage)
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

    var availableAncControlModes: [AncMode] {
        let caps = effectiveCapabilities
        guard !caps.availableAncMainModes.isEmpty else { return [] }

        if caps.availableAncSubModes.isEmpty {
            return caps.availableAncMainModes
        }

        let mainModes = caps.availableAncMainModes.filter { $0 != .smart }
        return mainModes + caps.availableAncSubModes
    }

    var menuBarTitle: String {
        guard snapshot.connected else { return "OPods" }
        let parts = [PodComponent.left, .right, .case].compactMap { component -> String? in
            guard let reading = snapshot.mergedBattery(for: component) else { return nil }
            return "\(component.rawValue)\(reading.clippedLevel)"
        }
        return parts.isEmpty ? "OPods" : parts.joined(separator: " ")
    }

    func text(_ key: String) -> String {
        AppStrings.text(key, language: language)
    }

    func refreshPairedDevices() {
        pairedDevices = service.pairedDevices()
    }

    func connectAutomatically() {
        connect(to: nil)
    }

    func connect(to device: BluetoothDeviceCandidate?) {
        phase = .connecting
        if let device {
            setStatus("status.connectingDevice", argument: device.name)
        } else {
            setStatus("status.searching")
        }

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
        guard availableAncControlModes.contains(mode) else { return }
        ancUserSetAt = Date()
        snapshot.ancMode = mode
        service.sendAnc(mode, capabilities: effectiveCapabilities)
    }

    func sendSpatialSound(_ enabled: Bool) {
        spatialSoundUserSetAt = Date()
        snapshot.spatialSound = enabled
        service.sendSpatialSound(enabled)
    }

    func sendSpatialAudio(_ mode: SpatialAudioMode) {
        snapshot.spatialMode = mode
        service.sendSpatialAudio(mode)
    }

    func sendDualDevice(_ enabled: Bool) {
        dualDeviceUserSetAt = Date()
        snapshot.dualDevice = enabled
        service.sendDualDevice(enabled)
    }

    func sendGameMode(_ enabled: Bool) {
        gameModeUserSetAt = Date()
        snapshot.gameMode = enabled
        service.sendGameMode(enabled, compatible: gameModeCompatible)
    }

    func sendEqPreset(_ name: String) {
        eqPresetUserSetAt = Date()
        snapshot.eqPreset = name
        service.sendEqPreset(name, capabilities: effectiveCapabilities)
    }

    func refreshMultiConnectInfo() {
        service.refreshMultiConnectInfo()
    }

    func syncNow() {
        service.refreshNow()
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
            let name = capabilities.modelName == "Unknown" ? deviceName : capabilities.modelName
            setStatus("status.connectedDevice", argument: name)
        case .snapshot(let snapshot):
            var next = snapshot
            if Date().timeIntervalSince(gameModeUserSetAt) < 3 {
                next.gameMode = self.snapshot.gameMode
            }
            if Date().timeIntervalSince(ancUserSetAt) < 3 {
                next.ancMode = self.snapshot.ancMode
            }
            if next.ancMode == .unknown {
                next.ancMode = self.snapshot.ancMode
            }
            if Date().timeIntervalSince(spatialSoundUserSetAt) < 3 {
                next.spatialSound = self.snapshot.spatialSound
            }
            if Date().timeIntervalSince(dualDeviceUserSetAt) < 3 {
                next.dualDevice = self.snapshot.dualDevice
            }
            if Date().timeIntervalSince(eqPresetUserSetAt) < 3 {
                next.eqPreset = self.snapshot.eqPreset
            }
            self.snapshot = next
            phase = snapshot.connected ? .connected : .disconnected
        case .disconnected(let reason):
            snapshot.connected = false
            phase = .disconnected
            if let reason {
                statusMessage = reason
                statusMessageKey = ""
                statusMessageArgument = nil
            } else {
                setStatus("status.disconnected")
            }
        case .error(let message):
            phase = .failed(message)
            statusMessage = message
            statusMessageKey = ""
            statusMessageArgument = nil
        }
    }

    private func setStatus(_ key: String, argument: String? = nil) {
        statusMessageKey = key
        statusMessageArgument = argument
        statusMessage = localizedStatus(key: key, argument: argument)
    }

    private func refreshLocalizedStatusMessage() {
        guard !statusMessageKey.isEmpty else { return }
        statusMessage = localizedStatus(key: statusMessageKey, argument: statusMessageArgument)
    }

    private func localizedStatus(key: String, argument: String?) -> String {
        switch key {
        case "status.connectedDevice":
            let format = language == .chinese ? "已连接到 %@。" : "Connected to %@."
            return String(format: format, argument ?? "")
        case "status.connectingDevice":
            let format = language == .chinese ? "正在连接 %@..." : "Connecting to %@..."
            return String(format: format, argument ?? "")
        default:
            return text(key)
        }
    }
}
