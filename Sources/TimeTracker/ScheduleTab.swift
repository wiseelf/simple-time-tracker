import SwiftUI

struct ScheduleTab: View {
    @ObservedObject var store: OnCallStore

    @State private var monthOffset:    Int   = 0
    @State private var selectedDate:   Date? = nil
    @State private var showingAddRule: Bool  = false
    @State private var editingRule:    RecurrenceRule? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                rulesSection
                Divider()
                calendarSection
                if let date = selectedDate {
                    Divider()
                    dayDetailPanel(for: date)
                }
            }
        }
        .scrollDisabled(true)
    }

    // MARK: - Rules section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Rule")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                if store.rules.isEmpty {
                    Button { showingAddRule = true } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain).foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)

            if let rule = store.rules.first {
                ruleRow(rule)
            } else {
                Text("No recurrence rule defined")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 12).padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showingAddRule) {
            RuleEditSheet(rule: nil) { store.addRule($0) }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditSheet(rule: rule) { store.updateRule($0) }
        }
    }

    private func ruleRow(_ rule: RecurrenceRule) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ruleKindLabel(rule))
                    .font(.system(size: 11, weight: .medium))
                Text(ruleTimeLabel(rule))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { editingRule = rule } label: {
                Image(systemName: "pencil").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Button { store.deleteRule(rule) } label: {
                Image(systemName: "trash").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.red.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Color.secondary.opacity(0.05)).cornerRadius(6)
        .padding(.horizontal, 8).padding(.bottom, 4)
    }

    // MARK: - Calendar section

    private var calendarSection: some View {
        VStack(spacing: 4) {
            HStack {
                Button { monthOffset -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text(monthLabel).font(.subheadline).fontWeight(.medium)
                Spacer()
                Button { monthOffset += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 24, height: 24).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.top, 8)

            OnCallCalendarGrid(
                monthOffset:  monthOffset,
                rule:         store.rules.first,
                exceptions:   store.exceptions,
                selectedDate: $selectedDate
            )
            .padding(.horizontal, 8).padding(.bottom, 6)
        }
    }

    // MARK: - Day detail panel

    private func dayDetailPanel(for date: Date) -> some View {
        let cal       = Calendar.current
        let d         = cal.startOfDay(for: date)
        let resolved  = store.rules.first?.resolvedWindow(on: date, exceptions: store.exceptions)
        let rawWindow = store.rules.first?.window(on: date)
        let isOnCall  = resolved != nil
        let hasExc    = store.exceptions.contains { cal.startOfDay(for: $0.date) == d }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button { selectedDate = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text("On-call").font(.system(size: 11))
                Toggle("", isOn: Binding(
                    get: { isOnCall },
                    set: { toggleOnCall(date: date, rawWindow: rawWindow, newValue: $0) }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }

            if isOnCall, let w = resolved {
                HStack(spacing: 6) {
                    Text("From").font(.system(size: 11)).foregroundStyle(.secondary)
                    MinutePickerField(minutes: Binding(
                        get: { w.0 },
                        set: { store.upsertException(ScheduleException(date: date,
                                   kind: .override(startMinute: $0, endMinute: w.1))) }
                    ))
                    .frame(width: 86, height: 22)
                    Text("To").font(.system(size: 11)).foregroundStyle(.secondary)
                    MinutePickerField(minutes: Binding(
                        get: { w.1 },
                        set: { store.upsertException(ScheduleException(date: date,
                                   kind: .override(startMinute: w.0, endMinute: $0))) }
                    ))
                    .frame(width: 86, height: 22)
                }
                if hasExc {
                    Button("Reset to rule defaults") { store.removeException(for: date) }
                        .font(.system(size: 10)).buttonStyle(.plain).foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func toggleOnCall(date: Date, rawWindow: (Int, Int)?, newValue: Bool) {
        guard let rule = store.rules.first else { return }
        if newValue {
            if rawWindow != nil {
                store.removeException(for: date)
            } else {
                store.upsertException(ScheduleException(date: date,
                    kind: .override(startMinute: rule.startMinute, endMinute: rule.endMinute)))
            }
        } else {
            if rawWindow != nil {
                store.upsertException(ScheduleException(date: date, kind: .skip))
            } else {
                store.removeException(for: date)
            }
        }
    }

    private var monthLabel: String {
        let cal = Calendar.current
        guard let base = cal.dateInterval(of: .month, for: .now)?.start,
              let date = cal.date(byAdding: .month, value: monthOffset, to: base) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private func ruleKindLabel(_ rule: RecurrenceRule) -> String {
        switch rule.kind {
        case .dayOfWeek(let days):
            let abbr = ["","Su","M","T","W","Th","F","Sa"]
            return "Every " + days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? abbr[$0] : nil }.joined(separator: ", ")
        case .intervalDuration(let iv, let dur):
            return dur == 1 ? "Every \(iv) days" : "Every \(iv) days, \(dur)-day block"
        }
    }

    private func ruleTimeLabel(_ rule: RecurrenceRule) -> String {
        "\(fmt(rule.startMinute)) – \(fmt(rule.endMinute))"
    }

    private func fmt(_ m: Int) -> String { String(format: "%d:%02d", m / 60, m % 60) }
}
