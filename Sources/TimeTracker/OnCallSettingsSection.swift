import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = OnCallStore.shared
    @State private var newRate: String = ""
    @State private var newRateDate: Date = .now
    @State private var editingRateId: UUID? = nil
    @State private var editingRateDate: Date = .now
    @State private var editingRateText: String = ""
    @State private var showingAddNB = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Week starts on Monday", isOn: Binding(
                get: { store.settings.weekStartsOnMonday },
                set: { v in var s = store.settings; s.weekStartsOnMonday = v; store.updateSettings(s) }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 12))

            Divider()

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

                MultiplierField(label: "Passive", value: store.settings.passiveMultiplier) { v in
                    store.updateSettings(store.settings.with(passiveMultiplier: v))
                }
                MultiplierField(label: "Active", value: store.settings.activeMultiplier) { v in
                    store.updateSettings(store.settings.with(activeMultiplier: v))
                }

                Divider()
                Text("Base rate history").font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach(store.settings.rateHistory.sorted { $0.effectiveFrom > $1.effectiveFrom }) { entry in
                    if editingRateId == entry.id {
                        HStack(spacing: 6) {
                            DatePicker("", selection: $editingRateDate, displayedComponents: .date)
                                .labelsHidden().frame(width: 90)
                            TextField("Rate", text: $editingRateText)
                                .textFieldStyle(.roundedBorder).frame(width: 60).font(.system(size: 11))
                            Button("Save") {
                                guard let r = Double(editingRateText), r > 0 else { return }
                                var s = store.settings
                                if let idx = s.rateHistory.firstIndex(where: { $0.id == entry.id }) {
                                    s.rateHistory[idx] = RateEntry(id: entry.id,
                                                                    effectiveFrom: editingRateDate, rate: r)
                                    s.rateHistory.sort { $0.effectiveFrom < $1.effectiveFrom }
                                }
                                store.updateSettings(s)
                                editingRateId = nil
                            }
                            .font(.system(size: 11))
                            .disabled(Double(editingRateText) == nil)
                            Button { editingRateId = nil } label: {
                                Image(systemName: "xmark").font(.system(size: 10))
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text(entry.effectiveFrom.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.system(size: 11))
                            Spacer()
                            Text(String(format: "%@%.2f /hr", store.settings.currencySymbol, entry.rate))
                                .font(.system(size: 11, design: .monospaced))
                            Button {
                                editingRateDate = entry.effectiveFrom
                                editingRateText = String(format: "%.2f", entry.rate)
                                editingRateId   = entry.id
                            } label: {
                                Image(systemName: "pencil").font(.system(size: 11))
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
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
            HStack {
                Text("Non-billable window").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddNB.toggle()
                } label: {
                    Image(systemName: showingAddNB ? "xmark.circle" : "plus.circle")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(showingAddNB ? .secondary : .accentColor)
            }
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
            if showingAddNB {
                AddNonBillableRuleRow { rule in
                    var s = store.settings
                    s.nonBillableRules.append(rule)
                    store.updateSettings(s)
                    showingAddNB = false
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .font(.system(size: 12))
    }

    private func dayNames(_ days: [Int]) -> String {
        let abbr = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return days.sorted().compactMap { $0 >= 1 && $0 <= 7 ? abbr[$0] : nil }.joined(separator: " ")
    }

    private func minuteLabel(_ m: Int) -> String {
        String(format: "%d:%02d", m / 60, m % 60)
    }
}

private struct MultiplierField: View {
    let label: String
    let value: Double
    let onChange: (Double) -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text("\(label) rate").font(.system(size: 11))
            Spacer()
            HStack(spacing: 2) {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)
                    .font(.system(size: 11, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onChange(of: focused) { isFocused in
                        if !isFocused { commit() }
                    }
                Text("%").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .onAppear { text = fmt(value) }
        .onChange(of: value) { newValue in
            if !focused { text = fmt(newValue) }
        }
    }

    private func fmt(_ v: Double) -> String {
        let pct = v * 100
        return pct.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(pct))
            : String(format: "%.1f", pct)
    }

    private func commit() {
        guard let pct = Double(text), pct >= 0, pct <= 200 else {
            text = fmt(value)
            return
        }
        onChange(pct / 100.0)
        text = fmt(pct / 100.0)
    }
}

struct AddNonBillableRuleRow: View {
    var onAdd: (NonBillableRule) -> Void

    @State private var days: Set<Int> = [2, 3, 4, 5, 6]
    @State private var startMinute: Int = 480
    @State private var endMinute: Int = 1080

    @ObservedObject private var store = OnCallStore.shared
    private var dayLabels: [(Int, String)] { store.settings.orderedWeekdays }

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
                       currencySymbol: currencySymbol,
                       weekStartsOnMonday: weekStartsOnMonday)
    }
    func with(passiveMultiplier: Double) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol,
                       weekStartsOnMonday: weekStartsOnMonday)
    }
    func with(activeMultiplier: Double) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol,
                       weekStartsOnMonday: weekStartsOnMonday)
    }
    func with(currencySymbol: String) -> OnCallSettings {
        OnCallSettings(incomeTrackingEnabled: incomeTrackingEnabled,
                       passiveMultiplier: passiveMultiplier,
                       activeMultiplier: activeMultiplier,
                       nonBillableRules: nonBillableRules,
                       rateHistory: rateHistory,
                       currencySymbol: currencySymbol,
                       weekStartsOnMonday: weekStartsOnMonday)
    }
}
