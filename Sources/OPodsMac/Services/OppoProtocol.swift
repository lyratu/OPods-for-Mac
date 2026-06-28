import Foundation

struct OppoFrame: Equatable {
    var command: UInt16
    var payload: [UInt8]
}

enum OppoProtocol {
    static let header: UInt8 = 0xAA
    static let sequence: UInt8 = 0xF0

    static let oppoSppUUIDBytes: [UInt8] = [
        0x00, 0x00, 0x07, 0x9A,
        0xD1, 0x02, 0x11, 0xE1,
        0x9B, 0x23, 0x00, 0x02,
        0x5B, 0x00, 0xA5, 0xA5
    ]

    static let supportedBrands = ["OPPO", "OnePlus", "realme"]

    enum Command {
        static let battery: UInt16 = 0x0106
        static let batteryResponse: UInt16 = 0x8106
        static let anc: UInt16 = 0x0404
        static let queryAnc: UInt16 = 0x010C
        static let ancResponse: UInt16 = 0x810C
        static let activeReport: UInt16 = 0x0204
        static let setFeature: UInt16 = 0x0403
        static let setEq: UInt16 = 0x0406
        static let queryEq: UInt16 = 0x010F
        static let eqResponse: UInt16 = 0x810F
        static let eqNotify: UInt16 = 0x0504
        static let spatialAudio: UInt16 = 0x0422
        static let registerNotify: UInt16 = 0x0205
        static let batchQuery: UInt16 = 0x010D
        static let batchQueryResponse: UInt16 = 0x810D
        static let multiConnectInfo: UInt16 = 0x0112
        static let multiConnectResponse: UInt16 = 0x8112
        static let operateHandheld: UInt16 = 0x0429
    }

    enum Feature {
        static let spatial: UInt8 = 0x1B
        static let gameMain: UInt8 = 0x28
        static let gameLowLatency: UInt8 = 0x06
        static let dualDevice: UInt8 = 0x11
    }

    static let ancResponseValues: [AncResponseKey: AncMode] = [
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

    static func buildPacket(command: UInt16, payload: [UInt8] = []) -> [UInt8] {
        let totalLength = 7 + payload.count
        var packet = [UInt8](repeating: 0, count: totalLength + 2)
        packet[0] = header
        packet[1] = UInt8(clamping: totalLength)
        packet[2] = 0x00
        packet[3] = 0x00
        packet[4] = UInt8(command & 0x00FF)
        packet[5] = UInt8(command >> 8)
        packet[6] = sequence
        packet[7] = UInt8(payload.count & 0x00FF)
        packet[8] = UInt8(payload.count >> 8)
        packet.replaceSubrange(9..<9 + payload.count, with: payload)
        return packet
    }

    static func buildFeaturePacket(feature: UInt8, enabled: Bool) -> [UInt8] {
        buildPacket(command: Command.setFeature, payload: [feature, enabled ? 0x01 : 0x00])
    }

    static let packetBattery = buildPacket(command: Command.battery)
    static let packetQueryAnc = buildPacket(command: Command.queryAnc, payload: [0x01, 0x01])
    static let packetQueryEq = buildPacket(command: Command.queryEq)
    static let packetRegisterNotify = buildPacket(command: Command.registerNotify, payload: [0x01, 0x01, 0x02, 0x02])
    static let packetBatchQuery = buildPacket(command: Command.batchQuery, payload: [0x0B, 0x05, 0x04, 0x0B, 0x11, 0x13, 0x18, 0x06, 0x1B, 0x1C, 0x27, 0x28])
    static let packetMultiConnectInfo = buildPacket(command: Command.multiConnectInfo)

    static func packetAncMode(_ mode: AncMode) -> [UInt8] {
        switch mode {
        case .off:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x01])
        case .smart:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x80])
        case .light:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x40])
        case .medium:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x20])
        case .deep:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x10])
        case .adaptive:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x00, 0x08])
        case .transparency:
            buildPacket(command: Command.anc, payload: [0x01, 0x01, 0x04])
        case .unknown:
            packetBattery
        }
    }

    static func packetSpatialAudio(_ mode: SpatialAudioMode) -> [UInt8] {
        switch mode {
        case .off:
            buildPacket(command: Command.spatialAudio, payload: [0x00])
        case .fixed:
            buildPacket(command: Command.spatialAudio, payload: [0x01])
        case .tracking:
            buildPacket(command: Command.spatialAudio, payload: [0x02])
        }
    }

    static func legacyAncSwap(_ mode: AncMode) -> AncMode {
        switch mode {
        case .smart, .light, .medium, .deep:
            .transparency
        case .transparency:
            .smart
        default:
            mode
        }
    }
}

