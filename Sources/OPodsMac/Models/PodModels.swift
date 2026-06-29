import Foundation

enum PodComponent: String, CaseIterable, Identifiable, Hashable {
    case left = "L"
    case right = "R"
    case `case` = "C"

    var id: String { rawValue }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .left: AppStrings.text("component.left", language: language)
        case .right: AppStrings.text("component.right", language: language)
        case .case: AppStrings.text("component.case", language: language)
        }
    }

    var assetName: String {
        switch self {
        case .left: "left"
        case .right: "right"
        case .case: "cang"
        }
    }
}

struct BatteryReading: Equatable {
    var level: Int
    var charging: Bool

    var clippedLevel: Int { min(100, max(0, level)) }
}

enum WearingStatus: String, Equatable {
    case disconnected = "Disconnected"
    case inCase = "In case"
    case removed = "Removed"
    case worn = "Worn"
    case unknown = "Unknown"

    init(protocolValue: UInt8) {
        switch protocolValue {
        case 0: self = .disconnected
        case 4: self = .inCase
        case 5: self = .removed
        case 7: self = .worn
        default: self = .unknown
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .disconnected: AppStrings.text("wear.disconnected", language: language)
        case .inCase: AppStrings.text("wear.inCase", language: language)
        case .removed: AppStrings.text("wear.removed", language: language)
        case .worn: AppStrings.text("wear.worn", language: language)
        case .unknown: AppStrings.text("wear.unknown", language: language)
        }
    }
}

enum AncMode: String, CaseIterable, Identifiable, Equatable, Hashable {
    case off = "Off"
    case smart = "Smart"
    case light = "Light"
    case medium = "Medium"
    case deep = "Deep"
    case adaptive = "Adaptive"
    case transparency = "Transparency"
    case unknown = "Unknown"

    var id: String { rawValue }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        FeatureDisplayCatalog.shared.ancModeTitle(self, language: language)
    }
}

enum SpatialAudioMode: String, CaseIterable, Identifiable, Equatable {
    case off = "Off"
    case fixed = "Fixed"
    case tracking = "Track"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        FeatureDisplayCatalog.shared.spatialAudioTitle(self, language: language)
    }
}

struct ConnectedDeviceInfo: Identifiable, Equatable {
    var address: String
    var deviceName: String
    var deviceType: Int
    var connectionState: Int
    var isAudioActive: Bool
    var isCurrentDevice: Bool
    var isMainAudioDevice: Bool

    var id: String { address }

    var statusText: String {
        statusText(language: .english)
    }

    func statusText(language: AppLanguage) -> String {
        switch connectionState {
        case 2: AppStrings.text("connected", language: language)
        case 1: AppStrings.text("connecting", language: language)
        default: AppStrings.text("disconnected", language: language)
        }
    }
}

struct BluetoothDeviceCandidate: Identifiable, Equatable {
    var address: String
    var name: String
    var likelySupported: Bool
    var isSystemConnected: Bool

    var id: String { address }
}

enum PairedDeviceConnectionState: Equatable {
    case controlled
    case connecting
    case systemConnected
    case paired
    case unsupported

    func title(language: AppLanguage) -> String {
        switch self {
        case .controlled: AppStrings.text("controlledByApp", language: language)
        case .connecting: AppStrings.text("connecting", language: language)
        case .systemConnected: AppStrings.text("bluetoothConnected", language: language)
        case .paired: AppStrings.text("paired", language: language)
        case .unsupported: AppStrings.text("unsupportedDevice", language: language)
        }
    }
}

struct PodSnapshot: Equatable {
    var connected = false
    var connectedDeviceName = ""
    var connectedDeviceAddress = ""
    var battery: [PodComponent: BatteryReading] = [:]
    var wearing: [PodComponent: WearingStatus] = [:]
    var ancMode: AncMode = .unknown
    var eqPreset = ""
    var spatialSound = false
    var spatialMode: SpatialAudioMode = .off
    var gameMode = false
    var dualDevice = false
    var connectedDevices: [ConnectedDeviceInfo] = []
    var multiConnectUpdatedAt: Date?

    func mergedBattery(for component: PodComponent) -> BatteryReading? {
        guard var reading = battery[component] else { return nil }
        if wearing[component] == .inCase {
            reading.charging = true
        }
        return reading
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case controls
    case devices
    case settings
    case about

    var id: String { rawValue }

    var title: String {
        title(language: .english)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview: AppStrings.text("overview", language: language)
        case .controls: AppStrings.text("controls", language: language)
        case .devices: AppStrings.text("devices", language: language)
        case .settings: AppStrings.text("settings", language: language)
        case .about: AppStrings.text("about", language: language)
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "earbuds"
        case .controls: "slider.horizontal.3"
        case .devices: "dot.radiowaves.left.and.right"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}
