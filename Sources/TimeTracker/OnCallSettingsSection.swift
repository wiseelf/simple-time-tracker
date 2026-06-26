import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = OnCallStore.shared
    @State private var newRate: String = ""
    @State private var newRateDate: Date = .now
    @State private var newNBDays: Set<Int> = []
    @State private var newNBStart: Int = 480
    @State private var newNBEnd: Int = 1080

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Income tracking", isOn: Binding(
                get: { store.settings.incomeTrackingEnabled },
                set: { store.updateSettings(store.settings.with(incomeTrackingEnabled: $0)) }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 12))

            if store.settings.incomeTrackingEnabled {
                HStack {
                    Text("Currency").font(.system(size: 11))
                    Spacer()
                    TextField("$", text: Binding(
                        get: { store.settings.currencySymbol },
                        set: { store.updateSettings(store.settings.with(currencySymbol: $0)) }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 44)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                }

                multiplierRow(label: "Passive", value: store.settings.passiveMultiplier) { v in
                    store.updateSettings(store.settings.with(passiveMultiplier: v))
                }
                multiplierRow(label: "Active", value: store.settings.activeMultiplier) { v in
                    store.updateSettings(store.settings.with(activeMultiplier: v))
                }

                Divider()
                Text("Base rate history").font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach(store.settings.rateHistory.sorted { $0.effectiveFrom > $1.effectiveFrom }) { entry in
                    HStack {
                        Text(entry.effectiveFrom.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(size: 11))
                        Spacer()
                        Text(String(format: "%@%.2f /hr", store.settings.currencySymbol, entry.rate))
                            .font(.system(size: 11, design: .monospaced))
                        Button {
                            var s = store.settings
                            s.rateHistory.removeAll { $0.id == entry.id }
                            store.updateSettings(s)
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    DatePicker("", selection: $newRateDate, displayedComponents: .date)
                        .labelsHidden()
                        .frame(width: 90)
                    TextField("Rate", text: $newRate)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .font(.system(size: 11))
                    Button("Add") {
                        guard let r = Double(newRate), r > 0 else { return }
                        var s = store.settings
                        s.rateHistory.append(RateEntry(effectiveFrom: newRateDate, rate: r))
                        s.rateHistory.sort { $0.effectiveFrom < $1.effectiveFrom }
                        store.updateSettings(s)
                        newRate = ""
                    }
                    .font(.system(size: 11))
                    .disabled(Double(newRate) == nil)
                }
            }

            Divider()
            Text("Non-billable window").font(.system(size: 11)).foregroundStyle(.secondary)
            ForEach(store.settings.nonBillableRules) { rule in
                HStack {
                    Text(dayNames(rule.daysOfWeek))
                        .font(.system(size: 11))
                    Spacer()
                    Text("\(minuteLabel(rule.startMinute))–\(minuteLabel(rule.endMinute))")
                        .font(.system(size: 11, design: .monospaced))
                    Button {
                        var s = store.settings
                        s.nonBillableRules.removeAll { $0.id == rule.id }
                        store.updateSettings(s)
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            AddNonBillableRuleRow { rule in
                var s = store.settings
                s.nonBillableRules.append(rule)
                store.updateSettings(s)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .font(.system(size: 12))
    }

    private func multiplierRow(label: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        HStack {
            Text("\(label) rate").font(.system(size: 11))
            Spacer()
            Stepper(value: Binding(get: { value }, set: onChange),
                    in: 0.0...2.0, step: 0.05) {
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 38, alignment: .trailing)
            }
            .controlSize(.small)
        }
    }

    private func dayNames(_ days: [Int]) -> String {
        let abbr = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? abbr[$0] : nil }.joined(separator: " ")
    }

    private func minuteLabel(_ m: Int) -> String {
        String(format: "%d:%02d", m / 60, m % 60)
    }
}

struct AddNonBillableRuleRow: View {
    var onAdd: (NonBillableRule) -> Void

    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var startMinute: Int = 480
    @State private var endMinute: Int = 1080

    private let dayLabels = [(2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "Su")]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(dayLabels, id: \.0) { (num, label) in
                    let selected = days.contains(num)
                    Button(label) {
                        var d = days
                        if selected { d.remove(num) } else { d.insert(num) }
                        days = d
                    }
                    .dayToggleStyle(selected: selected)
                }
            }
            HStack(spacing: 6) {
                timeStepperField(label: "From", minute: $startMinute)
                Text("–").foregroundStyle(.secondary)
                timeStepperField(label: "To", minute: $endMinute)
                Spacer()
                Button("Add") {
                    guard !days.isEmpty, startMinute < endMinute else { return }
                    onAdd(NonBillableRule(daysOfWeek: Array(days), startMinute: startMinute, endMinute: endMinute))
                }
                .font(.system(size: 11))
                .disabled(days.isEmpty || startMinute >= endMinute)
            }
        }
    }

    private func timeStepperField(label: String, minute: Binding<Int>) -> some View {
        Stepper(value: minute, in: 0...1440, step: 30) {
            Text(minuteLabel(minute.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 38, alignment: .trailing)
        }
        .controlSize(.small)
    }

    private func minuteLabel(_ m: Int) -> String {
        String(format: "%d:%02d", m / 60, m % 60)
    }
}

private extension OnCallSettings {
    func with(incomeTrackingEnabled: Bool) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol)
    }
    func with(passiveMultiplier: Double) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol)
    }
    func with(activeMultiplier: Double) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol)
    }
    func with(currencySymbol: String) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol)
    }
}
