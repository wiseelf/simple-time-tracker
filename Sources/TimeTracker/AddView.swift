import SwiftUI

struct AddView: View {
    @EnvironmentObject var manager: TimerManager
    @ObservedObject private var store = SessionStore.shared

    @State private var addHours: String = ""
    @State private var addMinutes: String = ""
    @State private var durationNote: String = ""
    @State private var rangeNote: String = ""
    @State private var entryMode: EntryMode = .duration
    @State private var rangeDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var rangeStart: Date = Date().addingTimeInterval(-3600)
    @State private var rangeEnd: Date = Date()
    @State private var isOnCallActive = false
    @State private var entryError: String?
    @FocusState private var focusedField: Field?

    private enum Field { case hours, minutes }
    private enum EntryMode { case duration, range }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Add time manually")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $entryMode) {
                    Text("Duration").tag(EntryMode.duration)
                    Text("Range").tag(EntryMode.range)
                }
                .pickerStyle(.segmented)
                .frame(width: 128)
                .onChange(of: entryMode) { _ in entryError = nil }
            }

            if entryMode == .duration {
                durationEntryRow
            } else {
                rangeEntryRows
            }

            if let error = entryError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var durationEntryRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Group {
                    TextField("0", text: $addHours)
                        .focused($focusedField, equals: .hours)
                        .onChange(of: addHours) { v in addHours = sanitize(v, max: 99) }
                    Text("h")
                        .foregroundStyle(.secondary)
                    TextField("0", text: $addMinutes)
                        .focused($focusedField, equals: .minutes)
                        .onChange(of: addMinutes) { v in addMinutes = sanitize(v, max: 59) }
                    Text("m")
                        .foregroundStyle(.secondary)
                }
                .font(.system(.body, design: .monospaced))

                Spacer()

                Button("Add") { commitDurationEntry() }
                    .buttonStyle(.bordered)
                    .disabled(addHours.isEmpty && addMinutes.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }

            NoteButton(note: $durationNote)
            onCallToggle
        }
    }

    private var rangeEntryRows: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                DatePicker("", selection: $rangeDay, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .onChange(of: rangeDay) { day in
                        rangeStart = combining(day, time: rangeStart)
                        rangeEnd   = combining(day, time: rangeEnd)
                    }
            }

            HStack {
                Text("From")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                TimePickerField(date: $rangeStart)
                    .frame(width: 86, height: 22)
            }
            HStack {
                Text("To")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                TimePickerField(date: $rangeEnd)
                    .frame(width: 86, height: 22)
            }

            DayTimelineView(
                sessions: store.sessions(on: rangeDay),
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )
            .padding(.top, 2)

            NoteButton(note: $rangeNote)
            onCallToggle

            HStack {
                Spacer()
                Button("Add") { commitRangeEntry() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    private var onCallToggle: some View {
        Toggle(isOn: $isOnCallActive) {
            Label("Active on-call", systemImage: "phone.fill")
                .font(.caption)
                .foregroundStyle(isOnCallActive ? .orange : .secondary)
        }
        .toggleStyle(.switch)
        .tint(.orange)
        .font(.caption)
    }

    private func combining(_ day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute, .second], from: time)
        return cal.date(from: DateComponents(
            year: d.year, month: d.month, day: d.day,
            hour: t.hour, minute: t.minute, second: t.second
        )) ?? time
    }

    private func commitDurationEntry() {
        entryError = nil
        let h = Int(addHours) ?? 0
        let m = Int(addMinutes) ?? 0
        do {
            try manager.addTime(hours: h, minutes: m, note: durationNote.trimmedOrNil,
                                isOnCallActive: isOnCallActive)
            addHours = ""
            addMinutes = ""
            durationNote = ""
            focusedField = nil
        } catch {
            entryError = error.localizedDescription
        }
    }

    private func commitRangeEntry() {
        entryError = nil
        let start = combining(rangeDay, time: rangeStart)
        let end   = combining(rangeDay, time: rangeEnd)
        do {
            try manager.addTimeRange(start: start, end: end, note: rangeNote.trimmedOrNil,
                                     isOnCallActive: isOnCallActive)
            rangeNote = ""
        } catch {
            entryError = error.localizedDescription
        }
    }

    private func sanitize(_ value: String, max maxVal: Int) -> String {
        let digits = value.filter(\.isNumber)
        if let n = Int(digits), n <= maxVal {
            return digits
        } else if digits.count > 2 {
            return String(digits.prefix(2))
        }
        return digits
    }
}