final class OppoFrameParser {
    private var buffer: [UInt8] = []

    func append(_ bytes: [UInt8]) -> [OppoFrame] {
        buffer.append(contentsOf: bytes)
        var frames: [OppoFrame] = []

        while let frame = extractFrame() {
            frames.append(frame)
        }

        return frames
    }

    private func extractFrame() -> OppoFrame? {
        guard let start = buffer.firstIndex(of: OppoProtocol.header) else {
            buffer.removeAll()
            return nil
        }

        if start > buffer.startIndex {
            buffer.removeSubrange(buffer.startIndex..<start)
        }

        guard buffer.count >= 2 else { return nil }
        let totalLength = Int(buffer[1])
        let frameLength = totalLength + 2
        guard totalLength >= 7, frameLength <= 512 else {
            buffer.removeFirst()
            return nil
        }
        guard buffer.count >= frameLength else { return nil }

        let raw = Array(buffer.prefix(frameLength))
        buffer.removeFirst(frameLength)

        guard raw.count >= 9 else { return nil }
        let command = UInt16(raw[4]) | (UInt16(raw[5]) << 8)
        let payloadLength = Int(raw[7]) | (Int(raw[8]) << 8)
        guard raw.count >= 9 + payloadLength else { return nil }
        return OppoFrame(command: command, payload: Array(raw[9..<9 + payloadLength]))
    }
}

enum OppoFrameReducer {
    static func apply(_ frame: OppoFrame, to snapshot: inout PodSnapshot, capabilities: DeviceCapabilities) {
        switch frame.command {
        case OppoProtocol.Command.batteryResponse:
            parseBattery(frame.payload, snapshot: &snapshot)
        case OppoProtocol.Command.ancResponse:
            parseAnc(frame.payload, snapshot: &snapshot, capabilities: capabilities)
        case OppoProtocol.Command.activeReport:
            parseActiveReport(frame.payload, snapshot: &snapshot)
        case OppoProtocol.Command.eqResponse, OppoProtocol.Command.eqNotify:
            parseEq(frame.payload, snapshot: &snapshot, capabilities: capabilities)
        case OppoProtocol.Command.batchQueryResponse:
            parseBatchStatus(frame.payload, snapshot: &snapshot)
        case OppoProtocol.Command.multiConnectResponse:
            parseMultiConnect(frame.payload, snapshot: &snapshot)
        default:
            break
        }
    }

    private static func parseBattery(_ payload: [UInt8], snapshot: inout PodSnapshot) {
        var index = 0
        while index + 1 < payload.count {
            if let component = component(for: payload[index]) {
                let raw = payload[index + 1]
                snapshot.battery[component] = BatteryReading(level: Int(raw & 0x7F), charging: (raw & 0x80) != 0)
            }
            index += 2
        }
    }

