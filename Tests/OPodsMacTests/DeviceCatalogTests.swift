import XCTest
@testable import OPodsMac

final class DeviceCatalogTests: XCTestCase {
    func testCatalogLoadsDeviceMatrix() {
        XCTAssertGreaterThan(DeviceCatalog.shared.modelNames.count, 100)
    }

    func testDetectsKnownModelFromBluetoothName() {
        let caps = DeviceCatalog.shared.detect(deviceName: "OPPO Enco Air4s")

        XCTAssertEqual(caps.modelName, "OPPO Enco Air4s")
        XCTAssertTrue(caps.hasDualDevice)
        XCTAssertFalse(caps.eqPresets.isEmpty)
    }
}
