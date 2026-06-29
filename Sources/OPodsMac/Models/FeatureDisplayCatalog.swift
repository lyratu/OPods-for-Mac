import Foundation

struct LocalizedDisplayName: Decodable, Equatable {
    var en: String
    var zhCN: String

    func text(language: AppLanguage) -> String {
        switch language {
        case .english: en
        case .chinese: zhCN
        }
    }
}

struct CapabilityDisplayItem: Identifiable, Equatable {
    var id: String
    var title: String
    var enabled: Bool
}

private struct FeatureDisplayDocument: Decodable {
    var controlGroups: [String: LocalizedDisplayName]
    var features: [String: LocalizedDisplayName]
    var capabilityItems: [CapabilityItemDefinition]
    var anc: AncDisplayDefinition
    var spatialAudio: SpatialAudioDisplayDefinition
    var eq: EqDisplayDefinition
}

private struct CapabilityItemDefinition: Decodable {
    var feature: String
    var capability: String
}

private struct AncDisplayDefinition: Decodable {
    var mainOrder: [String]
    var subModeFallbackOrder: [String]
    var modeTypes: [String: String]
    var modes: [String: LocalizedDisplayName]
}

private struct SpatialAudioDisplayDefinition: Decodable {
    var modes: [String: LocalizedDisplayName]
}

private struct EqDisplayDefinition: Decodable {
    var modeCollections: [String]
    var includeVersionGatedModesWhenVersionUnknown: Bool
    var fallbackName: String
    var fallbackIndexedNameFormat: String
}

final class FeatureDisplayCatalog {
    static let shared = FeatureDisplayCatalog()

    private let document: FeatureDisplayDocument

    init(bundle: Bundle = .module) {
        document = Self.loadDocument(bundle: bundle) ?? Self.fallbackDocument()
    }

    var includeVersionGatedEqModesWhenVersionUnknown: Bool {
        document.eq.includeVersionGatedModesWhenVersionUnknown
    }

    var eqModeCollections: [String] {
        document.eq.modeCollections
    }

    func controlGroupTitle(_ id: String, language: AppLanguage) -> String {
        document.controlGroups[id]?.text(language: language) ?? id
    }

    func featureTitle(_ id: String, language: AppLanguage) -> String {
        document.features[id]?.text(language: language) ?? id
    }

    func ancModeTitle(_ mode: AncMode, language: AppLanguage) -> String {
        document.anc.modes[mode.displayConfigKey]?.text(language: language) ?? mode.rawValue
    }

    func spatialAudioTitle(_ mode: SpatialAudioMode, language: AppLanguage) -> String {
        document.spatialAudio.modes[mode.displayConfigKey]?.text(language: language) ?? mode.rawValue
    }

    func ancMode(forModeType modeType: Int) -> AncMode? {
        guard let key = document.anc.modeTypes[String(modeType)] else { return nil }
        return AncMode(displayConfigKey: key)
    }

    func orderedAncMainModes(_ modes: Set<AncMode>) -> [AncMode] {
        orderedAncModes(document.anc.mainOrder, available: modes)
    }

    func orderedAncSubModes(from children: [ModeIndexEntry]) -> [AncMode] {
        let mapped = children.compactMap { child -> AncMode? in
            guard let modeType = child.modeType else { return nil }
            return ancMode(forModeType: modeType)
        }
        if !mapped.isEmpty {
            return orderedAncModes(document.anc.subModeFallbackOrder, available: Set(mapped))
        }

        let fallbackModes = document.anc.subModeFallbackOrder
            .compactMap { AncMode(displayConfigKey: $0) }
        return Array(fallbackModes.prefix(children.count))
    }

    func eqFallbackName(protocolIndex: UInt8, modeType: Int?) -> String {
        if let modeType {
            return String(format: document.eq.fallbackIndexedNameFormat, modeType)
        }
        return String(format: document.eq.fallbackIndexedNameFormat, Int(protocolIndex))
    }

    func defaultEqName() -> String {
        document.eq.fallbackName
    }

    func capabilityItems(for capabilities: DeviceCapabilities, language: AppLanguage) -> [CapabilityDisplayItem] {
        document.capabilityItems.map { definition in
            CapabilityDisplayItem(
                id: definition.feature,
                title: featureTitle(definition.feature, language: language),
                enabled: isCapability(definition.capability, enabledFor: capabilities)
            )
        }
    }

    private func orderedAncModes(_ order: [String], available: Set<AncMode>) -> [AncMode] {
        order.compactMap { key -> AncMode? in
            guard let mode = AncMode(displayConfigKey: key), available.contains(mode) else { return nil }
            return mode
        }
    }

    private func isCapability(_ capability: String, enabledFor caps: DeviceCapabilities) -> Bool {
        switch capability {
        case "ancAvailable": !caps.availableAncMainModes.isEmpty
        case "ancSubModes": caps.hasAncSubModes
        case "adaptiveAnc": caps.hasAdaptiveAnc
        case "spatialSound": caps.hasSpatialSound
        case "spatialAudio": caps.hasSpatialAudio
        case "dualDevice": caps.hasDualDevice
        case "eqPreset": caps.hasEqPreset
        case "gameMode": caps.hasGameMode
        default: false
        }
    }

    private static func loadDocument(bundle: Bundle) -> FeatureDisplayDocument? {
        guard let url = bundle.url(forResource: "FeatureDisplayConfig", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(FeatureDisplayDocument.self, from: data)
        } catch {
            return nil
        }
    }

    private static func fallbackDocument() -> FeatureDisplayDocument {
        FeatureDisplayDocument(
            controlGroups: [:],
            features: [:],
            capabilityItems: [],
            anc: AncDisplayDefinition(
                mainOrder: AncMode.allCases.map(\.displayConfigKey),
                subModeFallbackOrder: [],
                modeTypes: [:],
                modes: [:]
            ),
            spatialAudio: SpatialAudioDisplayDefinition(modes: [:]),
            eq: EqDisplayDefinition(
                modeCollections: ["equalizerMode"],
                includeVersionGatedModesWhenVersionUnknown: false,
                fallbackName: "Default",
                fallbackIndexedNameFormat: "Mode %d"
            )
        )
    }
}

private extension AncMode {
    var displayConfigKey: String {
        switch self {
        case .off: "off"
        case .smart: "smart"
        case .light: "light"
        case .medium: "medium"
        case .deep: "deep"
        case .adaptive: "adaptive"
        case .transparency: "transparency"
        case .unknown: "unknown"
        }
    }

    init?(displayConfigKey key: String) {
        switch key.lowercased() {
        case "off": self = .off
        case "smart": self = .smart
        case "light": self = .light
        case "medium": self = .medium
        case "deep": self = .deep
        case "adaptive": self = .adaptive
        case "transparency": self = .transparency
        case "unknown": self = .unknown
        default: return nil
        }
    }
}

private extension SpatialAudioMode {
    var displayConfigKey: String {
        switch self {
        case .off: "off"
        case .fixed: "fixed"
        case .tracking: "tracking"
        }
    }
}
