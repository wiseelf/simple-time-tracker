import SwiftUI
import UniformTypeIdentifiers

struct StatsView: View {
    enum Period { case week, month }

    @ObservedObject private var store = SessionStore.shared
    @State private var period: Period = .week
    @State private var weekOffset: Int = 0
    @State private var monthOffset: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            chartSection
            Divider()
            footerSection
            Divider()
            backupSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Picker("", selection: $period) {
                Text("Week").tag(Period.week)
                Text("Month").tag(Period.month)
            }
            .pickerStyle(.segmented)
            .onChange(of: period) { _ in weekOffset = 0; monthOffset = 0 }

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
                    barRow(
                        label: row.label,
                        seconds: row.seconds,
                        maxSeconds: maxWeekSeconds,
                        highlight: row.isToday,
                        labelWidth: 30
                    )
                }
            } else {
                ForEach(monthWeekRows) { row in
                    barRow(
                        label: row.label,
                        seconds: row.seconds,
                        maxSeconds: maxMonthSeconds,
                        highlight: false,
                        labelWidth: 52
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func barRow(label: String, seconds: Int, maxSeconds: Int,
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
                }
            }
            .frame(height: 12)

            Text(seconds > 0 ? formatDuration(seconds) : "—")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(seconds > 0 ? .primary : .tertiary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
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

    // MARK: - Backup

    private var backupSection: some View {
        HStack {
            Button { exportBackup() } label: {
                Label("Export", systemImage: "square.and.arrow.up")
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
    }

    private struct WeekRow: Identifiable {
        let id: Date; let label: String; let seconds: Int
    }

    private var weekRows: [DayRow] {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = cal.date(byAdding: .weekOfYear, value: weekOffset, to: weekStart)
        else { return [] }
        return (0..<7).compactMap { i in
            guard let day = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            let secs = store.totalSeconds(in: store.sessions(on: day))
            let raw = day.formatted(.dateTime.weekday(.abbreviated))
            return DayRow(id: day, label: String(raw.prefix(3)), seconds: secs,
                          isToday: cal.isDateInToday(day))
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
        var weekNum = 1
        while cursor < monthEnd {
            let next = cal.date(byAdding: .day, value: 7, to: cursor) ?? monthEnd
            let end = min(next, monthEnd)
            var dayCursor = cursor
            var secs = 0
            while dayCursor < end {
                secs += store.totalSeconds(in: store.sessions(on: dayCursor))
                dayCursor = cal.date(byAdding: .day, value: 1, to: dayCursor) ?? dayCursor.addingTimeInterval(86400)
            }
            let sd = cal.component(.day, from: cursor)
            let ed = cal.component(.day, from: end.addingTimeInterval(-1))
            rows.append(WeekRow(id: cursor, label: "Wk\(weekNum) \(sd)–\(ed)", seconds: secs))
            cursor = end
            weekNum += 1
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
        if offset == 0  { return "This Week" }
        if offset == -1 { return "Last Week" }
        let cal = Calendar.current
        guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
              let start = cal.date(byAdding: .weekOfYear, value: offset, to: base),
              let end   = cal.date(byAdding: .day, value: 6, to: start) else { return "" }
        let sm = cal.component(.month, from: start), em = cal.component(.month, from: end)
        let sd = cal.component(.day,   from: start), ed = cal.component(.day,   from: end)
        if sm == em { return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd)–\(ed)" }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func monthLabel(_ offset: Int) -> String {
        if offset == 0  { return "This Month" }
        if offset == -1 { return "Last Month" }
        let cal = Calendar.current
        guard let base = cal.dateInterval(of: .month, for: .now)?.start,
              let date = cal.date(byAdding: .month, value: offset, to: base) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    // MARK: - Export / Import

    private var appDelegate: AppDelegate? { NSApp.delegate as? AppDelegate }

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
