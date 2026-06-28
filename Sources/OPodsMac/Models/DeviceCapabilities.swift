import Foundation

struct AncResponseKey: Hashable {
    var first: UInt8
    var second: UInt8
}

struct DeviceCapabilities: Equatable {
    var deviceName = ""
    var modelName = "Unknown"
    var modelId = ""
    var hasSpatialAudio = false
    var hasSpatialSound = false
    var hasDualDevice = false
    var hasAdaptiveAnc = false
    var isLegacyAnc = false
    var hasGameMode = true
    var eqPresets: [String: UInt8] = ["Default": 0]
    var eqNames: [UInt8: String] = [0: "Default"]
    var ancModeMap: [AncResponseKey: AncMode] = [:]

    static let fallback = DeviceCapabilities()
}

struct DeviceModelEntry: Decodable, Identifiable {
    let name: String
    let id: String?
    let brand: String?
    let uuid: String?
    let supportSpp: Bool?
    let function: DeviceFunction?
}

struct DeviceFunction: Decodable {
    let spatialTypes: [Int]?
    let multiDevicesConnect: Int?
    let noiseReductionMode: [NoiseReductionMode]?
    let equalizerMode: [ModeIndexEntry]?
}

struct NoiseReductionMode: Decodable {
    let modeType: Int?
    let protocolIndex: Int?
    let childrenMode: [ModeIndexEntry]?
}

struct ModeIndexEntry: Decodable {
    let modeType: Int?
    let protocolIndex: Int?
}

struct EqNameDocument: Decodable {
    let mapping: [String: String]
}

final class DeviceCatalog {
    static let shared = DeviceCatalog()

    private(set) var models: [DeviceModelEntry] = []
    private(set) var eqModeNames: [String: String] = [:]

    init(bundle: Bundle = .module) {
        models = Self.loadModels(bundle: bundle)
        models.sort { $0.name.count > $1.name.count }
        eqModeNames = Self.loadEqNames(bundle: bundle)
    }

    var modelNames: [String] {
        models.map(\.name)
    }

    func detect(deviceName: String?) -> DeviceCapabilities {
        guard let deviceName, !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .fallback
        }

        let normalizedName = normalize(deviceName)
        for entry in models where matches(normalizedName, normalize(entry.name)) {
            return capabilities(from: entry, deviceName: deviceName)
        }

        var unknown = DeviceCapabilities.fallback
        unknown.deviceName = deviceName
        unknown.modelName = deviceName
        return unknown
    }

    func forceModel(_ modelName: String?) -> DeviceCapabilities {
        guard let modelName, !modelName.isEmpty else { return .fallback }
        guard let entry = models.first(where: { $0.name.caseInsensitiveCompare(modelName) == .orderedSame }) else {
            return .fallback
        }
        return capabilities(from: entry, deviceName: modelName)
    }

    func likelySupported(deviceName: String) -> Bool {
        let detected = detect(deviceName: deviceName)
        if detected.modelName != "Unknown", detected.modelName != deviceName {
            return true
        }
        let upper = deviceName.uppercased()
        return OppoProtocol.supportedBrands.contains { upper.contains($0.uppercased()) }
    }

    private func capabilities(from entry: DeviceModelEntry, deviceName: String) -> DeviceCapabilities {
        var caps = DeviceCapabilities()
        caps.deviceName = deviceName
        caps.modelName = entry.name
        caps.modelId = entry.id ?? ""

        guard let function = entry.function else { return caps }

        if let spatialTypes = function.spatialTypes {
            caps.hasSpatialSound = true
            caps.hasSpatialAudio = spatialTypes.count >= 3
        }

        if let multiDevicesConnect = function.multiDevicesConnect {
            caps.hasDualDevice = multiDevicesConnect >= 1
        }

        if let noiseReductionMode = function.noiseReductionMode {
            caps.hasAdaptiveAnc = noiseReductionMode.contains { $0.childrenMode?.isEmpty == false }
            caps.ancModeMap = buildAncMap(from: noiseReductionMode)

            if !caps.hasAdaptiveAnc {
                caps.isLegacyAnc = noiseReductionMode.contains {
                    $0.modeType == 5 && $0.protocolIndex == 0
                }
            }
        }

        let eqNames = buildEqNames(from: function.equalizerMode)
        caps.eqNames = eqNames
        caps.eqPresets = Dictionary(uniqueKeysWithValues: eqNames.map { ($0.value, $0.key) })
        return caps
    }

    private func buildEqNames(from modes: [ModeIndexEntry]?) -> [UInt8: String] {
        guard let modes, !modes.isEmpty else {
            return [0: "Default"]
        }

        var names: [UInt8: String] = [:]
        for mode in modes {
            guard let protocolIndex = mode.protocolIndex else { continue }
            let index = UInt8(clamping: protocolIndex)
            var displayName = index < 10 ? "Mode \(index)" : "M\(index)"
            if let modeType = mode.modeType,
               let mapped = eqModeNames[String(modeType)],
               !mapped.isEmpty {
                displayName = mapped
            }
            names[index] = displayName
        }
        return names.isEmpty ? [0: "Default"] : names
    }

    private func buildAncMap(from modes: [NoiseReductionMode]) -> [AncResponseKey: AncMode] {
        let adaptiveNames: [AncMode] = [.smart, .light, .medium, .deep]
        var map: [AncResponseKey: AncMode] = [:]

        for mode in modes {
            guard let type = mode.modeType else { continue }
            guard let children = mode.childrenMode, !children.isEmpty else {
                if let index = mode.protocolIndex {
                    map[AncResponseKey(first: UInt8(clamping: type), second: UInt8(clamping: index))] = .unknown
                }
                continue
            }

            for (childIndex, child) in children.enumerated() {
                guard let protocolIndex = child.protocolIndex else { continue }
                let key = AncResponseKey(first: UInt8(clamping: type), second: UInt8(clamping: protocolIndex))
                if type == 1 {
                    map[key] = .off
                } else if type == 2 {
                    map[key] = .transparency
                } else if adaptiveNames.indices.contains(childIndex) {
                    map[key] = adaptiveNames[childIndex]
                } else {
                    map[key] = .unknown
                }
            }
        }
        return map
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func matches(_ deviceName: String, _ modelName: String) -> Bool {
        deviceName.contains(modelName) || modelName.contains(deviceName)
    }

    private static func loadModels(bundle: Bundle) -> [DeviceModelEntry] {
        guard let url = bundle.url(forResource: "DeviceModels", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([DeviceModelEntry].self, from: data)
        } catch {
            return []
        }
    }

    private static func loadEqNames(bundle: Bundle) -> [String: String] {
        guard let url = bundle.url(forResource: "EqModeNames", withExtension: "json") else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(EqNameDocument.self, from: data).mapping
        } catch {
            return [:]
        }
    }
}
