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

    // MARK: - calendar

    @Test func calendar_weekStartsOnMonday_usesMondayAsFirstWeekday() {
        let settings = OnCallSettings(weekStartsOnMonday: true)
        #expect(settings.calendar.firstWeekday == 2)
    }

    @Test func calendar_weekStartsOnSunday_usesSundayAsFirstWeekday() {
        let settings = OnCallSettings(weekStartsOnMonday: false)
        #expect(settings.calendar.firstWeekday == 1)
    }

    @Test func calendar_drivesWeekIntervalRegardlessOfSystemLocale() {
        let mondaySettings = OnCallSettings(weekStartsOnMonday: true)
        let sundaySettings = OnCallSettings(weekStartsOnMonday: false)

        let mondayInterval = PeriodRange.interval(for: .week, offset: 0, calendar: mondaySettings.calendar)!
        let sundayInterval = PeriodRange.interval(for: .week, offset: 0, calendar: sundaySettings.calendar)!

        let mondayWeekday = Calendar.current.component(.weekday, from: mondayInterval.start)
        let sundayWeekday = Calendar.current.component(.weekday, from: sundayInterval.start)

        #expect(mondayWeekday == 2) // Monday
        #expect(sundayWeekday == 1) // Sunday
    }
}
