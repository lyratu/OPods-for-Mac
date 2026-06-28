import XCTest
@testable import OPodsMac

final class DeviceCatalogTests: XCTestCase {
    func testCatalogLoadsDeviceMatrix() {
        XCTAssertGreaterThan(DeviceCapabilities.GetModelNames().count, 100)
    }

    func testDetectsKnownModelFromBluetoothName() {
        let caps = DeviceCapabilities.Detect("OPPO Enco Air4s")

        XCTAssertEqual(caps.modelName, "OPPO Enco Air4s")
        XCTAssertTrue(caps.hasDualDevice)
        XCTAssertFalse(caps.eqPresets.isEmpty)
    }

    func testAncOptionsFollowImportedDeviceMatrix() {
        let air4s = DeviceCapabilities.Detect("OPPO Enco Air4s")
        XCTAssertEqual(air4s.availableAncMainModes, [.off, .transparency, .smart])
        XCTAssertFalse(air4s.hasAdaptiveAnc)
        XCTAssertTrue(air4s.availableAncSubModes.isEmpty)

        let free4 = DeviceCapabilities.Detect("OPPO Enco Free4")
        XCTAssertEqual(free4.availableAncMainModes, [.off, .adaptive, .transparency, .smart])
        XCTAssertTrue(free4.hasAdaptiveAnc)
        XCTAssertEqual(free4.availableAncSubModes, [.smart, .light, .medium, .deep])
    }
}
