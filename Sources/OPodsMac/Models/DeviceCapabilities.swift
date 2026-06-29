import Foundation

struct AncResponseKey: Hashable {
    var first: UInt8
    var second: UInt8
}

struct EqPresetOption: Identifiable, Equatable {
    var protocolIndex: UInt8
    var name: String

    var id: UInt8 { protocolIndex }
}

struct DeviceCapabilities: Equatable {
    var deviceName = ""
    var modelName = "Unknown"
    var modelId = ""
    var hasSpatialAudio = false
    var hasSpatialSound = false
    var hasDualDevice = false
    var hasAdaptiveAnc = false
    var hasAncSubModes = false
    var hasEqPreset = false
    var isLegacyAnc = false
    var hasGameMode = true
    var availableAncMainModes: [AncMode] = []
    var availableAncSubModes: [AncMode] = []
    var eqOptions: [EqPresetOption] = [
        EqPresetOption(protocolIndex: 0, name: FeatureDisplayCatalog.shared.defaultEqName())
    ]
    var eqPresets: [String: UInt8] = [
        FeatureDisplayCatalog.shared.defaultEqName(): 0
    ]
    var eqNames: [UInt8: String] = [
        0: FeatureDisplayCatalog.shared.defaultEqName()
    ]
    var ancModeMap: [AncResponseKey: AncMode] = [:]

    static let fallback = DeviceCapabilities()

    static func Detect(_ deviceName: String?) -> DeviceCapabilities {
        DeviceCatalog.shared.detect(deviceName: deviceName)
    }

    static func ForceModel(_ modelName: String?) -> DeviceCapabilities {
        DeviceCatalog.shared.forceModel(modelName)
    }

    static func GetModelNames() -> [String] {
        DeviceCatalog.shared.modelNames
    }
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
    let equalizerModeCompat: [ModeIndexEntry]?
    let equalizerModeByVersion: [ModeIndexEntry]?
}

struct NoiseReductionMode: Decodable {
    let modeType: Int?
    let protocolIndex: Int?
    let childrenMode: [ModeIndexEntry]?
}

struct ModeIndexEntry: Decodable {
    let modeType: Int?
    let protocolIndex: Int?
    let order: Int?
}

struct EqNameDocument: Decodable {
    let mapping: [String: String]
}

final class DeviceCatalog {
    static let shared = DeviceCatalog()

    private(set) var models: [DeviceModelEntry] = []
    private(set) var eqModeNames: [String: String] = [:]
    private let featureDisplay: FeatureDisplayCatalog

    init(bundle: Bundle = .module) {
        featureDisplay = FeatureDisplayCatalog(bundle: bundle)
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
        return OppoProtocol.SupportedBrands.contains { upper.contains($0.uppercased()) }
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
            caps.hasAdaptiveAnc = noiseReductionMode.contains { $0.modeType == 10 }
            caps.availableAncMainModes = buildAncMainModes(from: noiseReductionMode)
            caps.availableAncSubModes = buildAncSubModes(from: noiseReductionMode)
            caps.hasAncSubModes = !caps.availableAncSubModes.isEmpty
            caps.ancModeMap = buildAncMap(from: noiseReductionMode)

            if !caps.hasAncSubModes {
                caps.isLegacyAnc = noiseReductionMode.contains {
                    $0.modeType == 5 && $0.protocolIndex == 0
                }
            }
        }

