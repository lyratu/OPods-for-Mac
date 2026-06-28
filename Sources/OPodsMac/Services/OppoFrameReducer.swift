import Foundation

enum OppoFrameReducer {
    static func apply(_ frame: OppoFrame, to snapshot: inout PodSnapshot, capabilities: DeviceCapabilities) {
        switch frame.command {
        case OppoProtocol.CmdBatteryResp:
            ParseBattery(frame.payload, snapshot: &snapshot)
        case OppoProtocol.CmdAncResp:
            ParseAnc(frame.payload, snapshot: &snapshot, capabilities: capabilities)
        case OppoProtocol.CmdActiveReport:
            ParseActiveReport(frame.payload, snapshot: &snapshot)
        case OppoProtocol.CmdEqResp, OppoProtocol.CmdEqNotify:
            ParseEq(frame.payload, snapshot: &snapshot, capabilities: capabilities)
        case OppoProtocol.CmdBatchQueryResp:
            ParseBatchStatus(frame.payload, snapshot: &snapshot)
        case OppoProtocol.CmdMultiConnectResp:
            ParseMultiConnect(frame.payload, snapshot: &snapshot)
        default:
            break
        }
    }

    private static func ParseBattery(_ payload: [UInt8], snapshot: inout PodSnapshot) {
        var index = 0
        while index + 1 < payload.count {
            if let component = component(for: payload[index]) {
                let raw = payload[index + 1]
                snapshot.battery[component] = BatteryReading(level: Int(raw & 0x7F), charging: (raw & 0x80) != 0)
            }
            index += 2
        }
    }

    private static func ParseAnc(_ payload: [UInt8], snapshot: inout PodSnapshot, capabilities: DeviceCapabilities) {
        guard payload.count >= 3 else {
            print("[OPods] ParseAnc skipped: payload too short (\(payload.count) bytes)")
            return
        }
        for index in 0..<(payload.count - 2) {
            guard payload[index] == 0x01, payload[index + 1] == 0x01 else { continue }
            let first = payload[index + 2]
            let second = index + 3 < payload.count ? payload[index + 3] : 0
            let key = AncResponseKey(first: first, second: second)
            let mapped = capabilities.ancModeMap[key] ?? OppoProtocol.AncValues[key]
            print("[OPods] ANC response key=(\(first), \(second)), mapped=\(mapped?.rawValue ?? "nil")")
            if let mapped, mapped != .unknown {
                snapshot.ancMode = mapped
            }
        }
    }

    private static func ParseActiveReport(_ payload: [UInt8], snapshot: inout PodSnapshot) {
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

    private static func ParseEq(_ payload: [UInt8], snapshot: inout PodSnapshot, capabilities: DeviceCapabilities) {
        guard payload.count >= 2 else { return }
        snapshot.eqPreset = capabilities.eqNames[payload[1]] ?? "Unknown"
    }

    private static func ParseBatchStatus(_ payload: [UInt8], snapshot: inout PodSnapshot) {
        var index = 0
        var gameMain: Bool?
        var gameLowLatency: Bool?
        while index + 1 < payload.count {
            let feature = payload[index]
            let value = payload[index + 1]
            switch feature {
            case OppoProtocol.FeatureGameMain:
                gameMain = value != 0
            case OppoProtocol.FeatureGameLL:
                gameLowLatency = value != 0
            case OppoProtocol.FeatureDualDevice:
                snapshot.dualDevice = value != 0
            case OppoProtocol.FeatureSpatial:
                snapshot.spatialSound = value != 0
            default:
                break
            }
            index += 2
        }

        if gameMain != nil || gameLowLatency != nil {
            snapshot.gameMode = (gameMain ?? false) || (gameLowLatency ?? false)
        }
    }

    private static func ParseMultiConnect(_ payload: [UInt8], snapshot: inout PodSnapshot) {
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
