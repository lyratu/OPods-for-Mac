import Foundation
import IOBluetooth
import IOKit

enum PodsServiceEvent {
    case connected(deviceName: String, capabilities: DeviceCapabilities, snapshot: PodSnapshot)
    case snapshot(PodSnapshot)
    case disconnected(String?)
    case error(String)
}

enum PodsServiceError: LocalizedError {
    case noPairedDevices
    case deviceNotFound
    case rfcommOpenFailed([String])
    case writeFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .noPairedDevices:
            "No paired Bluetooth devices were found. Pair the earbuds in macOS Bluetooth settings first."
        case .deviceNotFound:
            "Could not find the selected Bluetooth device."
        case .rfcommOpenFailed(let attempts):
            "Could not open OPPO RFCOMM channel. Tried \(attempts.joined(separator: ", "))."
        case .writeFailed(let status):
            "Bluetooth write failed with IOReturn \(status)."
        }
    }
}

final class RfcommService: NSObject, IOBluetoothRFCOMMChannelDelegate, @unchecked Sendable {
    var onEvent: ((PodsServiceEvent) -> Void)?

    private let queue = DispatchQueue(label: "com.kelonl.OPodsMac.bluetooth")
    private let parser = OppoFrameParser()
    private var channel: IOBluetoothRFCOMMChannel?
    private var device: IOBluetoothDevice?
    private var capabilities = DeviceCapabilities.fallback
    private var snapshot = PodSnapshot()
    private var pollTimer: DispatchSourceTimer?
    private var pollTick = 0
    private var connectedAt = Date.distantPast
    private var lastEmittedSnapshot = PodSnapshot()
    private var wokeAt = Date.distantPast
    private let rfcommRetryDelays: [TimeInterval] = [0, 0.8, 1.6]

