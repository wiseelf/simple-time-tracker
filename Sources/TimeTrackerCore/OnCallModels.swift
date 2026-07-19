import Foundation

public struct DaySchedule: Codable, Identifiable {
    public var id: UUID
    public var daysOfWeek: [Int]   // 1 = Sun … 7 = Sat (Calendar.Component.weekday)
    public var startMinute: Int    // minutes from midnight
    public var endMinute: Int

    public init(id: UUID = UUID(), daysOfWeek: [Int], startMinute: Int, endMinute: Int) {
        self.id = id
        self.daysOfWeek = daysOfWeek
        self.startMinute = startMinute
        self.endMinute = endMinute
    }
}

public struct OnCallRotationBlock: Codable, Identifiable {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date
    public var schedules: [DaySchedule]

    public init(id: UUID = UUID(), startDate: Date, endDate: Date, schedules: [DaySchedule]) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.schedules = schedules
    }

    /// True if this rotation's calendar-day range overlaps [periodStart, periodEnd].
    /// Compares by calendar day rather than raw instant: `startDate`/`endDate` are picked
    /// via a date-only `DatePicker` that preserves whatever time-of-day was already on the
    /// value (typically `.now`'s wall-clock time, not midnight), so a raw `Date` comparison
    /// against a period boundary that's midnight of its last day would wrongly exclude a
    /// rotation that lands on that exact day.
    public func overlaps(periodStart: Date, periodEnd: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: startDate) <= calendar.startOfDay(for: periodEnd)
            && calendar.startOfDay(for: endDate) >= calendar.startOfDay(for: periodStart)
    }
}

public struct NonBillableRule: Codable, Identifiable {
    public var id: UUID
    public var daysOfWeek: [Int]
    public var startMinute: Int
    public var endMinute: Int

    public init(id: UUID = UUID(), daysOfWeek: [Int], startMinute: Int, endMinute: Int) {
        self.id = id
        self.daysOfWeek = daysOfWeek
        self.startMinute = startMinute
        self.endMinute = endMinute
    }
}

public struct RateEntry: Codable, Identifiable {
    public var id: UUID
    public var effectiveFrom: Date
    public var rate: Double   // per hour, no currency

    public init(id: UUID = UUID(), effectiveFrom: Date, rate: Double) {
        self.id = id
        self.effectiveFrom = effectiveFrom
        self.rate = rate
    }
}

public struct OnCallSettings: Codable {
    public var incomeTrackingEnabled: Bool
    public var passiveMultiplier: Double   // default 0.4
    public var activeMultiplier: Double    // default 1.0
    public var nonBillableRules: [NonBillableRule]
    public var rateHistory: [RateEntry]   // sorted by effectiveFrom ascending
    public var currencySymbol: String      // default "$"
    public var weekStartsOnMonday: Bool    // default false (Sunday-first)
    public var hideFromScreenCapture: Bool // default true (exclude popover from screenshots/recordings)

    public var orderedWeekdays: [(Int, String)] {
        weekStartsOnMonday
            ? [(2,"M"),(3,"Tu"),(4,"W"),(5,"Th"),(6,"F"),(7,"Sa"),(1,"Su")]
            : [(1,"Su"),(2,"M"),(3,"Tu"),(4,"W"),(5,"Th"),(6,"F"),(7,"Sa")]
    }

    /// `Calendar.current` with `firstWeekday` set from `weekStartsOnMonday`, so week-range
    /// computations (`PeriodRange`, `SessionStore.sessions(weekOffset:)`, etc.) respect the
    /// user's preference instead of falling back to the system locale's first weekday.
    public var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1
        return cal
    }

    public init(incomeTrackingEnabled: Bool = false,
                passiveMultiplier: Double = 0.4,
                activeMultiplier: Double = 1.0,
                nonBillableRules: [NonBillableRule] = [],
                rateHistory: [RateEntry] = [],
                currencySymbol: String = "$",
                weekStartsOnMonday: Bool = false,
                hideFromScreenCapture: Bool = true) {
        self.incomeTrackingEnabled = incomeTrackingEnabled
        self.passiveMultiplier = passiveMultiplier
        self.activeMultiplier = activeMultiplier
        self.nonBillableRules = nonBillableRules
        self.rateHistory = rateHistory
        self.currencySymbol = currencySymbol
        self.weekStartsOnMonday = weekStartsOnMonday
        self.hideFromScreenCapture = hideFromScreenCapture
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        incomeTrackingEnabled = try c.decode(Bool.self, forKey: .incomeTrackingEnabled)
        passiveMultiplier     = try c.decode(Double.self, forKey: .passiveMultiplier)
        activeMultiplier      = try c.decode(Double.self, forKey: .activeMultiplier)
        nonBillableRules      = try c.decode([NonBillableRule].self, forKey: .nonBillableRules)
        rateHistory           = try c.decode([RateEntry].self, forKey: .rateHistory)
        currencySymbol        = try c.decodeIfPresent(String.self, forKey: .currencySymbol) ?? "$"
        weekStartsOnMonday    = try c.decodeIfPresent(Bool.self, forKey: .weekStartsOnMonday) ?? false
        hideFromScreenCapture = try c.decodeIfPresent(Bool.self, forKey: .hideFromScreenCapture) ?? true
    }
}
