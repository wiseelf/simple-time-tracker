import Testing
import Foundation
@testable import TimeTrackerCore

struct RecurrenceBillingTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }

    @Test func billableMinutes_intervalRule_onCycleDay() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        let result = OnCallBilling.billableMinutes(
            on: date(2026, 6, 1), rotations: [], rules: [rule], exceptions: [], settings: OnCallSettings()
        )
        #expect(result == 1440)
    }

    @Test func billableMinutes_intervalRule_betweenCycles() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        let result = OnCallBilling.billableMinutes(
            on: date(2026, 6, 2), rotations: [], rules: [rule], exceptions: [], settings: OnCallSettings()
        )
        #expect(result == 0)
    }

    @Test func billableMinutes_skipException_removesDay() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        let exc = ScheduleException(date: date(2026, 6, 1), kind: .skip)
        let result = OnCallBilling.billableMinutes(
            on: date(2026, 6, 1), rotations: [], rules: [rule], exceptions: [exc], settings: OnCallSettings()
        )
        #expect(result == 0)
    }

    @Test func billableMinutes_overrideException_changesHours() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        let exc = ScheduleException(date: date(2026, 6, 1), kind: .override(startMinute: 0, endMinute: 480))
        let result = OnCallBilling.billableMinutes(
            on: date(2026, 6, 1), rotations: [], rules: [rule], exceptions: [exc], settings: OnCallSettings()
        )
        #expect(result == 480)
    }

    @Test func billableMinutes_ruleAndRotationBlock_merged() {
        // Rule: 0–480; block: 360–720 (overlaps). Merged: 0–720 = 720 min.
        // June 1 2026 = Monday (weekday 2)
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 480)
        let block = OnCallRotationBlock(
            startDate: date(2026, 6, 1), endDate: date(2026, 6, 1),
            schedules: [DaySchedule(daysOfWeek: [2], startMinute: 360, endMinute: 720)]
        )
        let result = OnCallBilling.billableMinutes(
            on: date(2026, 6, 1), rotations: [block], rules: [rule], exceptions: [], settings: OnCallSettings()
        )
        #expect(result == 720)
    }

    @Test func existingBillingCalls_compileWithoutRulesParam() {
        // Existing callers (no rules/exceptions args) must still compile and return same result.
        let block = OnCallRotationBlock(
            startDate: date(2026, 6, 1), endDate: date(2026, 6, 1),
            schedules: [DaySchedule(daysOfWeek: [2], startMinute: 0, endMinute: 480)]
        )
        let result = OnCallBilling.billableMinutes(
            on: date(2026, 6, 1), rotations: [block], settings: OnCallSettings()
        )
        #expect(result == 480)
    }
}
