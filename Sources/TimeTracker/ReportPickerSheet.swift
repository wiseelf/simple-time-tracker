import SwiftUI

struct ReportPickerSheet: View {
    var onExport: ([Date], String) -> Void

    enum Option: CaseIterable {
        case thisWeek, lastWeek, thisMonth, lastMonth, custom
        var title: String {
            switch self {
            case .thisWeek:  return "This Week"
            case .lastWeek:  return "Last Week"
            case .thisMonth: return "This Month"
            case .lastMonth: return "Last Month"
            case .custom:    return "Custom Range"
            }
        }
    }

    @State private var option: Option
    @State private var customStart: Date
    @State private var customEnd: Date
    @Environment(\.dismiss) private var dismiss

    init(defaultOption: Option = .thisWeek, onExport: @escaping ([Date], String) -> Void) {
        self.onExport = onExport
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        _option      = State(initialValue: defaultOption)
        _customStart = State(initialValue: weekStart)
        _customEnd   = State(initialValue: cal.date(byAdding: .day, value: 6, to: weekStart) ?? .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Report Period").font(.headline)

            Picker("", selection: $option) {
                ForEach(Option.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()

            if option == .custom {
                HStack(spacing: 8) {
                    DatePicker("", selection: $customStart, displayedComponents: .date)
                        .labelsHidden()
                    Text("–").foregroundStyle(.secondary)
                    DatePicker("", selection: $customEnd,
                               in: customStart...,
                               displayedComponents: .date)
                        .labelsHidden()
                }
            }

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Export") { onExport(dates, label); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var dates: [Date] {
        let cal = Calendar.current
        switch option {
        case .thisWeek, .lastWeek:
            let offset = option == .lastWeek ? -1 : 0
            guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: offset, to: base)
            else { return [] }
            return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        case .thisMonth, .lastMonth:
            let offset = option == .lastMonth ? -1 : 0
            guard let base  = cal.dateInterval(of: .month, for: .now)?.start,
                  let start = cal.date(byAdding: .month, value: offset, to: base),
                  let end   = cal.date(byAdding: .month, value: 1, to: start)
            else { return [] }
            return stride(from: start, to: end, by: 86400).map { $0 }
        case .custom:
            let start = cal.startOfDay(for: customStart)
            let end   = cal.startOfDay(for: customEnd)
            return stride(from: start, through: end, by: 86400).map { $0 }
        }
    }

    private var label: String {
        let cal = Calendar.current
        switch option {
        case .thisWeek, .lastWeek:
            let offset = option == .lastWeek ? -1 : 0
            guard let base  = cal.dateInterval(of: .weekOfYear, for: .now)?.start,
                  let start = cal.date(byAdding: .weekOfYear, value: offset, to: base),
                  let end   = cal.date(byAdding: .day, value: 6, to: start)
            else { return option.title }
            return weekRangeLabel(start: start, end: end, cal: cal)
        case .thisMonth, .lastMonth:
            let offset = option == .lastMonth ? -1 : 0
            guard let base  = cal.dateInterval(of: .month, for: .now)?.start,
                  let start = cal.date(byAdding: .month, value: offset, to: base)
            else { return option.title }
            return start.formatted(.dateTime.month(.wide).year())
        case .custom:
            let s = customStart.formatted(.dateTime.month(.abbreviated).day().year())
            let e = customEnd.formatted(.dateTime.month(.abbreviated).day().year())
            return "\(s) – \(e)"
        }
    }

    private func weekRangeLabel(start: Date, end: Date, cal: Calendar) -> String {
        let sm = cal.component(.month, from: start)
        let em = cal.component(.month, from: end)
        let sd = cal.component(.day,   from: start)
        let ed = cal.component(.day,   from: end)
        let yr = cal.component(.year,  from: start)
        if sm == em {
            return "\(start.formatted(.dateTime.month(.abbreviated))) \(sd)–\(ed), \(yr)"
        }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day())), \(yr)"
    }
}
