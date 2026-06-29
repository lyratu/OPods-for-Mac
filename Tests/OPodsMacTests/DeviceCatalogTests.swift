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

    func testFeatureDisplayCatalogMapsConfigKeysToExistingModes() {
        let catalog = FeatureDisplayCatalog.shared

        XCTAssertEqual(catalog.controlGroupTitle("noise", language: .chinese), "降噪控制")
        XCTAssertEqual(catalog.featureTitle("eqPreset", language: .english), "EQ preset")
        XCTAssertEqual(catalog.ancMode(forModeType: 10), .adaptive)
        XCTAssertEqual(catalog.ancMode(forModeType: 4), .light)
        XCTAssertEqual(catalog.ancModeTitle(.transparency, language: .chinese), "通透")
        XCTAssertEqual(catalog.spatialAudioTitle(.tracking, language: .chinese), "头部追踪")
    }

    func testCapabilityItemsFollowDisplayConfigOrderAndNames() {
        let caps = DeviceCapabilities.Detect("OPPO Enco Air4s")
        let items = FeatureDisplayCatalog.shared.capabilityItems(for: caps, language: .english)

        XCTAssertEqual(items.map(\.id), [
            "noiseControl",
            "ancLevel",
            "adaptiveAnc",
            "spatialSound",
            "spatialAudioModes",
            "dualDevice",
            "eqPreset",
            "gameMode"
        ])
        XCTAssertEqual(items.first(where: { $0.id == "noiseControl" })?.title, "Noise Control")
        XCTAssertEqual(items.first(where: { $0.id == "ancLevel" })?.enabled, false)
        XCTAssertEqual(items.first(where: { $0.id == "spatialSound" })?.enabled, true)
        XCTAssertEqual(items.first(where: { $0.id == "eqPreset" })?.enabled, true)
    }

    func testAncOptionsFollowImportedDeviceMatrix() {
        let air4s = DeviceCapabilities.Detect("OPPO Enco Air4s")
        XCTAssertEqual(air4s.availableAncMainModes, [.off, .transparency, .smart])
        XCTAssertFalse(air4s.hasAdaptiveAnc)
        XCTAssertTrue(air4s.availableAncSubModes.isEmpty)

        let free4 = DeviceCapabilities.ForceModel("OPPO Enco Free4")
        XCTAssertEqual(free4.availableAncMainModes, [.off, .adaptive, .transparency, .smart])
        XCTAssertTrue(free4.hasAdaptiveAnc)
        XCTAssertEqual(free4.availableAncSubModes, [.smart, .light, .medium, .deep])
    }

    func testEqOptionsUseConfiguredCollectionsNamesAndOrder() {
        let air4s = DeviceCapabilities.Detect("OPPO Enco Air4s")
        XCTAssertEqual(air4s.eqOptions.map(\.name), ["均衡（默认）", "深海低音", "明快清亮"])
        XCTAssertEqual(air4s.eqPresets["深海低音"], 1)

        let free4 = DeviceCapabilities.ForceModel("OPPO Enco Free4")
        XCTAssertEqual(free4.eqOptions.map(\.name), ["至臻原音", "纯享人声", "澎湃低音", "活力动感"])
        XCTAssertEqual(free4.eqPresets["活力动感"], 7)
    }
}
