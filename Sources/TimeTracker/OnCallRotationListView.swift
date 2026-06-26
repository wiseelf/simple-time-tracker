import SwiftUI

struct OnCallRotationListView: View {
    @ObservedObject var store: OnCallStore
    var filterStart: Date? = nil
    var filterEnd: Date? = nil

    @State private var showingAdd = false
    @State private var editingRotation: OnCallRotationBlock? = nil

    private var visibleRotations: [OnCallRotationBlock] {
        guard let s = filterStart, let e = filterEnd else { return store.rotations }
        return store.rotations.filter { $0.startDate <= e && $0.endDate >= s }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Rotations")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if visibleRotations.isEmpty {
                Text(filterStart != nil ? "No rotations this period" : "No rotations defined")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            } else {
                ForEach(visibleRotations) { rotation in
                    rotationRow(rotation)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            RotationEditSheet(rotation: nil) { block in
                store.addRotation(block)
            }
        }
        .sheet(item: $editingRotation) { rotation in
            RotationEditSheet(rotation: rotation) { block in
                store.updateRotation(block)
            }
        }
    }

    private func rotationRow(_ rotation: OnCallRotationBlock) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateRangeLabel(rotation))
                    .font(.system(size: 11, weight: .medium))
                Text(scheduleSummary(rotation.schedules))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                editingRotation = rotation
            } label: {
                Image(systemName: "pencil").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                store.deleteRotation(rotation)
            } label: {
                Image(systemName: "trash").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private func dateRangeLabel(_ r: OnCallRotationBlock) -> String {
        let fmt = Date.FormatStyle().month(.abbreviated).day()
        return "\(r.startDate.formatted(fmt)) – \(r.endDate.formatted(fmt))"
    }

    private func scheduleSummary(_ schedules: [DaySchedule]) -> String {
        schedules.map { s in
            let days = dayAbbrs(s.daysOfWeek)
            return "\(days) \(minuteLabel(s.startMinute))–\(minuteLabel(s.endMinute))"
        }.joined(separator: "; ")
    }

    private func dayAbbrs(_ days: [Int]) -> String {
        let abbr = ["", "Su", "M", "T", "W", "Th", "F", "Sa"]
        return days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? abbr[$0] : nil }.joined(separator: "")
    }

    private func minuteLabel(_ m: Int) -> String {
        String(format: "%d:%02d", m / 60, m % 60)
    }
}

struct RotationEditSheet: View {
    var rotation: OnCallRotationBlock?
    var onSave: (OnCallRotationBlock) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var schedules: [DaySchedule]

    init(rotation: OnCallRotationBlock?, onSave: @escaping (OnCallRotationBlock) -> Void) {
        self.rotation = rotation
        self.onSave = onSave
        _startDate = State(initialValue: rotation?.startDate ?? .now)
        _endDate   = State(initialValue: rotation?.endDate ?? .now)
        _schedules = State(initialValue: rotation?.schedules ?? [
            DaySchedule(daysOfWeek: [2, 3, 4, 5, 6], startMinute: 0, endMinute: 1440),
            DaySchedule(daysOfWeek: [1, 7],           startMinute: 0, endMinute: 1440)
        ])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rotation == nil ? "Add Rotation" : "Edit Rotation")
                .font(.headline)
                .padding(.top, 4)

            HStack {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                Text("–").foregroundStyle(.secondary)
                DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .labelsHidden()
            }

            Divider()

            Text("Schedules").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)

            ForEach($schedules) { $sched in
                ScheduleRowEditor(schedule: $sched) {
                    schedules.removeAll { $0.id == sched.id }
                }
            }

            Button("+ Add schedule group") {
                schedules.append(DaySchedule(daysOfWeek: [], startMinute: 0, endMinute: 1440))
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Save") {
                    let block = OnCallRotationBlock(
                        id: rotation?.id ?? UUID(),
                        startDate: startDate,
                        endDate: endDate,
                        schedules: schedules.filter { !$0.daysOfWeek.isEmpty }
                    )
                    onSave(block)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(schedules.filter { !$0.daysOfWeek.isEmpty }.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320, height: 380)
    }
}

struct ScheduleRowEditor: View {
    @Binding var schedule: DaySchedule
    var onDelete: () -> Void

    private let allDays = [(1, "Su"), (2, "M"), (3, "T"), (4, "W"), (5, "Th"), (6, "F"), (7, "Sa")]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(allDays, id: \.0) { (num, label) in
                    let selected = schedule.daysOfWeek.contains(num)
                    Button(label) {
                        var days = schedule.daysOfWeek
                        if selected { days.removeAll { $0 == num } } else { days.append(num) }
                        schedule = DaySchedule(id: schedule.id, daysOfWeek: days.sorted(),
                                              startMinute: schedule.startMinute, endMinute: schedule.endMinute)
                    }
                    .dayToggleStyle(selected: selected)
                }
                Spacer()
                Button { onDelete() } label: {
                    Image(systemName: "minus.circle").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                Text("From").font(.system(size: 11)).foregroundStyle(.secondary)
                MinutePickerField(minutes: Binding(
                    get: { schedule.startMinute },
                    set: { schedule = DaySchedule(id: schedule.id, daysOfWeek: schedule.daysOfWeek,
                                                  startMinute: $0, endMinute: schedule.endMinute) }
                ))
                .frame(width: 86, height: 22)

                Text("To").font(.system(size: 11)).foregroundStyle(.secondary)
                MinutePickerField(minutes: Binding(
                    get: { schedule.endMinute },
                    set: { schedule = DaySchedule(id: schedule.id, daysOfWeek: schedule.daysOfWeek,
                                                  startMinute: schedule.startMinute, endMinute: $0) }
                ))
                .frame(width: 86, height: 22)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }
}