    func pairedDevices() -> [BluetoothDeviceCandidate] {
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return devices.compactMap { device in
            guard let address = device.addressString else { return nil }
            let name = device.nameOrAddress ?? address
            return BluetoothDeviceCandidate(
                address: address,
                name: name,
                likelySupported: DeviceCatalog.shared.likelySupported(deviceName: name),
                isSystemConnected: device.isConnected()
            )
        }
        .sorted {
            let lhsPriority = deviceListPriority($0)
            let rhsPriority = deviceListPriority($1)
            if lhsPriority != rhsPriority {
                return lhsPriority > rhsPriority
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func connect(to candidate: BluetoothDeviceCandidate?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.connectLocked(to: candidate)
                    continuation.resume()
                } catch {
                    self.emit(.error(error.localizedDescription))
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func disconnect() {
        queue.async {
            self.disconnectLocked(reason: nil)
        }
    }

    func sendAnc(_ mode: AncMode, capabilities: DeviceCapabilities) {
        send(OppoProtocol.PktAncMode(mode, isLegacy: capabilities.isLegacyAnc))
    }

    func sendSpatialSound(_ enabled: Bool) {
        send(OppoProtocol.BuildFeaturePacket(OppoProtocol.FeatureSpatial, enabled))
    }

    func sendSpatialAudio(_ mode: SpatialAudioMode) {
        send(OppoProtocol.PktSpatialAudio(mode))
    }

    func sendDualDevice(_ enabled: Bool) {
        send(OppoProtocol.BuildFeaturePacket(OppoProtocol.FeatureDualDevice, enabled))
    }

    func sendGameMode(_ enabled: Bool, compatible: Bool) {
        send(OppoProtocol.BuildFeaturePacket(OppoProtocol.FeatureGameMain, enabled))
        if compatible {
            send(OppoProtocol.BuildFeaturePacket(OppoProtocol.FeatureGameLL, enabled))
        }
    }

    func sendEqPreset(_ name: String, capabilities: DeviceCapabilities) {
        guard let identifier = capabilities.eqPresets[name] else { return }
        send(OppoProtocol.BuildPacket(OppoProtocol.CmdSetEq, [identifier]))
    }

    func refreshMultiConnectInfo() {
        send(OppoProtocol.PktMultiConnectInfo)
    }

    func refreshNow() {
        wokeAt = Date()
        queue.async { [weak self] in
            guard let self, self.snapshot.connected else { return }
            self.sendSilentlyLocked(OppoProtocol.PktBattery)
            self.sendSilentlyLocked(OppoProtocol.PktQueryAnc)
            self.sendSilentlyLocked(OppoProtocol.PktBatchQuery)
            self.sendSilentlyLocked(OppoProtocol.PktQueryEq)
        }
    }

    func operateHandheld(address: String, connect: Bool) {
        let bytes = address.split(separator: ":").compactMap { UInt8($0, radix: 16) }
        guard bytes.count == 6 else { return }
        send(OppoProtocol.BuildPacket(OppoProtocol.CmdOperateHandheld, [connect ? 0x01 : 0x00] + bytes))
    }

    private func connectLocked(to candidate: BluetoothDeviceCandidate?) throws {
        disconnectLocked(reason: nil, emitEvent: false)

        let selectedDevice = try resolveDevice(candidate)
        let deviceName = selectedDevice.nameOrAddress ?? selectedDevice.addressString ?? "OPPO earbuds"
        capabilities = DeviceCapabilities.Detect(deviceName)

        var failures: [String] = []
        for (attempt, delay) in rfcommRetryDelays.enumerated() {
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }

            if !selectedDevice.isConnected() {
                _ = selectedDevice.openConnection()
                Thread.sleep(forTimeInterval: 0.25)
            }

            var attemptFailures: [String] = []
            for channelID in channelIDs(for: selectedDevice) {
                var openedChannel: IOBluetoothRFCOMMChannel?
                let result = selectedDevice.openRFCOMMChannelSync(&openedChannel, withChannelID: channelID, delegate: self)
                if result == kIOReturnSuccess, let openedChannel {
                    device = selectedDevice
                    channel = openedChannel
                    snapshot = PodSnapshot()
                    snapshot.connected = true
                    snapshot.connectedDeviceName = deviceName
                    snapshot.connectedDeviceAddress = selectedDevice.addressString ?? ""
                    connectedAt = Date()
                    lastEmittedSnapshot = snapshot
                    emit(.connected(deviceName: deviceName, capabilities: capabilities, snapshot: snapshot))
                    sendStartupQueriesLocked()
                    startPollingLocked()
                    return
                }
                attemptFailures.append("attempt \(attempt + 1) channel \(channelID): \(result)")
            }
            failures = attemptFailures
        }

        throw PodsServiceError.rfcommOpenFailed(failures)
    }

    private func resolveDevice(_ candidate: BluetoothDeviceCandidate?) throws -> IOBluetoothDevice {
        if let candidate {
            guard let selected = IOBluetoothDevice(addressString: candidate.address) else {
                throw PodsServiceError.deviceNotFound
            }
            return selected
        }

        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        guard !devices.isEmpty else { throw PodsServiceError.noPairedDevices }

        let sortedDevices = devices.sorted {
            let lhs = bluetoothDevicePriority($0)
            let rhs = bluetoothDevicePriority($1)
            if lhs != rhs {
                return lhs > rhs
            }
            let lhsName = $0.nameOrAddress ?? $0.addressString ?? ""
            let rhsName = $1.nameOrAddress ?? $1.addressString ?? ""
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }

        if let supported = sortedDevices.first(where: { device in
            let name = device.nameOrAddress ?? device.addressString ?? ""
            return DeviceCatalog.shared.likelySupported(deviceName: name)
        }) {
            return supported
        }

        return sortedDevices[0]
    }

    private func deviceListPriority(_ device: BluetoothDeviceCandidate) -> Int {
        (device.likelySupported ? 2 : 0) + (device.isSystemConnected ? 1 : 0)
    }

    private func bluetoothDevicePriority(_ device: IOBluetoothDevice) -> Int {
        let name = device.nameOrAddress ?? device.addressString ?? ""
        let likelySupported = DeviceCatalog.shared.likelySupported(deviceName: name)
        return (likelySupported ? 2 : 0) + (device.isConnected() ? 1 : 0)
    }

    private func channelIDs(for device: IOBluetoothDevice) -> [BluetoothRFCOMMChannelID] {
        var ids: [BluetoothRFCOMMChannelID] = []

        if let uuid = oppoSppUUID(),
           let service = device.getServiceRecord(for: uuid) {
            var serviceChannel = BluetoothRFCOMMChannelID(0)
            if service.getRFCOMMChannelID(&serviceChannel) == kIOReturnSuccess, serviceChannel > 0 {
                ids.append(serviceChannel)
            }
        }

        ids.append(15)
        ids.append(1)

        var seen = Set<BluetoothRFCOMMChannelID>()
        return ids.filter { seen.insert($0).inserted }
    }

    private func oppoSppUUID() -> IOBluetoothSDPUUID? {
        let data = Data(OppoProtocol.OppoSppUuidBytes)
        return data.withUnsafeBytes { pointer -> IOBluetoothSDPUUID? in
            guard let baseAddress = pointer.baseAddress else { return nil }
            return IOBluetoothSDPUUID(bytes: baseAddress, length: OppoProtocol.OppoSppUuidBytes.count)
        }
    }

    private func sendStartupQueriesLocked() {
        let startupPackets: [[UInt8]] = [
            OppoProtocol.PktBatchQuery,
            OppoProtocol.PktBattery,
            OppoProtocol.PktQueryAnc,
            OppoProtocol.PktQueryEq,
            OppoProtocol.PktRegisterNotify,
            OppoProtocol.PktMultiConnectInfo
        ]

        for (offset, packet) in startupPackets.enumerated() {
            queue.asyncAfter(deadline: .now() + .milliseconds(80 * offset)) { [weak self] in
                do {
                    try self?.sendLocked(packet)
                } catch {
                    self?.emit(.error(error.localizedDescription))
                }
            }
        }
    }

    private func startPollingLocked() {
        pollTimer?.cancel()
        pollTick = 0
        scheduleNextPoll()
    }

    private func scheduleNextPoll() {
        let stableElapsed = Date().timeIntervalSince(connectedAt)
        let wokeElapsed = Date().timeIntervalSince(wokeAt)
        let interval: TimeInterval = (stableElapsed < 30 || wokeElapsed < 30) ? 5 : 30

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            self?.pollLocked()
        }
        timer.resume()
        pollTimer = timer
    }

    private func pollLocked() {
        guard snapshot.connected else { return }
        pollTick += 1
        let elapsed = Date().timeIntervalSince(connectedAt)
        let isStable = elapsed >= 30

        sendSilentlyLocked(OppoProtocol.PktBattery)
        sendSilentlyLocked(OppoProtocol.PktQueryAnc)

        if !isStable || pollTick % 2 == 0 {
            sendSilentlyLocked(OppoProtocol.PktBatchQuery)
        }

        if !isStable || pollTick % 3 == 0 {
            sendSilentlyLocked(OppoProtocol.PktQueryEq)
        }

        if !isStable {
            sendSilentlyLocked(OppoProtocol.PktMultiConnectInfo)
        }

        scheduleNextPoll()
    }

    private func send(_ packet: [UInt8]) {
        queue.async {
            do {
                try self.sendLocked(packet)
            } catch {
                self.emit(.error(error.localizedDescription))
            }
        }
    }

    private func sendSilentlyLocked(_ packet: [UInt8]) {
        do {
            try sendLocked(packet)
        } catch {
            disconnectLocked(reason: error.localizedDescription)
        }
    }

    private func sendLocked(_ packet: [UInt8]) throws {
        guard let channel else { throw PodsServiceError.writeFailed(kIOReturnNotOpen) }
        var data = packet
        let length = UInt16(data.count)
        let result = data.withUnsafeMutableBytes { pointer in
            channel.writeSync(pointer.baseAddress, length: length)
        }
        guard result == kIOReturnSuccess else {
            throw PodsServiceError.writeFailed(result)
        }
    }

    private func disconnectLocked(reason: String?, emitEvent: Bool = true) {
        pollTimer?.cancel()
        pollTimer = nil

        if let channel {
            _ = channel.close()
        }

        channel = nil
        device = nil
        snapshot.connected = false

        if emitEvent {
            emit(.disconnected(reason))
        }
    }

    private func emit(_ event: PodsServiceEvent) {
        onEvent?(event)
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard let dataPointer, dataLength > 0 else { return }
        let bytes = Array(UnsafeBufferPointer(start: dataPointer.assumingMemoryBound(to: UInt8.self), count: dataLength))
        queue.async {
            let frames = self.parser.append(bytes)
            for frame in frames {
                OppoFrameReducer.apply(frame, to: &self.snapshot, capabilities: self.capabilities)
            }
            if self.snapshot != self.lastEmittedSnapshot {
                self.lastEmittedSnapshot = self.snapshot
                self.emit(.snapshot(self.snapshot))
            }
        }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        queue.async {
            self.disconnectLocked(reason: "Bluetooth channel closed")
        }
    }
}
