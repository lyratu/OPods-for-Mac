import Foundation

struct OppoFrame: Equatable {
    var command: UInt16
    var payload: [UInt8]
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
        guard let start = buffer.firstIndex(of: OppoProtocol.Header) else {
            buffer.removeAll()
            return nil
        }

        if start > buffer.startIndex {
            buffer.removeSubrange(buffer.startIndex..<start)
        }

        guard buffer.count >= 2 else { return nil }
        let totalLen = Int(buffer[1])
        let frameLen = totalLen + 2
        guard totalLen >= 7, frameLen <= 512 else {
            buffer.removeFirst()
            return nil
        }
        guard buffer.count >= frameLen else { return nil }

        let pkt = Array(buffer.prefix(frameLen))
        buffer.removeFirst(frameLen)

        guard pkt.count >= 9 else { return nil }
        let cmd = UInt16(pkt[4]) | (UInt16(pkt[5]) << 8)
        let payLen = Int(pkt[7]) | (Int(pkt[8]) << 8)
        guard pkt.count >= 9 + payLen else { return nil }
        return OppoFrame(command: cmd, payload: Array(pkt[9..<9 + payLen]))
    }
}
