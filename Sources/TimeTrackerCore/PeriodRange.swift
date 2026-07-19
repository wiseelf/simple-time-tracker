import Foundation

/// Computes "this week"/"this month"-style date ranges, offset from the current period.
public enum PeriodRange {
    public enum Period { case week, month }

    /// The half-open date interval for `period`, `offset` periods from the current one
    /// (0 = current, -1 = previous, ...).
    public static func interval(for period: Period, offset: Int,
                                calendar: Calendar = .current) -> DateInterval? {
        let component: Calendar.Component = period == .week ? .weekOfYear : .month
        guard let base  = calendar.dateInterval(of: component, for: .now)?.start,
              let start = calendar.date(byAdding: component, value: offset, to: base),
              let end   = calendar.date(byAdding: component, value: 1, to: start)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Every calendar day in `period`, `offset` periods from the current one.
    public static func days(for period: Period, offset: Int,
                            calendar: Calendar = .current) -> [Date] {
        guard let interval = interval(for: period, offset: offset, calendar: calendar) else { return [] }
        var day = interval.start
        var result: [Date] = []
        while day < interval.end {
            result.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86400)
        }
        return result
    }
}
