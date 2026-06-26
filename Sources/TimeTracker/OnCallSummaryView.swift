import SwiftUI

struct OnCallSummaryView: View {
    @ObservedObject var store:        OnCallStore
    @ObservedObject var sessionStore: SessionStore

    enum Period { case week, month }
    let period: Period
    @Binding var offset: Int

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            OnCallRotationListView(store: store, filterStart: periodStart, filterEnd: periodEnd)
            Divider()
            summaryRows
        }
    }

    private var periodStart: Date? { periodDates.first }
    private var periodEnd:   Date? { periodDates.last  }

    // MARK: - Header (nav arrows only — period picker owned by OnCallView)

    private var summaryHeader: some View {
        HStack {
            Button { offset -= 1 } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
            Text(periodLabel).font(.subheadline).fontWeight(.medium)
            Spacer()

            Button { offset += 1 } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Summary rows

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
                .foregroundStyle(row.activeMinutes > 0
                    ? AnyShapeStyle(Color.orange)
                    : AnyShapeStyle(Color.secondary.opacity(0.5)))
            if store.settings.incomeTrackingEnabled {
                Text(row.income > 0
                     ? String(format: "%@%.0f", store.settings.currencySymbol, row.income)
                     : "—")
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
                .foregroundStyle(totals.active > 0
                    ? AnyShapeStyle(Color.orange)
                    : AnyShapeStyle(Color.secondary.opacity(0.5)))
            if store.settings.incomeTrackingEnabled {
                Text(totals.income > 0
                     ? String(format: "%@%.0f", store.settings.currencySymbol, totals.income)
                     : "—")
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
        return periodDates.map { day in
            let sessions = sessionStore.sessions(on: day)
            let passive = OnCallBilling.passiveMinutes(
                on: day, sessions: sessions,
                rotations: store.rotations,
                rules: store.rules,
                exceptions: store.exceptions,
                settings: store.settings)
            let active = OnCallBilling.activeMinutesWithinBillable(
                on: day, sessions: sessions,
                rotations: store.rotations,
                rules: store.rules,
                exceptions: store.exceptions,
                settings: store.settings)
            let label: String
            if period == .week {
                label = String(day.formatted(.dateTime.weekday(.abbreviated)).prefix(3))
            } else {
                label = "\(cal.component(.day, from: day))"
            }
            return SummaryRow(date: day, label: label, isToday: cal.isDateInToday(day),
                              passiveMinutes: passive, activeMinutes: active,
                              income: incomeFor(day: day, passive: passive, active: active))
        }
        .filter { $0.passiveMinutes > 0 || $0.activeMinutes > 0 }
    }

    // MARK: - Period computation

    private var periodDates: [Date] {
        let cal = Calendar.current
        if period == .week {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start     = cal.date(byAdding: .weekOfYear, value: offset, to: weekStart)
            else { return [] }
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        } else {
            guard let monthStart = cal.dateInterval(of: .month, for: .now)?.start,
                  let start      = cal.date(byAdding: .month, value: offset, to: monthStart),
                  let monthEnd   = cal.date(byAdding: .month, value: 1, to: start)
            else { return [] }
            var d = start, all: [Date] = []
            while d < monthEnd {
                all.append(d)
                d = cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400)
            }
            return all
        }
    }

    private var periodLabel: String {
        let cal = Calendar.current
        if period == .week {
            guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: offset, to: base),
                  let end   = cal.date(byAdding: .day, value: 6, to: start) else { return "" }
            let sm = cal.component(.month, from: start), em = cal.component(.month, from: end)
            let sd = cal.component(.day,   from: start), ed = cal.component(.day,   from: end)
            if sm == em { return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd)–\(ed)" }
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        } else {
            guard let base = cal.dateInterval(of: .month, for: .now)?.start,
                  let date = cal.date(byAdding: .month, value: offset, to: base) else { return "" }
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func incomeFor(day: Date, passive: Int, active: Int) -> Double {
        guard store.settings.incomeTrackingEnabled,
              let rate = OnCallBilling.rate(on: day, settings: store.settings) else { return 0 }
        return Double(passive) / 60.0 * rate * store.settings.passiveMultiplier
             + Double(active)  / 60.0 * rate * store.settings.activeMultiplier
    }

    private func formatMins(_ m: Int) -> String {
        let h = m / 60, min = m % 60
        return h > 0 ? "\(h)h\(min > 0 ? " \(min)m" : "")" : "\(min)m"
    }
}
