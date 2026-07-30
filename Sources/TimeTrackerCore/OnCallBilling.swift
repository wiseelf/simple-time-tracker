import Foundation

public enum OnCallBilling {

    public static func billableMinutes(on date: Date,
                                       rotations: [OnCallRotationBlock],
                                       rules: [RecurrenceRule] = [],
                                       exceptions: [ScheduleException] = [],
                                       settings: OnCallSettings) -> Int {
        billableRangesList(on: date, rotations: rotations, rules: rules,
                           exceptions: exceptions, settings: settings)
            .reduce(0) { $0 + ($1.1 - $1.0) }
    }

    /// Minutes of on-call-active session time, whether or not the session falls inside a
    /// scheduled rotation window — an unscheduled escalation still counts as active on-call
    /// time. Time that overlaps a non-billable rule (e.g. normal working hours) is excluded,
    /// since that time is already compensated by the regular job.
    public static func activeMinutes(on date: Date,
                                      sessions: [TimeSession],
                                      settings: OnCallSettings) -> Int {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: date)
        let nonBillable = settings.nonBillableRules
            .filter { $0.daysOfWeek.contains(weekday) }
            .map    { ($0.startMinute, $0.endMinute) }

        var totalSeconds = 0
        for session in sessions where session.isOnCallActive {
            guard cal.isDate(session.startDate, inSameDayAs: date) else { continue }
            let sStartSec = Int(session.startDate.timeIntervalSince(dayStart))
            let sEndSec   = sStartSec + session.duration
            var sessionSeconds = sEndSec - sStartSec
            for (nbStart, nbEnd) in nonBillable {
                let clippedStart = max(sStartSec, nbStart * 60)
                let clippedEnd   = min(sEndSec,   nbEnd   * 60)
                if clippedEnd > clippedStart { sessionSeconds -= (clippedEnd - clippedStart) }
            }
            totalSeconds += max(0, sessionSeconds)
        }
        return totalSeconds / 60
    }

    public static func passiveMinutes(on date: Date,
                                       sessions: [TimeSession],
                                       rotations: [OnCallRotationBlock],
                                       rules: [RecurrenceRule] = [],
                                       exceptions: [ScheduleException] = [],
                                       settings: OnCallSettings) -> Int {
        let billable = billableMinutes(on: date, rotations: rotations, rules: rules,
                                       exceptions: exceptions, settings: settings)
        let active   = activeMinutes(on: date, sessions: sessions, settings: settings)
        return max(0, billable - active)
    }

    public static func rate(on date: Date, settings: OnCallSettings) -> Double? {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        return settings.rateHistory
            .filter { cal.startOfDay(for: $0.effectiveFrom) <= dayStart }
            .max { cal.startOfDay(for: $0.effectiveFrom) < cal.startOfDay(for: $1.effectiveFrom) }?
            .rate
    }

    // MARK: - Income

    public static func regularIncome(seconds: Int, rate: Double) -> Double {
        Double(seconds) / 3600.0 * rate
    }

    public static func passiveIncome(minutes: Int, rate: Double, settings: OnCallSettings) -> Double {
        Double(minutes) / 60.0 * rate * settings.passiveMultiplier
    }

    public static func activeIncome(minutes: Int, rate: Double, settings: OnCallSettings) -> Double {
        Double(minutes) / 60.0 * rate * settings.activeMultiplier
    }

    public static func onCallIncome(passiveMinutes: Int, activeMinutes: Int,
                                     rate: Double, settings: OnCallSettings) -> Double {
        passiveIncome(minutes: passiveMinutes, rate: rate, settings: settings)
            + activeIncome(minutes: activeMinutes, rate: rate, settings: settings)
    }

    // MARK: - Internal helpers (internal for tests)

    static func billableRangesList(on date: Date,
                                   rotations: [OnCallRotationBlock],
                                   rules: [RecurrenceRule] = [],
                                   exceptions: [ScheduleException] = [],
                                   settings: OnCallSettings) -> [(Int, Int)] {
        let cal = Calendar.current
        let weekday  = cal.component(.weekday, from: date)
        let dayStart = cal.startOfDay(for: date)

        var onCallRanges: [(Int, Int)] = []

        for block in rotations {
            let blockStart = cal.startOfDay(for: block.startDate)
            let blockEnd   = cal.startOfDay(for: block.endDate)
            guard dayStart >= blockStart && dayStart <= blockEnd else { continue }
            for sched in block.schedules where sched.daysOfWeek.contains(weekday) {
                onCallRanges.append((sched.startMinute, sched.endMinute))
            }
        }

        for rule in rules {
            if let window = rule.resolvedWindow(on: date, exceptions: exceptions) {
                onCallRanges.append(window)
            }
        }

        guard !onCallRanges.isEmpty else { return [] }
        let merged = mergeRanges(onCallRanges)
        let nonBillable = settings.nonBillableRules
            .filter { $0.daysOfWeek.contains(weekday) }
            .map    { ($0.startMinute, $0.endMinute) }
        return subtractRanges(merged, subtract: nonBillable)
    }

    static func mergeRanges(_ ranges: [(Int, Int)]) -> [(Int, Int)] {
        let sorted = ranges.sorted { $0.0 < $1.0 }
        var result: [(Int, Int)] = []
        for r in sorted {
            if let last = result.last, r.0 <= last.1 {
                result[result.count - 1] = (last.0, max(last.1, r.1))
            } else {
                result.append(r)
            }
        }
        return result
    }

    static func subtractRanges(_ base: [(Int, Int)], subtract: [(Int, Int)]) -> [(Int, Int)] {
        var result = base
        for sub in subtract {
            result = result.flatMap { (start, end) -> [(Int, Int)] in
                if sub.0 <= start && sub.1 >= end { return [] }
                if sub.1 <= start || sub.0 >= end { return [(start, end)] }
                if sub.0 <= start { return [(sub.1, end)] }
                if sub.1 >= end   { return [(start, sub.0)] }
                return [(start, sub.0), (sub.1, end)]
            }
        }
        return result
    }
}
