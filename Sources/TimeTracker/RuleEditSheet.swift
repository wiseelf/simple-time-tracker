import SwiftUI

struct RuleEditSheet: View {
    var rule: RecurrenceRule?
    var onSave: (RecurrenceRule) -> Void

    @Environment(\.dismiss) private var dismiss

    enum KindTab: String, CaseIterable {
        case dayOfWeek        = "Day of week"
        case intervalDuration = "Interval"
    }

    @State private var kindTab:      KindTab
    @State private var daysOfWeek:   [Int]
    @State private var intervalDays: Int
    @State private var durationDays: Int
    @State private var anchorDate:   Date
    @State private var hasEndDate:   Bool
    @State private var endDate:      Date
    @State private var startMinute:  Int
    @State private var endMinute:    Int

    private let allDays = [(1,"Su"),(2,"M"),(3,"T"),(4,"W"),(5,"Th"),(6,"F"),(7,"Sa")]

    init(rule: RecurrenceRule?, onSave: @escaping (RecurrenceRule) -> Void) {
        self.rule = rule
        self.onSave = onSave
        if let r = rule {
            switch r.kind {
            case .dayOfWeek(let days):
                _kindTab      = State(initialValue: .dayOfWeek)
                _daysOfWeek   = State(initialValue: days)
                _intervalDays = State(initialValue: 3)
                _durationDays = State(initialValue: 1)
            case .intervalDuration(let iv, let dur):
                _kindTab      = State(initialValue: .intervalDuration)
                _daysOfWeek   = State(initialValue: [2,3,4,5,6])
                _intervalDays = State(initialValue: iv)
                _durationDays = State(initialValue: dur)
            }
            _anchorDate  = State(initialValue: r.anchorDate)
            _hasEndDate  = State(initialValue: r.endDate != nil)
            _endDate     = State(initialValue: r.endDate ?? .now)
            _startMinute = State(initialValue: r.startMinute)
            _endMinute   = State(initialValue: r.endMinute)
        } else {
            _kindTab      = State(initialValue: .dayOfWeek)
            _daysOfWeek   = State(initialValue: [2,3,4,5,6])
            _intervalDays = State(initialValue: 3)
            _durationDays = State(initialValue: 1)
            _anchorDate   = State(initialValue: .now)
            _hasEndDate   = State(initialValue: false)
            _endDate      = State(initialValue: .now)
            _startMinute  = State(initialValue: 0)
            _endMinute    = State(initialValue: 1440)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rule == nil ? "Add Rule" : "Edit Rule")
                .font(.headline).padding(.top, 4)

            Picker("", selection: $kindTab) {
                ForEach(KindTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()

            if kindTab == .dayOfWeek {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Days").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(allDays, id: \.0) { (num, label) in
                            let sel = daysOfWeek.contains(num)
                            Button(label) {
                                if sel { daysOfWeek.removeAll { $0 == num } }
                                else   { daysOfWeek.append(num); daysOfWeek.sort() }
                            }
                            .dayToggleStyle(selected: sel)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text("Every").font(.system(size: 11))
                    Stepper("\(intervalDays) days", value: $intervalDays, in: 1...365)
                        .font(.system(size: 11))
                        .onChange(of: intervalDays) { newValue in
                            if durationDays > newValue { durationDays = newValue }
                        }
                }
                HStack(spacing: 8) {
                    Text("For").font(.system(size: 11))
                    Stepper(durationDays == 1 ? "1 day" : "\(durationDays) days",
                            value: $durationDays, in: 1...intervalDays)
                        .font(.system(size: 11))
                }
            }

            Divider()

            HStack(spacing: 6) {
                Text("From").font(.system(size: 11)).foregroundStyle(.secondary)
                MinutePickerField(minutes: $startMinute).frame(width: 86, height: 22)
                Text("To").font(.system(size: 11)).foregroundStyle(.secondary)
                MinutePickerField(minutes: $endMinute).frame(width: 86, height: 22)
            }

            Divider()

            HStack {
                Text("Starts").font(.system(size: 11)).foregroundStyle(.secondary)
                DatePicker("", selection: $anchorDate, displayedComponents: .date).labelsHidden()
            }

            HStack(spacing: 8) {
                Toggle("End date", isOn: $hasEndDate)
                    .font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
                if hasEndDate {
                    DatePicker("", selection: $endDate, in: anchorDate..., displayedComponents: .date)
                        .labelsHidden()
                }
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
        }
        .padding(16)
        .frame(width: 320, height: 360)
    }

    private var isValid: Bool {
        switch kindTab {
        case .dayOfWeek:        return !daysOfWeek.isEmpty
        case .intervalDuration: return intervalDays > 0 && durationDays > 0
        }
    }

    private func save() {
        let kind: RecurrenceRuleKind
        switch kindTab {
        case .dayOfWeek:        kind = .dayOfWeek(daysOfWeek: daysOfWeek)
        case .intervalDuration: kind = .intervalDuration(intervalDays: intervalDays, durationDays: durationDays)
        }
        onSave(RecurrenceRule(id: rule?.id ?? UUID(), kind: kind, anchorDate: anchorDate,
                              endDate: hasEndDate ? endDate : nil,
                              startMinute: startMinute, endMinute: endMinute))
        dismiss()
    }
}
