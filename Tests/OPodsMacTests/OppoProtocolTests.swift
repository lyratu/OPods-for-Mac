import XCTest
@testable import OPodsMac

final class OppoProtocolTests: XCTestCase {
    func testBuildPacketUsesExpectedFrameShape() {
        let packet = OppoProtocol.buildPacket(command: OppoProtocol.Command.battery, payload: [0x01, 0x02])

        XCTAssertEqual(packet[0], 0xAA)
        XCTAssertEqual(packet[1], 9)
        XCTAssertEqual(packet[4], 0x06)
        XCTAssertEqual(packet[5], 0x01)
        XCTAssertEqual(packet[6], 0xF0)
        XCTAssertEqual(packet[7], 2)
        XCTAssertEqual(packet[8], 0)
        XCTAssertEqual(Array(packet.suffix(2)), [0x01, 0x02])
    }

    func testFrameParserHandlesSplitInput() {
        let frame = OppoProtocol.buildPacket(command: OppoProtocol.Command.batteryResponse, payload: [1, 85, 2, 0xC0])
        let parser = OppoFrameParser()

        XCTAssertTrue(parser.append(Array(frame.prefix(4))).isEmpty)
        let parsed = parser.append(Array(frame.dropFirst(4)))

        XCTAssertEqual(parsed, [OppoFrame(command: OppoProtocol.Command.batteryResponse, payload: [1, 85, 2, 0xC0])])
    }

    func testBatteryFrameUpdatesSnapshot() {
        var snapshot = PodSnapshot()
        let frame = OppoFrame(command: OppoProtocol.Command.batteryResponse, payload: [1, 85, 2, 0xC0, 3, 97])

        OppoFrameReducer.apply(frame, to: &snapshot, capabilities: .fallback)

        XCTAssertEqual(snapshot.battery[.left], BatteryReading(level: 85, charging: false))
        XCTAssertEqual(snapshot.battery[.right], BatteryReading(level: 64, charging: true))
        XCTAssertEqual(snapshot.battery[.case], BatteryReading(level: 97, charging: false))
    }
}
