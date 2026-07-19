import Testing
import Foundation
@testable import TimeTrackerCore

struct OnCallRotationBlockTests {

    private func day(_ year: Int, _ month: Int, _ d: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = d; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    // MARK: - overlaps(periodStart:periodEnd:)

    @Test func overlaps_rotationFullyInsidePeriod_returnsTrue() {
        let rotation = OnCallRotationBlock(startDate: day(2026, 7, 20), endDate: day(2026, 7, 21), schedules: [])
        #expect(rotation.overlaps(periodStart: day(2026, 7, 19), periodEnd: day(2026, 7, 25)))
    }

    @Test func overlaps_rotationBeforePeriod_returnsFalse() {
        let rotation = OnCallRotationBlock(startDate: day(2026, 7, 1), endDate: day(2026, 7, 2), schedules: [])
        #expect(!rotation.overlaps(periodStart: day(2026, 7, 19), periodEnd: day(2026, 7, 25)))
    }

    @Test func overlaps_rotationAfterPeriod_returnsFalse() {
        let rotation = OnCallRotationBlock(startDate: day(2026, 8, 1), endDate: day(2026, 8, 2), schedules: [])
        #expect(!rotation.overlaps(periodStart: day(2026, 7, 19), periodEnd: day(2026, 7, 25)))
    }

    /// Reproduces the reported bug: a rotation dated for the period's last calendar day,
    /// saved with a real (non-midnight) time-of-day — as RotationEditSheet's date-only
    /// pickers do, since they default to `.now` — must still count as falling within the
    /// period. `periodEnd` here is midnight of the last day (as OnCallSummaryView passes
    /// it), not end-of-day, so the comparison must be by calendar day, not raw instant.
    @Test func overlaps_rotationOnPeriodsLastDayWithNonMidnightTime_returnsTrue() {
        let periodStart = day(2026, 7, 19)
        let periodEnd   = day(2026, 7, 25) // midnight of the last day, not end-of-day
        let rotation = OnCallRotationBlock(
            startDate: day(2026, 7, 25, hour: 14, minute: 32),
            endDate:   day(2026, 7, 25, hour: 14, minute: 32),
            schedules: []
        )
        #expect(rotation.overlaps(periodStart: periodStart, periodEnd: periodEnd))
    }

    @Test func overlaps_rotationOnPeriodsFirstDayWithNonMidnightTime_returnsTrue() {
        let periodStart = day(2026, 7, 19)
        let periodEnd   = day(2026, 7, 25)
        let rotation = OnCallRotationBlock(
            startDate: day(2026, 7, 19, hour: 23, minute: 45),
            endDate:   day(2026, 7, 19, hour: 23, minute: 45),
            schedules: []
        )
        #expect(rotation.overlaps(periodStart: periodStart, periodEnd: periodEnd))
    }
}
