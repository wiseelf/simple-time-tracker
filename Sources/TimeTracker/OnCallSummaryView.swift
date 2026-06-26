import SwiftUI

struct OnCallSummaryView: View {
    @ObservedObject var store: OnCallStore
    @ObservedObject var sessionStore: SessionStore

    enum Period { case week, month }
    @State private var period: Period = .week
    @State private var weekOffset: Int = 0
    @State private var monthOffset: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            summaryHeader
            Divider()
            summaryRows
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 6) {
            Picker("", selection: $period) {
                Text("Week").tag(Period.week)
                Text("Month").tag(Period.month)
            }
            .pickerStyle(.segmented)

            HStack {
                Button { stepPeriod(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()
                Text(periodLabel)
                    .font(.subheadline).fontWeight(.medium)
                Spacer()

                Button { stepPeriod(+1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(currentOffset < 0 ? .secondary : .tertiary)
                .disabled(currentOffset >= 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var summaryRows: some View {
        VStack(spacing: 0) {
            summaryRowHeader
            ForEach(summaryData, id: \.date) { row in
                summaryDataRow(row)
                Divider().padding(.horizontal, 12)
            }
            summaryTotalsRow
        }
    }

    private var summaryRowHeader: some View {
        HStack {
            Text("Date").frame(width: 60, alignment: .leading)
            Spacer()
            Text("Passive").frame(width: 52, alignment: .trailing)
            Text("Active").frame(width: 46, alignment: .trailing)
            if store.settings.incomeTrackingEnabled {
                Text("Income").frame(width: 48, alignment: .trailing)
            }
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func summaryDataRow(_ row: SummaryRow) -> some View {
        HStack {
            Text(row.label).frame(width: 60, alignment: .leading)
                .font(.system(size: 11))
                .foregroundStyle(row.isToday ? .primary : .secondary)
            Spacer()
            Text(row.passiveMinutes > 0 ? formatMins(row.passiveMinutes) : "—")
                .frame(width: 52, alignment: .trailing)
            Text(row.activeMinutes > 0 ? formatMins(row.activeMinutes) : "—")
                .frame(width: 46, alignment: .trailing)
                .foregroundStyle(row.activeMinutes > 0 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.secondary.opacity(0.5)))
            if store.settings.incomeTrackingEnabled {
                Text(row.income > 0 ? String(format: "%.0f", row.income) : "—")
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private var summaryTotalsRow: some View {
        let totals = summaryData.reduce((passive: 0, active: 0, income: 0.0)) {
            ($0.passive + $1.passiveMinutes, $0.active + $1.activeMinutes, $0.income + $1.income)
        }
        return HStack {
            Text("TOTAL").frame(width: 60, alignment: .leading)
            Spacer()
            Text(totals.passive > 0 ? formatMins(totals.passive) : "—")
                .frame(width: 52, alignment: .trailing)
            Text(totals.active > 0 ? formatMins(totals.active) : "—")
                .frame(width: 46, alignment: .trailing)
                .foregroundStyle(totals.active > 0 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.secondary.opacity(0.5)))
            if store.settings.incomeTrackingEnabled {
                Text(totals.income > 0 ? String(format: "%.0f", totals.income) : "—")
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Data

    private struct SummaryRow {
        let date: Date
        let label: String
        let isToday: Bool
        let passiveMinutes: Int
        let activeMinutes: Int
        let income: Double
    }

    private var summaryData: [SummaryRow] {
        let cal = Calendar.current
        let dates = periodDates
        return dates.map { day in
            let sessions = sessionStore.sessions(on: day)
            let passive = OnCallBilling.passiveMinutes(on: day, sessions: sessions,
                                                       rotations: store.rotations, settings: store.settings)
            let active  = OnCallBilling.activeMinutesWithinBillable(on: day, sessions: sessions,
                                                                     rotations: store.rotations, settings: store.settings)
            let income  = incomeFor(day: day, passive: passive, active: active)
            let label: String
            if period == .week {
                let raw = day.formatted(.dateTime.weekday(.abbreviated))
                label = String(raw.prefix(3))
            } else {
                label = "\(cal.component(.day, from: day))"
            }
            return SummaryRow(date: day, label: label, isToday: cal.isDateInToday(day),
                              passiveMinutes: passive, activeMinutes: active, income: income)
        }
        .filter { $0.passiveMinutes > 0 || $0.activeMinutes > 0 }
    }

    private var periodDates: [Date] {
        let cal = Calendar.current
        if period == .week {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart)
            else { return [] }
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        } else {
            guard let monthStart = cal.dateInterval(of: .month, for: .now)?.start,
                  let start = cal.date(byAdding: .month, value: monthOffset, to: monthStart),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: start)
            else { return [] }
            var d = start, all: [Date] = []
            while d < monthEnd { all.append(d); d = cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400) }
            return all
        }
    }

    private func incomeFor(day: Date, passive: Int, active: Int) -> Double {
        guard store.settings.incomeTrackingEnabled,
              let rate = OnCallBilling.rate(on: day, settings: store.settings) else { return 0 }
        let passiveIncome = Double(passive) / 60.0 * rate * store.settings.passiveMultiplier
        let activeIncome  = Double(active)  / 60.0 * rate * store.settings.activeMultiplier
        return passiveIncome + activeIncome
    }

    // MARK: - Navigation

    private var currentOffset: Int { period == .week ? weekOffset : monthOffset }

    private func stepPeriod(_ delta: Int) {
        if period == .week { weekOffset  = min(0, weekOffset  + delta) }
        else               { monthOffset = min(0, monthOffset + delta) }
    }

    private var periodLabel: String {
        let cal = Calendar.current
        if period == .week {
            guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: base),
                  let end   = cal.date(byAdding: .day, value: 6, to: start) else { return "" }
            let sm = cal.component(.month, from: start), em = cal.component(.month, from: end)
            let sd = cal.component(.day, from: start), ed = cal.component(.day, from: end)
            if sm == em { return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd)–\(ed)" }
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        } else {
            guard let base = cal.dateInterval(of: .month, for: .now)?.start,
                  let date = cal.date(byAdding: .month, value: monthOffset, to: base) else { return "" }
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func formatMins(_ m: Int) -> String {
        let h = m / 60, min = m % 60
        if h > 0 { return "\(h)h\(min > 0 ? " \(min)m" : "")" }
        return "\(min)m"
    }
}
