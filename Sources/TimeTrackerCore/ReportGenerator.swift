import Foundation

public struct ReportRow {
    public let date: Date
    public let regularSeconds: Int
    public let regularAmount: Double?
    public let onCallMinutes: Int
    public let onCallAmount: Double?
}

public struct ReportData {
    public let periodLabel: String
    public let rows: [ReportRow]

    public var totalRegularSeconds: Int { rows.reduce(0) { $0 + $1.regularSeconds } }
    public var totalOnCallMinutes:  Int { rows.reduce(0) { $0 + $1.onCallMinutes } }

    public var totalRegularAmount: Double? {
        let vals = rows.compactMap(\.regularAmount)
        return vals.isEmpty ? nil : vals.reduce(0, +)
    }
    public var totalOnCallAmount: Double? {
        let vals = rows.compactMap(\.onCallAmount)
        return vals.isEmpty ? nil : vals.reduce(0, +)
    }
    public var grandTotal: Double? {
        switch (totalRegularAmount, totalOnCallAmount) {
        case (let r?, let oc?): return r + oc
        case (let r?, nil):     return r
        case (nil, let oc?):    return oc
        case (nil, nil):        return nil
        }
    }

    public func markdownString(currencySymbol sym: String) -> String {
        let showAmounts = rows.contains { $0.regularAmount != nil }
        var out = "# Time Report — \(periodLabel)\n\n"

        if showAmounts {
            out += "| Date | Hours | Amount | On-call | OC Amount |\n"
            out += "|------|------:|-------:|--------:|----------:|\n"
        } else {
            out += "| Date | Hours | On-call |\n"
            out += "|------|------:|--------:|\n"
        }

        for row in rows {
            let d  = row.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            let h  = row.regularSeconds > 0 ? fmtSecs(row.regularSeconds) : "—"
            let oc = row.onCallMinutes  > 0 ? fmtMins(row.onCallMinutes)  : "—"
            if showAmounts {
                let amt   = row.regularAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
                let ocAmt = row.onCallAmount.map  { String(format: "%@%.2f", sym, $0) } ?? "—"
                out += "| \(d) | \(h) | \(amt) | \(oc) | \(ocAmt) |\n"
            } else {
                out += "| \(d) | \(h) | \(oc) |\n"
            }
        }

        out += "\n"

        if showAmounts {
            let regAmt = totalRegularAmount.map { String(format: "%@%.2f", sym, $0) } ?? "—"
            let ocAmt  = totalOnCallAmount.map  { String(format: "%@%.2f", sym, $0) } ?? "—"
            let grand  = grandTotal.map         { String(format: "%@%.2f", sym, $0) } ?? "—"
            out += "Regular:   \(fmtSecs(totalRegularSeconds))   \(regAmt)\n"
            out += "On-call:   \(fmtMins(totalOnCallMinutes))    \(ocAmt)\n"
            out += "Total:                \(grand)\n"
        } else {
            out += "Regular:   \(fmtSecs(totalRegularSeconds))\n"
            out += "On-call:   \(fmtMins(totalOnCallMinutes))\n"
        }

        return out
    }

    private func fmtSecs(_ s: Int) -> String { String(format: "%d:%02d", s / 3600, (s % 3600) / 60) }
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
            let regularAmount = rate.map { Double(regularSecs) / 3600.0 * $0 }

            let passiveMins = OnCallBilling.passiveMinutes(
                on: date, sessions: daySessions,
                rotations: rotations, rules: rules, exceptions: exceptions, settings: settings)
            let activeMins = OnCallBilling.activeMinutesWithinBillable(
                on: date, sessions: daySessions,
                rotations: rotations, rules: rules, exceptions: exceptions, settings: settings)
            let onCallMins = passiveMins + activeMins

            let onCallAmount = rate.map {
                Double(passiveMins) / 60.0 * $0 * settings.passiveMultiplier
                    + Double(activeMins) / 60.0 * $0 * settings.activeMultiplier
            }

            guard regularSecs > 0 || onCallMins > 0 else { return nil }
            return ReportRow(date: date, regularSeconds: regularSecs, regularAmount: regularAmount,
                             onCallMinutes: onCallMins, onCallAmount: onCallAmount)
        }
        return ReportData(periodLabel: periodLabel, rows: rows)
    }
}
