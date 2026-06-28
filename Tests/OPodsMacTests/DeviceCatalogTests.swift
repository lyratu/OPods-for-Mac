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
}
