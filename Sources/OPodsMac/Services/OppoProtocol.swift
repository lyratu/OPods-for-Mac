import Foundation

/// Swift mirror of upstream `OppoProtocol.cs`.
///
/// Keep names and grouping close to the C# source so command/feature updates can
/// be ported with a small mechanical diff.
enum OppoProtocol {
    static let OppoSppUuidString = "0000079A-D102-11E1-9B23-00025B00A5A5"
    static let OppoSppUuidBytes: [UInt8] = [
        0x00, 0x00, 0x07, 0x9A,
        0xD1, 0x02, 0x11, 0xE1,
        0x9B, 0x23, 0x00, 0x02,
        0x5B, 0x00, 0xA5, 0xA5
    ]

    static let Header: UInt8 = 0xAA
    static let Seq: UInt8 = 0xF0

    // MARK: Commands

    static let CmdBattery: UInt16 = 0x0106
    static let CmdBatteryResp: UInt16 = 0x8106
    static let CmdAnc: UInt16 = 0x0404
    static let CmdQueryAnc: UInt16 = 0x010C
    static let CmdAncResp: UInt16 = 0x810C
    static let CmdActiveReport: UInt16 = 0x0204
    static let CmdSetFeature: UInt16 = 0x0403
    static let CmdSetEq: UInt16 = 0x0406
    static let CmdQueryEq: UInt16 = 0x010F
    static let CmdEqResp: UInt16 = 0x810F
    static let CmdEqNotify: UInt16 = 0x0504
    static let CmdSpatialAudio: UInt16 = 0x0422
    static let CmdRegisterNotify: UInt16 = 0x0205
    static let CmdBatchQuery: UInt16 = 0x010D
    static let CmdBatchQueryResp: UInt16 = 0x810D
    static let CmdMultiConnectInfo: UInt16 = 0x0112
    static let CmdMultiConnectResp: UInt16 = 0x8112
    static let CmdOperateHandheld: UInt16 = 0x0429

    // MARK: Feature IDs

    static let FeatureSpatial: UInt8 = 0x1B
    static let FeatureGameMain: UInt8 = 0x28
    static let FeatureGameLL: UInt8 = 0x06
    static let FeatureDualDevice: UInt8 = 0x11

    // MARK: ANC payloads

    static let AncOff: [UInt8] = [0x01, 0x01, 0x01]
    static let AncSmart: [UInt8] = [0x01, 0x01, 0x80]
    static let AncLight: [UInt8] = [0x01, 0x01, 0x40]
    static let AncMedium: [UInt8] = [0x01, 0x01, 0x20]
    static let AncDeep: [UInt8] = [0x01, 0x01, 0x10]
    static let AncAdaptive: [UInt8] = [0x01, 0x01, 0x00, 0x08]
    static let AncTransparency: [UInt8] = [0x01, 0x01, 0x04]

    static let AncOffLegacy: [UInt8] = [0x01, 0x01, 0x08]

    static let AncValues: [AncResponseKey: AncMode] = [
        AncResponseKey(first: 8, second: 0): .off,
        AncResponseKey(first: 2, second: 0): .smart,
        AncResponseKey(first: 0x80, second: 0): .smart,
        AncResponseKey(first: 0x40, second: 0): .light,
        AncResponseKey(first: 0x20, second: 0): .medium,
        AncResponseKey(first: 0x10, second: 0): .deep,
        AncResponseKey(first: 0, second: 1): .transparency,
        AncResponseKey(first: 0, second: 2): .transparency,
        AncResponseKey(first: 4, second: 0): .transparency,
        AncResponseKey(first: 0, second: 8): .adaptive
    ]

    // MARK: Spatial audio payloads

    static let SpatialOff: [UInt8] = [0x00]
    static let SpatialFixed: [UInt8] = [0x01]
    static let SpatialTrack: [UInt8] = [0x02]

    static func BuildPacket(_ cmd: UInt16, _ payload: [UInt8] = []) -> [UInt8] {
        let totalLen = 7 + payload.count
        var pkt = [UInt8](repeating: 0, count: 2 + totalLen)
        pkt[0] = Header
        pkt[1] = UInt8(clamping: totalLen)
        pkt[2] = 0x00
        pkt[3] = 0x00
        pkt[4] = UInt8(cmd & 0x00FF)
        pkt[5] = UInt8(cmd >> 8)
        pkt[6] = Seq
        pkt[7] = UInt8(payload.count & 0x00FF)
        pkt[8] = UInt8(payload.count >> 8)
        pkt.replaceSubrange(9..<9 + payload.count, with: payload)
        return pkt
    }

    static func BuildFeaturePacket(_ feature: UInt8, _ on: Bool) -> [UInt8] {
        BuildPacket(CmdSetFeature, [feature, on ? 0x01 : 0x00])
    }

    // MARK: Prebuilt packets

    static let PktBattery = BuildPacket(CmdBattery)
    static let PktQueryAnc = BuildPacket(CmdQueryAnc, [0x01, 0x01])
    static let PktQueryEq = BuildPacket(CmdQueryEq)
    static let PktRegisterNotify = BuildPacket(CmdRegisterNotify, [0x01, 0x01, 0x02, 0x02])
    static let PktBatchQuery = BuildPacket(CmdBatchQuery, [0x0B, 0x05, 0x04, 0x0B, 0x11, 0x13, 0x18, 0x06, 0x1B, 0x1C, 0x27, 0x28])
    static let PktMultiConnectInfo = BuildPacket(CmdMultiConnectInfo)

    static let SupportedBrands = ["OPPO", "OnePlus", "realme"]

    static func LegacyAncSwap(_ mode: AncMode) -> AncMode {
        switch mode {
        case .off:
            .smart
        case .smart, .light, .medium, .deep:
            .off
        default:
            mode
        }
    }

    static func PktAncMode(_ mode: AncMode, isLegacy: Bool = false) -> [UInt8] {
        if isLegacy {
            switch mode {
            case .off:
                return BuildPacket(CmdAnc, AncOffLegacy)
            case .smart, .light, .medium, .deep:
                return BuildPacket(CmdAnc, AncOff)
            case .transparency:
                return BuildPacket(CmdAnc, AncTransparency)
            case .adaptive:
                return BuildPacket(CmdAnc, AncAdaptive)
            case .unknown:
                return PktBattery
            }
        }
        switch mode {
        case .off:
            return BuildPacket(CmdAnc, AncOff)
        case .smart:
            return BuildPacket(CmdAnc, AncSmart)
        case .light:
            return BuildPacket(CmdAnc, AncLight)
        case .medium:
            return BuildPacket(CmdAnc, AncMedium)
        case .deep:
            return BuildPacket(CmdAnc, AncDeep)
        case .adaptive:
            return BuildPacket(CmdAnc, AncAdaptive)
        case .transparency:
            return BuildPacket(CmdAnc, AncTransparency)
        case .unknown:
            return PktBattery
        }
    }

    static func PktSpatialAudio(_ mode: SpatialAudioMode) -> [UInt8] {
        switch mode {
        case .fixed:
            BuildPacket(CmdSpatialAudio, SpatialFixed)
        case .tracking:
            BuildPacket(CmdSpatialAudio, SpatialTrack)
        case .off:
            BuildPacket(CmdSpatialAudio, SpatialOff)
        }
    }
}
