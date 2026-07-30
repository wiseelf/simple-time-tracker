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
            let active = OnCallBilling.activeMinutes(
                on: day, sessions: sessions,
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
        PeriodRange.days(for: period == .week ? .week : .month, offset: offset, calendar: store.settings.calendar)
    }

    private var periodLabel: String {
        let cal = store.settings.calendar
        if period == .week {
            guard let start = PeriodRange.interval(for: .week, offset: offset, calendar: cal)?.start,
                  let end   = cal.date(byAdding: .day, value: 6, to: start) else { return "" }
            let sm = cal.component(.month, from: start), em = cal.component(.month, from: end)
            let sd = cal.component(.day,   from: start), ed = cal.component(.day,   from: end)
            if sm == em { return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd)–\(ed)" }
            return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        } else {
            guard let date = PeriodRange.interval(for: .month, offset: offset, calendar: cal)?.start else { return "" }
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func incomeFor(day: Date, passive: Int, active: Int) -> Double {
        guard store.settings.incomeTrackingEnabled,
              let rate = OnCallBilling.rate(on: day, settings: store.settings) else { return 0 }
        return OnCallBilling.onCallIncome(passiveMinutes: passive, activeMinutes: active,
                                          rate: rate, settings: store.settings)
    }

    private func formatMins(_ m: Int) -> String {
        let h = m / 60, min = m % 60
        return h > 0 ? "\(h)h\(min > 0 ? " \(min)m" : "")" : "\(min)m"
    }
}
