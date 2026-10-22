import Foundation
import PalmGuardCore
import Testing

@testable import PalmGuard

@Suite("Retire native click filtering without losing calibration")
struct SettingsMigrationTests {
    @Test(arguments: ["filterClicks", "deliberateTaps"])
    func preservesAreaFromBothLegacyModes(mode: String) throws {
        var oldSettings = AppSettings()
        oldSettings.configuration.area = TapArea(minX: 0.22, minY: 0.11, maxX: 0.88, maxY: 0.69)
        let encoded = try JSONEncoder().encode(oldSettings)
        var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy["mode"] = mode
        let loaded = SettingsStore.decode(try JSONSerialization.data(withJSONObject: legacy))
        #expect(loaded.configuration.area == oldSettings.configuration.area)
        #expect(!loaded.nativeTapsDisabledConfirmed)
        let newData = try JSONEncoder().encode(loaded)
        let saved = try #require(JSONSerialization.jsonObject(with: newData) as? [String: Any])
        #expect(saved["mode"] == nil)
    }
}
