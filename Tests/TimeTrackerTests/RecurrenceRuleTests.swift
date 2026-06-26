import Testing
import Foundation
@testable import TimeTrackerCore

struct RecurrenceRuleTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar.current.date(from: c)!
    }

    // MARK: - dayOfWeek

    @Test func dayOfWeek_matchingDay_returnsWindow() {
        // June 2 2026 = Tuesday (weekday 3)
        let rule = RecurrenceRule(kind: .dayOfWeek(daysOfWeek: [3]),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 480)
        let w = rule.window(on: date(2026, 6, 2))
        #expect(w?.0 == 0 && w?.1 == 480)
    }

    @Test func dayOfWeek_nonMatchingDay_returnsNil() {
        // June 3 2026 = Wednesday (weekday 4)
        let rule = RecurrenceRule(kind: .dayOfWeek(daysOfWeek: [3]),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 480)
        #expect(rule.window(on: date(2026, 6, 3)) == nil)
    }

    // MARK: - intervalDuration

    @Test func interval_onCycleDay_returnsWindow() {
        // every 3 days, 1-day duration; June 1 = day 0 (in), June 4 = day 3 (in)
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        #expect(rule.window(on: date(2026, 6, 1)) != nil)
        #expect(rule.window(on: date(2026, 6, 4)) != nil)
    }

    @Test func interval_betweenCycles_returnsNil() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        #expect(rule.window(on: date(2026, 6, 2)) == nil)
    }

    @Test func interval_multiDayDuration_allDaysInWindow() {
        // 1 week on / 1 week off: interval=14, duration=7
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 14, durationDays: 7),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        for d in 1...7  { #expect(rule.window(on: date(2026, 6, d)) != nil, "day \(d) on") }
        for d in 8...14 { #expect(rule.window(on: date(2026, 6, d)) == nil,  "day \(d) off") }
        #expect(rule.window(on: date(2026, 6, 15)) != nil)
    }

    // MARK: - boundary conditions

    @Test func window_beforeAnchor_returnsNil() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        #expect(rule.window(on: date(2026, 5, 31)) == nil)
    }

    @Test func window_afterEndDate_returnsNil() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), endDate: date(2026, 6, 7),
                                  startMinute: 0, endMinute: 1440)
        #expect(rule.window(on: date(2026, 6, 7)) != nil)
        #expect(rule.window(on: date(2026, 6, 8)) == nil)
    }

    // MARK: - exceptions

    @Test func resolvedWindow_skipException_returnsNil() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        let exc = ScheduleException(date: date(2026, 6, 1), kind: .skip)
        #expect(rule.resolvedWindow(on: date(2026, 6, 1), exceptions: [exc]) == nil)
    }

    @Test func resolvedWindow_overrideException_returnsOverriddenWindow() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 1440)
        let exc = ScheduleException(date: date(2026, 6, 1), kind: .override(startMinute: 480, endMinute: 960))
        let w = rule.resolvedWindow(on: date(2026, 6, 1), exceptions: [exc])
        #expect(w?.0 == 480 && w?.1 == 960)
    }

    @Test func resolvedWindow_noException_usesRuleWindow() {
        let rule = RecurrenceRule(kind: .intervalDuration(intervalDays: 3, durationDays: 1),
                                  anchorDate: date(2026, 6, 1), startMinute: 0, endMinute: 480)
        let w = rule.resolvedWindow(on: date(2026, 6, 1), exceptions: [])
        #expect(w?.0 == 0 && w?.1 == 480)
    }
}