        let eqEntries = eqModeEntries(from: function)
        let eqOptions = buildEqOptions(from: eqEntries)
        caps.hasEqPreset = !eqEntries.isEmpty
        caps.eqOptions = eqOptions
        caps.eqNames = Dictionary(uniqueKeysWithValues: eqOptions.map { ($0.protocolIndex, $0.name) })
        caps.eqPresets = buildEqPresetLookup(from: eqOptions)
        return caps
    }

    private func buildAncMainModes(from modes: [NoiseReductionMode]) -> [AncMode] {
        var available = Set<AncMode>()
        for mode in modes {
            guard let modeType = mode.modeType,
                  let ancMode = mainAncMode(forModeType: modeType) else {
                continue
            }
            available.insert(ancMode)
        }
        return featureDisplay.orderedAncMainModes(available)
    }

    private func buildAncSubModes(from modes: [NoiseReductionMode]) -> [AncMode] {
        guard let noiseCancelling = modes.first(where: { $0.modeType == 5 }),
              let children = noiseCancelling.childrenMode,
              !children.isEmpty else {
            return []
        }
        return featureDisplay.orderedAncSubModes(from: children)
    }

    private func mainAncMode(forModeType modeType: Int) -> AncMode? {
        guard let mode = featureDisplay.ancMode(forModeType: modeType) else { return nil }
        switch mode {
        case .light, .medium, .deep:
            return .smart
        default:
            return mode
        }
    }

    private func eqModeEntries(from function: DeviceFunction) -> [ModeIndexEntry] {
        var entries: [ModeIndexEntry] = []
        for collection in featureDisplay.eqModeCollections {
            switch collection {
            case "equalizerMode":
                entries.append(contentsOf: function.equalizerMode ?? [])
            case "equalizerModeCompat":
                entries.append(contentsOf: function.equalizerModeCompat ?? [])
            case "equalizerModeByVersion":
                if featureDisplay.includeVersionGatedEqModesWhenVersionUnknown {
                    entries.append(contentsOf: function.equalizerModeByVersion ?? [])
                }
            default:
                break
            }
        }
        return orderedEqEntries(entries)
    }

    private func orderedEqEntries(_ entries: [ModeIndexEntry]) -> [ModeIndexEntry] {
        guard entries.contains(where: { $0.order != nil }) else { return entries }
        return entries.enumerated()
            .sorted { left, right in
                let leftOrder = left.element.order ?? left.offset + 1
                let rightOrder = right.element.order ?? right.offset + 1
                if leftOrder != rightOrder {
                    return leftOrder < rightOrder
                }
                return left.offset < right.offset
            }
            .map(\.element)
    }

    private func buildEqOptions(from modes: [ModeIndexEntry]) -> [EqPresetOption] {
        guard !modes.isEmpty else {
            return defaultEqOptions()
        }

        var options: [EqPresetOption] = []
        var seenIndexes = Set<UInt8>()
        for mode in modes {
            guard let protocolIndex = mode.protocolIndex else { continue }
            let index = UInt8(clamping: protocolIndex)
            guard seenIndexes.insert(index).inserted else { continue }
            options.append(EqPresetOption(
                protocolIndex: index,
                name: eqDisplayName(for: mode, protocolIndex: index)
            ))
        }
        return options.isEmpty ? defaultEqOptions() : options
    }

    private func eqDisplayName(for mode: ModeIndexEntry, protocolIndex: UInt8) -> String {
        if let modeType = mode.modeType,
           let mapped = eqModeNames[String(modeType)],
           !mapped.isEmpty {
            return mapped
        }
        return featureDisplay.eqFallbackName(protocolIndex: protocolIndex, modeType: mode.modeType)
    }

    private func defaultEqOptions() -> [EqPresetOption] {
        [EqPresetOption(protocolIndex: 0, name: featureDisplay.defaultEqName())]
    }

    private func buildEqPresetLookup(from options: [EqPresetOption]) -> [String: UInt8] {
        var presets: [String: UInt8] = [:]
        for option in options where presets[option.name] == nil {
            presets[option.name] = option.protocolIndex
        }
        return presets
    }

    private func buildAncMap(from modes: [NoiseReductionMode]) -> [AncResponseKey: AncMode] {
        var map: [AncResponseKey: AncMode] = [:]

        for mode in modes {
            guard let type = mode.modeType else { continue }
            guard let children = mode.childrenMode, !children.isEmpty else {
                if let index = mode.protocolIndex {
                    map[AncResponseKey(first: UInt8(clamping: type), second: UInt8(clamping: index))] = featureDisplay.ancMode(forModeType: type) ?? .smart
                }
                continue
            }

            for child in children {
                guard let protocolIndex = child.protocolIndex else { continue }
                let key = AncResponseKey(first: UInt8(clamping: type), second: UInt8(clamping: protocolIndex))
                map[key] = child.modeType.flatMap(featureDisplay.ancMode(forModeType:)) ?? .unknown
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
