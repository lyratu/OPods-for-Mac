import Foundation

enum PodComponent: String, CaseIterable, Identifiable, Hashable {
    case left = "L"
    case right = "R"
    case `case` = "C"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .case: "Case"
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
}

enum AncMode: String, CaseIterable, Identifiable, Equatable {
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
        switch self {
        case .off: "Off"
        case .smart: "Smart"
        case .light: "Light"
        case .medium: "Medium"
        case .deep: "Deep"
        case .adaptive: "Adaptive"
        case .transparency: "Transparency"
        case .unknown: "Unknown"
        }
    }
}

enum SpatialAudioMode: String, CaseIterable, Identifiable, Equatable {
    case off = "Off"
    case fixed = "Fixed"
    case tracking = "Track"

    var id: String { rawValue }
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
        switch connectionState {
        case 2: isCurrentDevice ? "Current device" : "Connected"
        case 1: "Connecting"
        default: "Disconnected"
        }
    }
}

struct BluetoothDeviceCandidate: Identifiable, Equatable {
    var address: String
    var name: String
    var likelySupported: Bool

    var id: String { address }
}

struct PodSnapshot: Equatable {
    var connected = false
    var connectedDeviceName = ""
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
        switch self {
        case .overview: "Overview"
        case .controls: "Controls"
        case .devices: "Devices"
        case .settings: "Settings"
        case .about: "About"
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
