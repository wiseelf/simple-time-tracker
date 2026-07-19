import Foundation

public struct ReportRow {
    public let date: Date
    public let regularSeconds: Int
    public let regularAmount: Double?
    public let passiveOnCallMinutes: Int
    public let passiveOnCallAmount: Double?
    public let activeOnCallMinutes: Int
    public let activeOnCallAmount: Double?
}

public struct ReportData {
    public let periodLabel: String
    public let rows: [ReportRow]

    public var totalRegularSeconds:       Int { rows.reduce(0) { $0 + $1.regularSeconds } }
    public var totalPassiveOnCallMinutes: Int { rows.reduce(0) { $0 + $1.passiveOnCallMinutes } }
    public var totalActiveOnCallMinutes:  Int { rows.reduce(0) { $0 + $1.activeOnCallMinutes } }
    public var totalOnCallMinutes:        Int { totalPassiveOnCallMinutes + totalActiveOnCallMinutes }

    public var totalRegularAmount: Double? {
        let vals = rows.compactMap(\.regularAmount)
        return vals.isEmpty ? nil : vals.reduce(0, +)
    }
    public var totalPassiveOnCallAmount: Double? {
        let vals = rows.compactMap(\.passiveOnCallAmount)
        return vals.isEmpty ? nil : vals.reduce(0, +)
    }
    public var totalActiveOnCallAmount: Double? {
        let vals = rows.compactMap(\.activeOnCallAmount)
        return vals.isEmpty ? nil : vals.reduce(0, +)
    }
    public var totalOnCallAmount: Double? {
        switch (totalPassiveOnCallAmount, totalActiveOnCallAmount) {
        case (let p?, let a?): return p + a
        case (let p?, nil):    return p
        case (nil, let a?):    return a
        case (nil, nil):       return nil
        }
    }
    public var grandTotal: Double? {
        switch (totalRegularAmount, totalOnCallAmount) {
        case (let r?, let oc?): return r + oc
        case (let r?, nil):     return r
        case (nil, let oc?):    return oc
        case (nil, nil):        return nil
        }
    }

    public func markdownString(currencySymbol sym: String, includeOnCall: Bool = true) -> String {
        let showAmounts = rows.contains { $0.regularAmount != nil }
        var out = "# Time Report — \(periodLabel)\n\n"

        if showAmounts && includeOnCall {
            out += "| Date | Hours | Amount | Passive OC | Passive Amt | Active OC | Active Amt |\n"
            out += "|------|------:|-------:|-----------:|------------:|----------:|-----------:|\n"
        } else if showAmounts {
            out += "| Date | Hours | Amount |\n"
            out += "|------|------:|-------:|\n"
        } else if includeOnCall {
            out += "| Date | Hours | Passive OC | Active OC |\n"
            out += "|------|------:|-----------:|----------:|\n"
        } else {
            out += "| Date | Hours |\n"
            out += "|------|------:|\n"
        }

        for row in rows {
            let d = row.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            let h = row.regularSeconds > 0 ? fmtSecs(row.regularSeconds) : "—"
            if showAmounts && includeOnCall {
                let amt  = row.regularAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
                let poc  = row.passiveOnCallMinutes > 0 ? fmtMins(row.passiveOnCallMinutes) : "—"
                let pAmt = row.passiveOnCallAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
                let aoc  = row.activeOnCallMinutes > 0 ? fmtMins(row.activeOnCallMinutes) : "—"
                let aAmt = row.activeOnCallAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
                out += "| \(d) | \(h) | \(amt) | \(poc) | \(pAmt) | \(aoc) | \(aAmt) |\n"
            } else if showAmounts {
                let amt = row.regularAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
                out += "| \(d) | \(h) | \(amt) |\n"
            } else if includeOnCall {
                let poc = row.passiveOnCallMinutes > 0 ? fmtMins(row.passiveOnCallMinutes) : "—"
                let aoc = row.activeOnCallMinutes > 0 ? fmtMins(row.activeOnCallMinutes) : "—"
                out += "| \(d) | \(h) | \(poc) | \(aoc) |\n"
            } else {
                out += "| \(d) | \(h) |\n"
            }
        }

        out += "\n"

        if showAmounts {
            let regAmt = totalRegularAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
            out += "Regular:      \(fmtSecs(totalRegularSeconds))   \(regAmt)\n"
            if includeOnCall {
                let pAmt  = totalPassiveOnCallAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
                let aAmt  = totalActiveOnCallAmount.map  { String(format: "%@%.2f", sym, $0) } ?? "—"
                let grand = grandTotal.map               { String(format: "%@%.2f", sym, $0) } ?? "—"
                out += "OC Passive:      \(fmtMins(totalPassiveOnCallMinutes))    \(pAmt)\n"
                out += "OC Active:       \(fmtMins(totalActiveOnCallMinutes))    \(aAmt)\n"
                out += "Total:                   \(grand)\n"
            }
        } else {
            out += "Regular:      \(fmtSecs(totalRegularSeconds))\n"
            if includeOnCall {
                out += "OC Passive:      \(fmtMins(totalPassiveOnCallMinutes))\n"
                out += "OC Active:       \(fmtMins(totalActiveOnCallMinutes))\n"
            }
        }

        return out
    }

    private func fmtSecs(_ s: Int) -> String { String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
    private func fmtMins(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }
}

public enum ReportGenerator {
    public static func generate(
        dates: [Date],
        periodLabel: String,
        sessions: [TimeSession],
        rotations: [OnCallRotationBlock],
        rules: [RecurrenceRule],
        exceptions: [ScheduleException],
        settings: OnCallSettings
    ) -> ReportData {
        let cal = Calendar.current
        let rows: [ReportRow] = dates.compactMap { date in
            let daySessions = sessions.filter { cal.isDate($0.startDate, inSameDayAs: date) }
            let regularSecs = daySessions.filter { !$0.isOnCallActive }.reduce(0) { $0 + $1.duration }

            let rate = settings.incomeTrackingEnabled
                ? OnCallBilling.rate(on: date, settings: settings)
                : nil
            let regularAmount = rate.map { OnCallBilling.regularIncome(seconds: regularSecs, rate: $0) }

            let passiveMins = OnCallBilling.passiveMinutes(
                on: date, sessions: daySessions,
                rotations: rotations, rules: rules, exceptions: exceptions, settings: settings)
            let activeMins = OnCallBilling.activeMinutesWithinBillable(
                on: date, sessions: daySessions,
                rotations: rotations, rules: rules, exceptions: exceptions, settings: settings)

            let passiveAmount = rate.map { OnCallBilling.passiveIncome(minutes: passiveMins, rate: $0, settings: settings) }
            let activeAmount  = rate.map { OnCallBilling.activeIncome(minutes: activeMins, rate: $0, settings: settings) }

            guard regularSecs > 0 || passiveMins > 0 || activeMins > 0 else { return nil }
            return ReportRow(
                date: date,
                regularSeconds: regularSecs, regularAmount: regularAmount,
                passiveOnCallMinutes: passiveMins, passiveOnCallAmount: passiveAmount,
                activeOnCallMinutes: activeMins, activeOnCallAmount: activeAmount
            )
        }
        return ReportData(periodLabel: periodLabel, rows: rows)
    }
}
