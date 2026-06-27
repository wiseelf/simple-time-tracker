import SwiftUI
import UniformTypeIdentifiers

struct StatsView: View {
    enum Period { case week, month }

    @ObservedObject private var store = SessionStore.shared
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var onCallStore = OnCallStore.shared
    @State private var period: Period = .week
    @State private var weekOffset: Int = 0
    @State private var monthOffset: Int = 0

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            chartSection
            Divider()
            footerSection
            if onCallStore.settings.incomeTrackingEnabled {
                Divider()
                incomeFooterSection
            }
            Divider()
            backupSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Picker("", selection: Binding(
                get: { period },
                set: { newPeriod in
                    guard newPeriod != period else { return }
                    weekOffset = 0
                    monthOffset = 0
                    period = newPeriod
                }
            )) {
                Text("Week").tag(Period.week)
                Text("Month").tag(Period.month)
            }
            .pickerStyle(.segmented)

            HStack {
                Button { step(-1) } label: {
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

                Button { step(+1) } label: {
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
        .padding(.vertical, 10)
    }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(spacing: 0) {
            if period == .week {
                ForEach(weekRows) { row in
                    barRow(label: row.label, seconds: row.seconds, onCallActiveSeconds: row.onCallActiveSeconds,
                           maxSeconds: maxWeekSeconds, highlight: row.isToday, labelWidth: 30)
                        .onTapGesture {
                            guard row.seconds > 0 else { return }
                            guard let delegate = appDelegate else { return }
                            if delegate.isShowingDetail,
                               Calendar.current.isDate(delegate.detailState.date, inSameDayAs: row.id) {
                                delegate.closeSessionsDetail()
                            } else {
                                delegate.openSessionsDetail(for: row.id)
                            }
                        }
                }
            } else {
                ForEach(monthWeekRows) { row in
                    barRow(label: row.label, seconds: row.seconds, onCallActiveSeconds: row.onCallActiveSeconds,
                           maxSeconds: maxMonthSeconds, highlight: false, labelWidth: 38)
                        .onTapGesture {
                            guard row.seconds > 0 else { return }
                            let cal = Calendar.current
                            // Use the midpoint of the segment (day+3) so edge days that
                            // belong to a neighbouring calendar week don't mislead us
                            let mid = cal.date(byAdding: .day, value: 3, to: row.id) ?? row.id
                            guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                                  let rowWeekStart  = cal.dateInterval(of: .weekOfYear, for: mid)?.start
                            else { return }
                            let days = cal.dateComponents([.day], from: thisWeekStart, to: rowWeekStart).day ?? 0
                            weekOffset = min(0, days / 7)
                            withAnimation { period = .week }
                        }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func barRow(label: String, seconds: Int, onCallActiveSeconds: Int, maxSeconds: Int,
                        highlight: Bool, labelWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: highlight ? .semibold : .regular))
                .foregroundStyle(highlight ? .primary : .secondary)
                .frame(width: labelWidth, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.secondary.opacity(0.1))
                    if seconds > 0, maxSeconds > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(highlight ? Color.accentColor : Color.accentColor.opacity(0.55))
                            .frame(width: geo.size.width * CGFloat(seconds) / CGFloat(maxSeconds))
                    }
                    if onCallActiveSeconds > 0, maxSeconds > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: geo.size.width * CGFloat(min(onCallActiveSeconds, seconds)) / CGFloat(maxSeconds))
                    }
                }
            }
            .frame(height: 12)

            Text(seconds > 0 ? formatDuration(seconds) : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(seconds > 0 ? .primary : .tertiary)
                .frame(width: 48, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(seconds > 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.clear))
                .frame(width: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL").font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
                Text(periodTotal > 0 ? formatDuration(periodTotal) : "—")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
            }
            Spacer()
            if dailyAverage > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("AVG / DAY").font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
                    Text(formatDuration(dailyAverage))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var incomeFooterSection: some View {
        let income = periodIncome
        let sym = onCallStore.settings.currencySymbol
        return HStack(spacing: 0) {
            incomeCell(label: "REGULAR", value: income.regular, symbol: sym)
            Spacer()
            incomeCell(label: "ON-CALL", value: income.onCall, symbol: sym)
            Spacer()
            incomeCell(label: "TOTAL", value: income.total, symbol: sym)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func incomeCell(label: String, value: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
            Text(value > 0 ? String(format: "%@%.0f", symbol, value) : "—")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
        }
    }

    private struct PeriodIncome { var regular: Double = 0; var onCall: Double = 0; var total: Double { regular + onCall } }

    private var periodIncome: PeriodIncome {
        let settings = onCallStore.settings
        let rotations = onCallStore.rotations
        guard settings.incomeTrackingEnabled else { return PeriodIncome() }

        let dates: [Date]
        let cal = Calendar.current
        if period == .week {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart)
            else { return PeriodIncome() }
            dates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        } else {
            guard let monthStart = cal.dateInterval(of: .month, for: .now)?.start,
                  let start = cal.date(byAdding: .month, value: monthOffset, to: monthStart),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: start)
            else { return PeriodIncome() }
            var d = start, all: [Date] = []
            while d < monthEnd { all.append(d); d = cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400) }
            dates = all
        }

        var result = PeriodIncome()
        for day in dates {
            guard let rate = OnCallBilling.rate(on: day, settings: settings) else { continue }
            let sessions = store.sessions(on: day)

            let regularSecs = sessions.filter { !$0.isOnCallActive }.reduce(0) { $0 + $1.duration }
            result.regular += Double(regularSecs) / 3600.0 * rate

            let passiveMins = OnCallBilling.passiveMinutes(on: day, sessions: sessions, rotations: rotations, settings: settings)
            let activeMins  = OnCallBilling.activeMinutesWithinBillable(on: day, sessions: sessions, rotations: rotations, settings: settings)
            result.onCall += (Double(passiveMins) / 60.0 * rate * settings.passiveMultiplier)
                           + (Double(activeMins) / 60.0 * rate * settings.activeMultiplier)
        }
        return result
    }

    // MARK: - Backup

    private var backupSection: some View {
        HStack {
            Button { exportBackup() } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button { exportReport() } label: {
                Label("Report", systemImage: "doc.text")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button { importBackup() } label: {
                Label("Import", systemImage: "square.and.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Data models

    private struct DayRow: Identifiable {
        let id: Date; let label: String; let seconds: Int; let isToday: Bool
        let onCallActiveSeconds: Int
    }

    private struct WeekRow: Identifiable {
        let id: Date; let label: String; let seconds: Int
        let onCallActiveSeconds: Int
    }

    /// Seconds of the currently running segment that haven't been saved to the store yet.
    private var liveExtraSeconds: Int {
        guard timerManager.isRunning else { return 0 }
        let stored = store.totalSeconds(in: store.sessions(on: .now))
        return max(0, timerManager.elapsedSeconds - stored)
    }

    private var weekRows: [DayRow] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart)
        else { return [] }
        return (0..<7).compactMap { i in
            guard let day = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            let daySessions = store.sessions(on: day)
            let secs = store.totalSeconds(in: daySessions)
                + (cal.isDateInToday(day) ? liveExtraSeconds : 0)
            let onCallSecs = daySessions.filter { $0.isOnCallActive }.reduce(0) { $0 + $1.duration }
            let raw = day.formatted(.dateTime.weekday(.abbreviated))
            return DayRow(id: day, label: String(raw.prefix(3)), seconds: secs,
                          isToday: cal.isDateInToday(day), onCallActiveSeconds: onCallSecs)
        }
    }

    private var monthWeekRows: [WeekRow] {
        let cal = Calendar.current
        guard let monthStart = cal.dateInterval(of: .month, for: .now)?.start,
              let start = cal.date(byAdding: .month, value: monthOffset, to: monthStart),
              let monthEnd = cal.date(byAdding: .month, value: 1, to: start)
        else { return [] }
        var rows: [WeekRow] = []
        var cursor = start
        while cursor < monthEnd {
            let next = cal.date(byAdding: .day, value: 7, to: cursor) ?? monthEnd
            let end = min(next, monthEnd)
            var dayCursor = cursor
            var secs = 0
            var onCallSecs = 0
            while dayCursor < end {
                let daySessions = store.sessions(on: dayCursor)
                secs += store.totalSeconds(in: daySessions)
                if cal.isDateInToday(dayCursor) { secs += liveExtraSeconds }
                onCallSecs += daySessions.filter { $0.isOnCallActive }.reduce(0) { $0 + $1.duration }
                dayCursor = cal.date(byAdding: .day, value: 1, to: dayCursor) ?? dayCursor.addingTimeInterval(86400)
            }
            let sd = cal.component(.day, from: cursor)
            let ed = cal.component(.day, from: end.addingTimeInterval(-1))
            rows.append(WeekRow(id: cursor, label: "\(sd)–\(ed)", seconds: secs, onCallActiveSeconds: onCallSecs))
            cursor = end
        }
        return rows
    }

    private var maxWeekSeconds:  Int { weekRows.map(\.seconds).max() ?? 0 }
    private var maxMonthSeconds: Int { monthWeekRows.map(\.seconds).max() ?? 0 }

    private var periodTotal: Int {
        period == .week
            ? weekRows.reduce(0) { $0 + $1.seconds }
            : monthWeekRows.reduce(0) { $0 + $1.seconds }
    }

    private var dailyAverage: Int {
        let active = period == .week
            ? weekRows.filter { $0.seconds > 0 }.count
            : monthWeekRows.filter { $0.seconds > 0 }.count
        return active > 0 ? periodTotal / active : 0
    }

    private var currentOffset: Int { period == .week ? weekOffset : monthOffset }

    // MARK: - Navigation

    private func step(_ delta: Int) {
        if period == .week { weekOffset  = min(0, weekOffset  + delta) }
        else               { monthOffset = min(0, monthOffset + delta) }
    }

    private var periodLabel: String {
        period == .week ? weekLabel(weekOffset) : monthLabel(monthOffset)
    }

    private func weekLabel(_ offset: Int) -> String {
        let cal = Calendar.current
        guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = cal.date(byAdding: .weekOfYear, value: offset, to: base),
              let end   = cal.date(byAdding: .day, value: 6, to: start) else { return "" }
        let dateRange = weekRangeString(start: start, end: end)
        if offset == 0  { return "This Week · \(dateRange)" }
        if offset == -1 { return "Last Week · \(dateRange)" }
        return dateRange
    }

    private func weekRangeString(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let sm = cal.component(.month, from: start), em = cal.component(.month, from: end)
        let sd = cal.component(.day,   from: start), ed = cal.component(.day,   from: end)
        if sm == em { return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd)–\(ed)" }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func monthLabel(_ offset: Int) -> String {
        let cal = Calendar.current
        guard let base = cal.dateInterval(of: .month, for: .now)?.start,
              let date = cal.date(byAdding: .month, value: offset, to: base) else { return "" }
        let name = date.formatted(.dateTime.month(.wide).year())
        if offset == 0  { return "This Month · \(date.formatted(.dateTime.month(.abbreviated).year()))" }
        if offset == -1 { return "Last Month · \(date.formatted(.dateTime.month(.abbreviated).year()))" }
        return name
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    // MARK: - Export / Import

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let dateStr = Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        panel.nameFieldStringValue = "timetracker-\(dateStr).json"
        appDelegate?.suppressAutoClose = true
        defer { appDelegate?.suppressAutoClose = false }
        let result = appDelegate?.withPanelLowered { panel.runModal() } ?? panel.runModal()
        guard result == .OK, let url = panel.url,
              let data = SessionStore.shared.exportData() else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func exportReport() {
        let cal = Calendar.current
        let dates: [Date]
        if period == .week {
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart)
            else { return }
            dates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        } else {
            guard let monthStart = cal.dateInterval(of: .month, for: .now)?.start,
                  let start = cal.date(byAdding: .month, value: monthOffset, to: monthStart),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: start)
            else { return }
            var d = start; var all: [Date] = []
            while d < monthEnd { all.append(d); d = cal.date(byAdding: .day, value: 1, to: d) ?? d.addingTimeInterval(86400) }
            dates = all
        }

        // Strip "This Week · " / "This Month · " prefix for the report header
        let cleanLabel = periodLabel.components(separatedBy: " · ").last ?? periodLabel
        let allSessions = dates.flatMap { store.sessions(on: $0) }
        let report = ReportGenerator.generate(
            dates: dates,
            periodLabel: cleanLabel,
            sessions: allSessions,
            rotations: onCallStore.rotations,
            rules: onCallStore.rules,
            exceptions: onCallStore.exceptions,
            settings: onCallStore.settings
        )
        let markdown = report.markdownString(currencySymbol: onCallStore.settings.currencySymbol)

        let panel = NSSavePanel()
        let mdType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [mdType]
        let dateStr = Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        panel.nameFieldStringValue = "time-report-\(dateStr).md"
        appDelegate?.suppressAutoClose = true
        defer { appDelegate?.suppressAutoClose = false }
        let result = appDelegate?.withPanelLowered { panel.runModal() } ?? panel.runModal()
        guard result == .OK, let url = panel.url else { return }
        try? markdown.write(to: url, atomically: true, encoding: .utf8)
    }

    private func importBackup() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a TimeTracker backup file"
        appDelegate?.suppressAutoClose = true
        defer { appDelegate?.suppressAutoClose = false }
        let openResult = appDelegate?.withPanelLowered { openPanel.runModal() } ?? openPanel.runModal()
        guard openResult == .OK, let url = openPanel.urls.first,
              let data = try? Data(contentsOf: url)
        else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode([TimeSession].self, from: data) else {
            let err = NSAlert()
            err.messageText = "Invalid backup file"
            err.informativeText = "The selected file is not a valid TimeTracker backup."
            err.alertStyle = .warning
            appDelegate?.withPanelLowered { err.runModal() }
            return
        }

        let existing = SessionStore.shared.sessions
        let existingIDs = Set(existing.map { $0.id })
        let newCount = imported.filter { !existingIDs.contains($0.id) }.count
        let skipCount = imported.count - newCount

        let alert = NSAlert()
        alert.messageText = "Import \(imported.count) session\(imported.count == 1 ? "" : "s")?"
        var info = newCount > 0
            ? "\(newCount) new session\(newCount == 1 ? "" : "s") will be added."
            : "No new sessions to add."
        if skipCount > 0 {
            info += "\n\(skipCount) duplicate\(skipCount == 1 ? "" : "s") will be skipped."
        }
        info += "\n\nChoose Replace to erase all existing data and import only the backup file."
        alert.informativeText = info
        alert.addButton(withTitle: "Merge")
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let response = appDelegate?.withPanelLowered { alert.runModal() } ?? alert.runModal()
        switch response {
        case .alertFirstButtonReturn: // Merge
            // Save any running segment so it's included in today's total after reload
            if TimerManager.shared.isRunning { TimerManager.shared.stop() }
            try? SessionStore.shared.importSessions(from: data)
            TimerManager.shared.reloadFromStore()
        case .alertSecondButtonReturn: // Replace
            // Discard in-progress segment — we're replacing everything
            SessionStore.shared.replaceAll(with: imported)
            TimerManager.shared.reloadFromStore()
        default:
            break
        }
    }
}