    private static func parseAnc(_ payload: [UInt8], snapshot: inout PodSnapshot, capabilities: DeviceCapabilities) {
        guard payload.count >= 4 else { return }
        for index in 0..<(payload.count - 3) {
            guard payload[index] == 0x01, payload[index + 1] == 0x01 else { continue }
            let key = AncResponseKey(first: payload[index + 2], second: payload[index + 3])
            let mapped = capabilities.ancModeMap[key] ?? OppoProtocol.ancResponseValues[key]
            if let mapped {
                snapshot.ancMode = capabilities.isLegacyAnc ? OppoProtocol.legacyAncSwap(mapped) : mapped
            }
        }
    }

    private static func parseActiveReport(_ payload: [UInt8], snapshot: inout PodSnapshot) {
        guard payload.count >= 2 else { return }
        let reportType = payload[0]
        let count = Int(payload[1])

        switch reportType {
        case 0x01:
            for item in 0..<count {
                let start = 2 + item * 2
                guard start + 1 < payload.count, let component = component(for: payload[start]) else { continue }
                let raw = payload[start + 1]
                snapshot.battery[component] = BatteryReading(level: Int(raw & 0x7F), charging: (raw & 0x80) != 0)
            }
        case 0x02:
            for item in 0..<count {
                let start = 2 + item * 2
                guard start + 1 < payload.count, let component = component(for: payload[start]) else { continue }
                snapshot.wearing[component] = WearingStatus(protocolValue: payload[start + 1])
            }
        default:
            break
        }
    }

    private static func parseEq(_ payload: [UInt8], snapshot: inout PodSnapshot, capabilities: DeviceCapabilities) {
        guard payload.count >= 2 else { return }
        snapshot.eqPreset = capabilities.eqNames[payload[1]] ?? "Unknown"
    }

    private static func parseBatchStatus(_ payload: [UInt8], snapshot: inout PodSnapshot) {
        var index = 0
        while index + 1 < payload.count {
            let feature = payload[index]
            let value = payload[index + 1]
            switch feature {
            case OppoProtocol.Feature.gameMain:
                snapshot.gameMode = value != 0
            case OppoProtocol.Feature.dualDevice:
                snapshot.dualDevice = value != 0
            case OppoProtocol.Feature.spatial:
                snapshot.spatialSound = value != 0
            default:
                break
            }
            index += 2
        }
    }

    private static func parseMultiConnect(_ payload: [UInt8], snapshot: inout PodSnapshot) {
        guard payload.count >= 2 else { return }
        let count = Int(payload[1])
        guard count > 0, count <= 8 else { return }

        var devices: [ConnectedDeviceInfo] = []
        var position = 2

        for _ in 0..<count {
            guard position + 9 < payload.count else { break }
            let address = payload[position..<position + 6]
                .map { String(format: "%02X", $0) }
                .joined(separator: ":")
            position += 6

            let stateFlags = payload[position]
            position += 1
            let connectionState = Int(payload[position])
            position += 1
            position += 1
            let nameLength = Int(payload[position])
            position += 1
            guard nameLength >= 0, position + nameLength <= payload.count else { break }

            let nameData = Data(payload[position..<position + nameLength])
            let deviceName = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
                ?? "Device \(address.suffix(5))"
            position += nameLength

            devices.append(
                ConnectedDeviceInfo(
                    address: address,
                    deviceName: deviceName.isEmpty ? "Device \(address.suffix(5))" : deviceName,
                    deviceType: 0,
                    connectionState: connectionState,
                    isAudioActive: (stateFlags & 0x02) != 0,
                    isCurrentDevice: (stateFlags & 0x08) != 0,
                    isMainAudioDevice: (stateFlags & 0x04) != 0
                )
            )
        }

        if !devices.isEmpty {
            snapshot.connectedDevices = devices.sorted {
                if $0.isCurrentDevice != $1.isCurrentDevice {
                    return $0.isCurrentDevice
                }
                return $0.deviceName < $1.deviceName
            }
            snapshot.multiConnectUpdatedAt = Date()
        }
    }

    private static func component(for value: UInt8) -> PodComponent? {
        switch value {
        case 1: .left
        case 2: .right
        case 3: .case
        default: nil
        }
    }
}
