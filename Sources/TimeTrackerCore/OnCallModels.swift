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

    public init(incomeTrackingEnabled: Bool = false,
                passiveMultiplier: Double = 0.4,
                activeMultiplier: Double = 1.0,
                nonBillableRules: [NonBillableRule] = [],
                rateHistory: [RateEntry] = [],
                currencySymbol: String = "$") {
        self.incomeTrackingEnabled = incomeTrackingEnabled
        self.passiveMultiplier = passiveMultiplier
        self.activeMultiplier = activeMultiplier
        self.nonBillableRules = nonBillableRules
        self.rateHistory = rateHistory
        self.currencySymbol = currencySymbol
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        incomeTrackingEnabled = try c.decode(Bool.self, forKey: .incomeTrackingEnabled)
        passiveMultiplier     = try c.decode(Double.self, forKey: .passiveMultiplier)
        activeMultiplier      = try c.decode(Double.self, forKey: .activeMultiplier)
        nonBillableRules      = try c.decode([NonBillableRule].self, forKey: .nonBillableRules)
        rateHistory           = try c.decode([RateEntry].self, forKey: .rateHistory)
        currencySymbol        = try c.decodeIfPresent(String.self, forKey: .currencySymbol) ?? "$"
    }
}
