import Testing
import Foundation
@testable import TimeTrackerCore

struct OnCallBillingTests {

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)!
    }

    private func session(on date: Date, startMinute: Int, durationMinutes: Int,
                         isOnCallActive: Bool) -> TimeSession {
        let start = Calendar.current.startOfDay(for: date)
            .addingTimeInterval(TimeInterval(startMinute * 60))
        return TimeSession(startDate: start, duration: durationMinutes * 60,
                           isOnCallActive: isOnCallActive)
    }

    private func rangesEqual(_ a: [(Int, Int)], _ b: [(Int, Int)]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { $0 == $1 }
    }

    private var weekdayAllDayBlock: OnCallRotationBlock {
        OnCallRotationBlock(
            startDate: date(2026, 6, 1),
            endDate: date(2026, 6, 7),
            schedules: [DaySchedule(daysOfWeek: [2, 3, 4, 5, 6], startMinute: 0, endMinute: 1440)]
        )
    }

    private var nonBillableWeekdayRule: NonBillableRule {
        NonBillableRule(daysOfWeek: [2, 3, 4, 5, 6], startMinute: 480, endMinute: 1080)
    }

    // MARK: - mergeRanges

    @Test func mergeRanges_noOverlap() {
        let result = OnCallBilling.mergeRanges([(0, 100), (200, 300)])
        #expect(result.count == 2)
    }

    @Test func mergeRanges_overlap() {
        let result = OnCallBilling.mergeRanges([(0, 200), (100, 300)])
        #expect(rangesEqual(result, [(0, 300)]))
    }

    @Test func mergeRanges_adjacent() {
        let result = OnCallBilling.mergeRanges([(0, 100), (100, 200)])
        #expect(rangesEqual(result, [(0, 200)]))
    }

    // MARK: - subtractRanges

    @Test func subtractRanges_fullCover() {
        let result = OnCallBilling.subtractRanges([(0, 100)], subtract: [(0, 100)])
        #expect(result.isEmpty)
    }

    @Test func subtractRanges_partialStart() {
        let result = OnCallBilling.subtractRanges([(0, 100)], subtract: [(0, 50)])
        #expect(rangesEqual(result, [(50, 100)]))
    }

    @Test func subtractRanges_partialEnd() {
        let result = OnCallBilling.subtractRanges([(0, 100)], subtract: [(50, 100)])
        #expect(rangesEqual(result, [(0, 50)]))
    }

    @Test func subtractRanges_middle() {
        let result = OnCallBilling.subtractRanges([(0, 300)], subtract: [(100, 200)])
        #expect(rangesEqual(result, [(0, 100), (200, 300)]))
    }

    // MARK: - billableMinutes

    @Test func billableMinutes_noRotation() {
        #expect(OnCallBilling.billableMinutes(on: date(2026, 6, 2), rotations: [], settings: OnCallSettings()) == 0)
    }

    @Test func billableMinutes_outsideDateRange() {
        let rotation = OnCallRotationBlock(
            startDate: date(2026, 6, 1), endDate: date(2026, 6, 7),
            schedules: [DaySchedule(daysOfWeek: [2], startMinute: 0, endMinute: 480)]
        )
        #expect(OnCallBilling.billableMinutes(on: date(2026, 6, 8), rotations: [rotation], settings: OnCallSettings()) == 0)
    }

    @Test func billableMinutes_weekdayMinusNonBillable() {
        // All day (1440) minus 8am–6pm (600) = 840 min billable
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        // June 2 2026 = Tuesday (weekday 3)
        #expect(OnCallBilling.billableMinutes(on: date(2026, 6, 2), rotations: [weekdayAllDayBlock], settings: settings) == 840)
    }

    @Test func billableMinutes_weekendFullDay() {
        let satRotation = OnCallRotationBlock(
            startDate: date(2026, 6, 6), endDate: date(2026, 6, 7),
            schedules: [DaySchedule(daysOfWeek: [7], startMinute: 0, endMinute: 1440)]
        )
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        // June 6 2026 = Saturday (weekday 7) — no non-billable rule for Sat
        #expect(OnCallBilling.billableMinutes(on: date(2026, 6, 6), rotations: [satRotation], settings: settings) == 1440)
    }

    // MARK: - activeMinutesWithinBillable

    @Test func activeMinutes_noOnCallSessions() {
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        let s = session(on: date(2026, 6, 2), startMinute: 0, durationMinutes: 60, isOnCallActive: false)
        #expect(OnCallBilling.activeMinutesWithinBillable(on: date(2026, 6, 2), sessions: [s],
                                                          rotations: [weekdayAllDayBlock], settings: settings) == 0)
    }

    @Test func activeMinutes_sessionFullyInsideBillable() {
        // Billable on Tue: 0–480 and 1080–1440. Session 0–60 is inside billable.
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        let s = session(on: date(2026, 6, 2), startMinute: 0, durationMinutes: 60, isOnCallActive: true)
        #expect(OnCallBilling.activeMinutesWithinBillable(on: date(2026, 6, 2), sessions: [s],
                                                          rotations: [weekdayAllDayBlock], settings: settings) == 60)
    }

    @Test func activeMinutes_sessionClippedAtBillableBoundary() {
        // Billable ends at 480. Session 420–540 clips to 420–480 = 60 min.
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        let s = session(on: date(2026, 6, 2), startMinute: 420, durationMinutes: 120, isOnCallActive: true)
        #expect(OnCallBilling.activeMinutesWithinBillable(on: date(2026, 6, 2), sessions: [s],
                                                          rotations: [weekdayAllDayBlock], settings: settings) == 60)
    }

    @Test func activeMinutes_sessionInsideNonBillable() {
        // Session during 8am–6pm (non-billable) → 0 active minutes
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        let s = session(on: date(2026, 6, 2), startMinute: 540, durationMinutes: 60, isOnCallActive: true)
        #expect(OnCallBilling.activeMinutesWithinBillable(on: date(2026, 6, 2), sessions: [s],
                                                          rotations: [weekdayAllDayBlock], settings: settings) == 0)
    }

    // MARK: - passiveMinutes

    @Test func passiveMinutes_noActiveSessions() {
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        #expect(OnCallBilling.passiveMinutes(on: date(2026, 6, 2), sessions: [],
                                             rotations: [weekdayAllDayBlock], settings: settings) == 840)
    }

    @Test func passiveMinutes_reducedByActive() {
        let settings = OnCallSettings(nonBillableRules: [nonBillableWeekdayRule])
        let s = session(on: date(2026, 6, 2), startMinute: 0, durationMinutes: 60, isOnCallActive: true)
        #expect(OnCallBilling.passiveMinutes(on: date(2026, 6, 2), sessions: [s],
                                             rotations: [weekdayAllDayBlock], settings: settings) == 780)
    }

    // MARK: - rate

    @Test func rate_noHistory() {
        #expect(OnCallBilling.rate(on: date(2026, 6, 2), settings: OnCallSettings()) == nil)
    }

    @Test func rate_singleEntry() {
        let entry = RateEntry(effectiveFrom: date(2026, 1, 1), rate: 100)
        let settings = OnCallSettings(rateHistory: [entry])
        #expect(OnCallBilling.rate(on: date(2026, 6, 2), settings: settings) == 100)
    }

    @Test func rate_beforeFirstEntry() {
        let entry = RateEntry(effectiveFrom: date(2026, 6, 1), rate: 100)
        let settings = OnCallSettings(rateHistory: [entry])
        #expect(OnCallBilling.rate(on: date(2026, 5, 31), settings: settings) == nil)
    }

    @Test func rate_picksLatestApplicable() {
        let e1 = RateEntry(effectiveFrom: date(2026, 1, 1), rate: 50)
        let e2 = RateEntry(effectiveFrom: date(2026, 4, 1), rate: 100)
        let settings = OnCallSettings(rateHistory: [e1, e2])
        #expect(OnCallBilling.rate(on: date(2026, 6, 2), settings: settings) == 100)
        #expect(OnCallBilling.rate(on: date(2026, 3, 31), settings: settings) == 50)
    }

    // MARK: - Income

    @Test func regularIncome_computesHourlyAmount() {
        #expect(OnCallBilling.regularIncome(seconds: 3600, rate: 50) == 50)
        #expect(OnCallBilling.regularIncome(seconds: 1800, rate: 50) == 25)
    }

    @Test func passiveIncome_appliesPassiveMultiplier() {
        let settings = OnCallSettings(passiveMultiplier: 0.4)
        #expect(OnCallBilling.passiveIncome(minutes: 60, rate: 100, settings: settings) == 40)
    }

    @Test func activeIncome_appliesActiveMultiplier() {
        let settings = OnCallSettings(activeMultiplier: 1.0)
        #expect(OnCallBilling.activeIncome(minutes: 60, rate: 100, settings: settings) == 100)
    }

    @Test func onCallIncome_sumsPassiveAndActive() {
        let settings = OnCallSettings(passiveMultiplier: 0.4, activeMultiplier: 1.0)
        let income = OnCallBilling.onCallIncome(passiveMinutes: 60, activeMinutes: 30, rate: 100, settings: settings)
        // passive: 60/60 * 100 * 0.4 = 40; active: 30/60 * 100 * 1.0 = 50
        #expect(income == 90)
    }
}
