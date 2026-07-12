import Testing
import Foundation
@testable import TimeTrackerCore

struct OnCallSettingsTests {

    @Test func hideFromScreenCapture_defaultsToTrue() {
        let settings = OnCallSettings()
        #expect(settings.hideFromScreenCapture == true)
    }

    @Test func hideFromScreenCapture_roundTripsThroughCodable() throws {
        let settings = OnCallSettings(hideFromScreenCapture: false)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(OnCallSettings.self, from: data)
        #expect(decoded.hideFromScreenCapture == false)
    }

    @Test func hideFromScreenCapture_decodingOldDataDefaultsToTrue() throws {
        // Simulates settings JSON persisted before this field existed.
        let json = """
        {
            "incomeTrackingEnabled": false,
            "passiveMultiplier": 0.4,
            "activeMultiplier": 1.0,
            "nonBillableRules": [],
            "rateHistory": [],
            "currencySymbol": "$",
            "weekStartsOnMonday": false
        }
        """
        let decoded = try JSONDecoder().decode(OnCallSettings.self, from: json.data(using: .utf8)!)
        #expect(decoded.hideFromScreenCapture == true)
    }
}
