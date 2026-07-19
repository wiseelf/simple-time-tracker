import Testing
import Foundation
@testable import TimeTrackerCore

struct PeriodRangeTests {

    private var calendar: Calendar { Calendar.current }

    // MARK: - interval(for:.week)

    @Test func weekInterval_currentWeek_spansSevenDays() {
        let interval = PeriodRange.interval(for: .week, offset: 0)
        #expect(interval != nil)
        let days = calendar.dateComponents([.day], from: interval!.start, to: interval!.end).day
        #expect(days == 7)
    }

    @Test func weekInterval_offsetMovesByWholeWeeks() {
        let current  = PeriodRange.interval(for: .week, offset: 0)!
        let previous = PeriodRange.interval(for: .week, offset: -1)!
        let days = calendar.dateComponents([.day], from: previous.start, to: current.start).day
        #expect(days == 7)
    }

    // MARK: - interval(for:.month)

    @Test func monthInterval_currentMonth_startsOnFirstDay() {
        let interval = PeriodRange.interval(for: .month, offset: 0)!
        #expect(calendar.component(.day, from: interval.start) == 1)
    }

    @Test func monthInterval_offsetMovesByWholeMonths() {
        let current  = PeriodRange.interval(for: .month, offset: 0)!
        let previous = PeriodRange.interval(for: .month, offset: -1)!
        #expect(previous.end == current.start)
    }

    // MARK: - days(for:)

    @Test func days_week_returnsSevenDates() {
        #expect(PeriodRange.days(for: .week, offset: 0).count == 7)
    }

    @Test func days_month_returnsOneDatePerCalendarDay() {
        let interval = PeriodRange.interval(for: .month, offset: 0)!
        let expectedCount = calendar.dateComponents([.day], from: interval.start, to: interval.end).day!
        #expect(PeriodRange.days(for: .month, offset: 0).count == expectedCount)
    }

    @Test func days_areConsecutiveCalendarDays() {
        let days = PeriodRange.days(for: .week, offset: 0)
        for i in 1..<days.count {
            let delta = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day
            #expect(delta == 1)
        }
    }
}
