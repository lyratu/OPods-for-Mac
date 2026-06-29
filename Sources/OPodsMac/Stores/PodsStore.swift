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
    private let featureDisplay = FeatureDisplayCatalog.shared
    private var statusMessageKey = "status.initial"
    private var statusMessageArgument: String?
    private var gameModeUserSetAt = Date.distantPast
    private var ancUserSetAt = Date.distantPast
    private var spatialSoundUserSetAt = Date.distantPast
    private var dualDeviceUserSetAt = Date.distantPast
    private var eqPresetUserSetAt = Date.distantPast
    private var connectingDeviceAddress: String?
    private var autoConnectSuppressedAddresses = Set<String>()
    private var bluetoothObservers: [NSObjectProtocol] = []

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
        observeBluetoothConnectionChanges()
        refreshPairedDevices()
    }

    deinit {
        for observer in bluetoothObservers {
            NotificationCenter.default.removeObserver(observer)
        }
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

    var capabilityDisplayItems: [CapabilityDisplayItem] {
        featureDisplay.capabilityItems(for: effectiveCapabilities, language: language)
    }

    func text(_ key: String) -> String {
        AppStrings.text(key, language: language)
    }

    func controlGroupTitle(_ id: String) -> String {
        featureDisplay.controlGroupTitle(id, language: language)
    }

    func featureTitle(_ id: String) -> String {
        featureDisplay.featureTitle(id, language: language)
    }

    func defaultEqName() -> String {
        featureDisplay.defaultEqName()
    }

    func refreshPairedDevices() {
        let devices = refreshPairedDeviceCache()
        autoConnectToSystemConnectedDeviceIfNeeded(from: devices)
    }

    func connectAutomatically() {
        let devices = refreshPairedDeviceCache()
        if let preferredDevice = preferredConnectionDevice(in: devices) {
            allowAutoConnect(for: preferredDevice.address)
            connect(to: preferredDevice, automatic: preferredDevice.isSystemConnected)
            return
        }
        autoConnectSuppressedAddresses.removeAll()
        connect(to: nil)
    }

    func connect(to device: BluetoothDeviceCandidate?, automatic: Bool = false) {
        if !automatic {
            if let address = device?.address {
                allowAutoConnect(for: address)
            } else {
                autoConnectSuppressedAddresses.removeAll()
            }
        }
        phase = .connecting
        connectingDeviceAddress = device?.address
        if let device {
            setStatus(automatic ? "status.adoptingConnectedDevice" : "status.connectingDevice", argument: device.name)
        } else {
            setStatus("status.searching")
        }

        Task {
            do {
                try await service.connect(to: device)
            } catch {
                connectingDeviceAddress = nil
                phase = .failed(error.localizedDescription)
                statusMessage = error.localizedDescription
            }
        }
    }

    func disconnect() {
        suppressAutoConnectForCurrentDevice()
        connectingDeviceAddress = nil
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

    func isCurrentConnectedDevice(_ device: BluetoothDeviceCandidate) -> Bool {
        guard snapshot.connected else { return false }
        if !snapshot.connectedDeviceAddress.isEmpty {
            return snapshot.connectedDeviceAddress.caseInsensitiveCompare(device.address) == .orderedSame
        }
        return snapshot.connectedDeviceName.localizedCaseInsensitiveCompare(device.name) == .orderedSame
    }

    func isConnecting(to device: BluetoothDeviceCandidate) -> Bool {
        guard case .connecting = phase else { return false }
        if let connectingDeviceAddress {
            return connectingDeviceAddress.caseInsensitiveCompare(device.address) == .orderedSame
        }
        return false
    }

    func connectionState(for device: BluetoothDeviceCandidate) -> PairedDeviceConnectionState {
        if isCurrentConnectedDevice(device) {
            return .controlled
        }
        if isConnecting(to: device) {
            return .connecting
        }
        if device.isSystemConnected {
            return device.likelySupported ? .systemConnected : .unsupported
        }
        return device.likelySupported ? .paired : .unsupported
    }

    private func handle(_ event: PodsServiceEvent) {
        switch event {
        case .connected(let deviceName, let capabilities, let snapshot):
            connectingDeviceAddress = nil
            self.snapshot = snapshot
            detectedCapabilities = capabilities
            phase = .connected
            _ = refreshPairedDeviceCache()
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
            connectingDeviceAddress = nil
            snapshot.connected = false
            phase = .disconnected
            let devices = refreshPairedDeviceCache()
            if let reason {
                statusMessage = reason
                statusMessageKey = ""
                statusMessageArgument = nil
                autoConnectToSystemConnectedDeviceIfNeeded(from: devices)
            } else {
                setStatus("status.disconnected")
            }
        case .error(let message):
            connectingDeviceAddress = nil
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
        case "status.adoptingConnectedDevice":
            let format = language == .chinese ? "发现已连接的 %@，正在接管控制..." : "Found connected %@. Taking control..."
            return String(format: format, argument ?? "")
        default:
            return text(key)
        }
    }

    @discardableResult
    private func refreshPairedDeviceCache() -> [BluetoothDeviceCandidate] {
        let devices = service.pairedDevices()
        pairedDevices = devices
        return devices
    }

    private func observeBluetoothConnectionChanges() {
        let names = [
            Notification.Name("IOBluetoothDeviceConnected"),
            Notification.Name("IOBluetoothDeviceDisconnected")
        ]
        bluetoothObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshPairedDevices()
                }
            }
        }
    }

    private func autoConnectToSystemConnectedDeviceIfNeeded(from devices: [BluetoothDeviceCandidate]) {
        guard shouldStartAutomaticConnection,
              let device = systemConnectedSupportedDevice(in: devices) else {
            return
        }
        guard !isAutoConnectSuppressed(for: device.address) else { return }
        connect(to: device, automatic: true)
    }

    private var shouldStartAutomaticConnection: Bool {
        if snapshot.connected { return false }
        if case .connecting = phase { return false }
        return true
    }

    private func systemConnectedSupportedDevice(in devices: [BluetoothDeviceCandidate]) -> BluetoothDeviceCandidate? {
        devices.first { $0.likelySupported && $0.isSystemConnected }
    }

    private func preferredConnectionDevice(in devices: [BluetoothDeviceCandidate]) -> BluetoothDeviceCandidate? {
        systemConnectedSupportedDevice(in: devices) ?? devices.first { $0.likelySupported }
    }

    private func suppressAutoConnectForCurrentDevice() {
        if !snapshot.connectedDeviceAddress.isEmpty {
            autoConnectSuppressedAddresses.insert(normalizedAddress(snapshot.connectedDeviceAddress))
        }
        if let connectingDeviceAddress {
            autoConnectSuppressedAddresses.insert(normalizedAddress(connectingDeviceAddress))
        }
    }

    private func allowAutoConnect(for address: String) {
        autoConnectSuppressedAddresses.remove(normalizedAddress(address))
    }

    private func isAutoConnectSuppressed(for address: String) -> Bool {
        autoConnectSuppressedAddresses.contains(normalizedAddress(address))
    }

    private func normalizedAddress(_ address: String) -> String {
        address.uppercased()
    }
}
