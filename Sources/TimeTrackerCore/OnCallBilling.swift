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

    public static func activeMinutesWithinBillable(on date: Date,
                                                    sessions: [TimeSession],
                                                    rotations: [OnCallRotationBlock],
                                                    rules: [RecurrenceRule] = [],
                                                    exceptions: [ScheduleException] = [],
                                                    settings: OnCallSettings) -> Int {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let billableRanges = billableRangesList(on: date, rotations: rotations, rules: rules,
                                                exceptions: exceptions, settings: settings)
        guard !billableRanges.isEmpty else { return 0 }

        var total = 0
        for session in sessions where session.isOnCallActive {
            guard cal.isDate(session.startDate, inSameDayAs: date) else { continue }
            let sStart = Int(session.startDate.timeIntervalSince(dayStart) / 60)
            let sEnd   = sStart + session.duration / 60
            for (bStart, bEnd) in billableRanges {
                let clippedStart = max(sStart, bStart)
                let clippedEnd   = min(sEnd, bEnd)
                if clippedEnd > clippedStart { total += clippedEnd - clippedStart }
            }
        }
        return total
    }

    public static func passiveMinutes(on date: Date,
                                       sessions: [TimeSession],
                                       rotations: [OnCallRotationBlock],
                                       rules: [RecurrenceRule] = [],
                                       exceptions: [ScheduleException] = [],
                                       settings: OnCallSettings) -> Int {
        let billable = billableMinutes(on: date, rotations: rotations, rules: rules,
                                       exceptions: exceptions, settings: settings)
        let active   = activeMinutesWithinBillable(on: date, sessions: sessions,
                                                   rotations: rotations, rules: rules,
                                                   exceptions: exceptions, settings: settings)
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
