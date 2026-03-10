import SwiftUI

struct StatsView: View {
    enum Period { case week, month }

    @ObservedObject private var store = SessionStore.shared
    @State private var period: Period = .week
    @State private var weekOffset: Int = 0
    @State private var monthOffset: Int = 0

    private var offset: Int { period == .week ? weekOffset : monthOffset }

    private var currentSessions: [TimeSession] {
        period == .week
            ? store.sessions(weekOffset: weekOffset)
            : store.sessions(monthOffset: monthOffset)
    }

    private var totalForPeriod: Int { store.totalSeconds(in: currentSessions) }
    private var totalToday:     Int { store.totalSeconds(in: store.sessions(on: .now)) }

    var body: some View {
        VStack(spacing: 0) {
            todayRow
            Divider()
            periodPicker
            navigationRow
            Divider()
            totalRow
            Divider()
            sessionList
        }
    }

    // MARK: - Today

    private var todayRow: some View {
        HStack {
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(totalToday > 0 ? formatDuration(totalToday) : "—")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(totalToday > 0 ? .primary : .tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        Picker("", selection: $period) {
            Text("Week").tag(Period.week)
            Text("Month").tag(Period.month)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Navigation

    private var navigationRow: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Menu {
                if period == .week {
                    ForEach(availableWeekOffsets, id: \.self) { off in
                        Button {
                            weekOffset = off
                        } label: {
                            if off == weekOffset {
                                Label(weekLabel(off), systemImage: "checkmark")
                            } else {
                                Text(weekLabel(off))
                            }
                        }
                    }
                } else {
                    ForEach(availableMonthOffsets, id: \.self) { off in
                        Button {
                            monthOffset = off
                        } label: {
                            if off == monthOffset {
                                Label(monthLabel(off), systemImage: "checkmark")
                            } else {
                                Text(monthLabel(off))
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(periodLabel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button { step(+1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(offset < 0 ? .secondary : .tertiary)
            .disabled(offset >= 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    // MARK: - Available periods (only those with data + current)

    private var availableWeekOffsets: [Int] {
        let cal = Calendar.current
        guard let currentStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return [0] }
        var offsets: Set<Int> = [0]
        for session in store.sessions {
            guard let sessionStart = cal.dateInterval(of: .weekOfYear, for: session.startDate)?.start else { continue }
            let diff = cal.dateComponents([.weekOfYear], from: sessionStart, to: currentStart).weekOfYear ?? 0
            offsets.insert(-diff)
        }
        return offsets.sorted(by: >)
    }

    private var availableMonthOffsets: [Int] {
        let cal = Calendar.current
        guard let currentStart = cal.dateInterval(of: .month, for: .now)?.start else { return [0] }
        var offsets: Set<Int> = [0]
        for session in store.sessions {
            guard let sessionStart = cal.dateInterval(of: .month, for: session.startDate)?.start else { continue }
            let diff = cal.dateComponents([.month], from: sessionStart, to: currentStart).month ?? 0
            offsets.insert(-diff)
        }
        return offsets.sorted(by: >)
    }

    // MARK: - Total

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Total")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(totalForPeriod > 0 ? formatDuration(totalForPeriod) : "—")
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(totalForPeriod > 0 ? .primary : .tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Session list

    private var sessionList: some View {
        Group {
            if currentSessions.isEmpty {
                Text("No sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(currentSessions.reversed()) { session in
                            SessionRow(session: session)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
    }

    // MARK: - Helpers

    private func step(_ delta: Int) {
        if period == .week  { weekOffset  = min(0, weekOffset  + delta) }
        else                { monthOffset = min(0, monthOffset + delta) }
    }

    private var periodLabel: String {
        period == .week ? weekLabel(weekOffset) : monthLabel(monthOffset)
    }

    private func weekLabel(_ offset: Int) -> String {
        if offset == 0 { return "This Week" }
        if offset == -1 { return "Last Week" }
        let cal = Calendar.current
        guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = cal.date(byAdding: .weekOfYear, value: offset, to: base),
              let end   = cal.date(byAdding: .day, value: 6, to: start) else { return "" }
        let sm = cal.component(.month, from: start)
        let em = cal.component(.month, from: end)
        let sd = cal.component(.day, from: start)
        let ed = cal.component(.day, from: end)
        if sm == em {
            return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd) – \(ed)"
        }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func monthLabel(_ offset: Int) -> String {
        if offset == 0 { return "This Month" }
        if offset == -1 { return "Last Month" }
        let cal = Calendar.current
        guard let base = cal.dateInterval(of: .month, for: .now)?.start,
              let date = cal.date(byAdding: .month, value: offset, to: base) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }
}

// MARK: - Session row

struct SessionRow: View {
    let session: TimeSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if session.isManual {
                    Text("Manual entry")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Text(durationString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var dateString: String {
        let cal = Calendar.current
        if cal.isDateInToday(session.startDate) {
            return "Today · " + session.startDate.formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInYesterday(session.startDate) {
            return "Yesterday · " + session.startDate.formatted(date: .omitted, time: .shortened)
        }
        return session.startDate.formatted(date: .abbreviated, time: .shortened)
    }

    private var durationString: String {
        let h = session.duration / 3600
        let m = (session.duration % 3600) / 60
        let s = session.duration % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}
