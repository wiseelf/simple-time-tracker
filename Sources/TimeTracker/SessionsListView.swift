import SwiftUI

struct SessionsListView: View {
    var date: Date = .now

    @EnvironmentObject var manager: TimerManager
    @ObservedObject private var store = SessionStore.shared

    @State private var editingID: UUID?
    @State private var editStart: Date = Date()
    @State private var editEnd: Date = Date()
    @State private var editError: String?

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var sessions: [TimeSession] {
        store.sessions(on: date).sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        if sessions.isEmpty {
            Text("No sessions")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
        } else {
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    VStack(spacing: 0) {
                        sessionRow(session)
                        if editingID == session.id {
                            editRow(for: session)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Session row

    private func sessionRow(_ session: TimeSession) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(timeRange(session))
                        .font(.system(.caption, design: .monospaced))
                    if session.isManual {
                        Text("manual")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.7), in: Capsule())
                    }
                }
                Text(formatDuration(session.duration))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { beginEdit(session) } label: {
                Image(systemName: "pencil")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            // Lock edit while timer is running on today's non-manual sessions
            .disabled(isToday && manager.isRunning && !session.isManual)

            Button { deleteSession(session) } label: {
                Image(systemName: "trash")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Inline edit row

    private func editRow(for session: TimeSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("From")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                TimePickerField(date: $editStart)
                    .frame(width: 86, height: 22)
            }
            HStack {
                Text("To")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                TimePickerField(date: $editEnd)
                    .frame(width: 86, height: 22)
            }

            if let error = editError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { cancelEdit() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") { commitEdit(session) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Actions

    private func beginEdit(_ session: TimeSession) {
        editingID = session.id
        editStart = session.startDate
        editEnd = session.startDate.addingTimeInterval(TimeInterval(session.duration))
        editError = nil
    }

    private func cancelEdit() {
        editingID = nil
        editError = nil
    }

    private func commitEdit(_ session: TimeSession) {
        editError = nil
        let cal = Calendar.current

        // Both times must stay on the same calendar day as the original session
        guard cal.isDate(editStart, inSameDayAs: session.startDate),
              cal.isDate(editEnd,   inSameDayAs: session.startDate) else {
            editError = "Time range must stay within the same day."
            return
        }
        guard editStart < editEnd else {
            editError = "Start time must be before end time."
            return
        }
        // For today: block future times. For past days: no restriction (the day is over).
        if isToday, editEnd > Date() {
            editError = "Cannot log time in the future."
            return
        }
        let overlap = store.sessions(on: date)
            .filter { $0.id != session.id }
            .contains { other in
                let otherEnd = other.startDate.addingTimeInterval(TimeInterval(other.duration))
                return editStart < otherEnd && other.startDate < editEnd
            }
        guard !overlap else {
            editError = "This range overlaps with an existing session."
            return
        }

        let duration = Int(editEnd.timeIntervalSince(editStart))
        store.update(session, startDate: editStart, duration: duration)
        if isToday { manager.resyncFromStore() }
        editingID = nil
    }

    private func deleteSession(_ session: TimeSession) {
        store.delete(session)
        if isToday { manager.resyncFromStore() }
        if editingID == session.id { editingID = nil }
    }

    // MARK: - Formatting

    private func timeRange(_ session: TimeSession) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        let start = fmt.string(from: session.startDate)
        let end   = fmt.string(from: session.startDate.addingTimeInterval(TimeInterval(session.duration)))
        return "\(start) – \(end)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
