import Foundation

// MARK: - RecurrenceRuleKind

public enum RecurrenceRuleKind: Codable, Equatable {
    case dayOfWeek(daysOfWeek: [Int])
    case intervalDuration(intervalDays: Int, durationDays: Int)
}

// MARK: - RecurrenceRule

public struct RecurrenceRule: Codable, Identifiable {
    public var id: UUID
    public var kind: RecurrenceRuleKind
    public var anchorDate: Date
    public var endDate: Date?
    public var startMinute: Int
    public var endMinute: Int

    public init(id: UUID = UUID(), kind: RecurrenceRuleKind, anchorDate: Date,
                endDate: Date? = nil, startMinute: Int = 0, endMinute: Int = 1440) {
        self.id = id; self.kind = kind; self.anchorDate = anchorDate
        self.endDate = endDate; self.startMinute = startMinute; self.endMinute = endMinute
    }

    /// Raw on-call window for the date, ignoring exceptions. Nil if not on-call.
    public func window(on date: Date) -> (Int, Int)? {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: anchorDate)
        let d      = cal.startOfDay(for: date)
        guard d >= anchor else { return nil }
        if let end = endDate, d > cal.startOfDay(for: end) { return nil }

        switch kind {
        case .dayOfWeek(let days):
            let weekday = cal.component(.weekday, from: date)
            return days.contains(weekday) ? (startMinute, endMinute) : nil

        case .intervalDuration(let intervalDays, let durationDays):
            let diff = cal.dateComponents([.day], from: anchor, to: d).day ?? 0
            return diff % intervalDays < durationDays ? (startMinute, endMinute) : nil
        }
    }

    /// Effective window after applying exceptions. Nil if not on-call.
    public func resolvedWindow(on date: Date, exceptions: [ScheduleException]) -> (Int, Int)? {
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        if let exc = exceptions.first(where: { cal.startOfDay(for: $0.date) == d }) {
            switch exc.kind {
            case .skip:                           return nil
            case .override(let s, let e):         return (s, e)
            }
        }
        return window(on: date)
    }
}

// MARK: - ScheduleException

public struct ScheduleException: Codable, Identifiable {
    public var id: UUID
    public var date: Date

    public enum ExceptionKind: Codable, Equatable {
        case skip
        case override(startMinute: Int, endMinute: Int)
    }

    public var kind: ExceptionKind

    /// The rule this exception overrides. Nil for exceptions persisted before rule scoping
    /// was introduced — treated as belonging to whichever rule is deleted (see
    /// `OnCallStore.deleteRule`), matching the original unscoped-wipe behavior for old data.
    public var ruleID: UUID?

    public init(id: UUID = UUID(), date: Date, kind: ExceptionKind, ruleID: UUID? = nil) {
        self.id = id; self.date = date; self.kind = kind; self.ruleID = ruleID
    }

    /// True if this exception should be removed when `rule` is deleted — either it
    /// explicitly overrides `rule`, or predates rule-scoping (`ruleID == nil`).
    public func isOwned(by rule: RecurrenceRule) -> Bool {
        ruleID == nil || ruleID == rule.id
    }
}
