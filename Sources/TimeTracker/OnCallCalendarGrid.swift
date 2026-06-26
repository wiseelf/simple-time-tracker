import SwiftUI

struct OnCallCalendarGrid: View {
    let monthOffset: Int
    let rule:        RecurrenceRule?
    let exceptions:  [ScheduleException]
    @Binding var selectedDate: Date?

    private let weekdayHeaders = ["Su","M","Tu","W","Th","F","Sa"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(weekdayHeaders, id: \.self) { h in
                    Text(h)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(cells) { cell in
                    let isSel = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: cell.date) } ?? false
                    DayCell(cell: cell, isSelected: isSel)
                        .opacity(cell.isCurrentMonth ? 1 : 0.2)
                        .onTapGesture {
                            guard cell.isCurrentMonth else { return }
                            selectedDate = isSel ? nil : cell.date
                        }
                }
            }
        }
    }

    private var cells: [CalendarCell] {
        let cal = Calendar.current
        guard let base       = cal.dateInterval(of: .month, for: .now)?.start,
              let monthStart = cal.date(byAdding: .month, value: monthOffset, to: base),
              let monthEnd   = cal.date(byAdding: .month, value: 1, to: monthStart)
        else { return [] }

        let leadingPad = cal.component(.weekday, from: monthStart) - 1
        var result: [CalendarCell] = []

        if leadingPad > 0 {
            for i in (1...leadingPad).reversed() {
                let d = cal.date(byAdding: .day, value: -i, to: monthStart)!
                result.append(makeCell(d, isCurrentMonth: false))
            }
        }

        var d = monthStart
        while d < monthEnd {
            result.append(makeCell(d, isCurrentMonth: true))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        let tail = result.count % 7
        if tail > 0 {
            for i in 1...(7 - tail) {
                let after = cal.date(byAdding: .day, value: i, to: result.last!.date)!
                result.append(makeCell(after, isCurrentMonth: false))
            }
        }
        return result
    }

    private func makeCell(_ date: Date, isCurrentMonth: Bool) -> CalendarCell {
        let cal    = Calendar.current
        let window = rule?.resolvedWindow(on: date, exceptions: exceptions)
        return CalendarCell(
            date:           date,
            dayNumber:      cal.component(.day, from: date),
            isCurrentMonth: isCurrentMonth,
            isToday:        cal.isDateInToday(date),
            onCallWindow:   window
        )
    }
}

// MARK: - Supporting types

struct CalendarCell: Identifiable {
    var id: Date { date }
    let date:           Date
    let dayNumber:      Int
    let isCurrentMonth: Bool
    let isToday:        Bool
    let onCallWindow:   (Int, Int)?
}

struct DayCell: View {
    let cell:       CalendarCell
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(bg)
            Text("\(cell.dayNumber)")
                .font(.system(size: 10, weight: cell.isToday ? .bold : .regular))
                .foregroundStyle(fg)
        }
        .frame(height: 22)
    }

    private var bg: Color {
        if isSelected             { return .accentColor }
        if cell.onCallWindow != nil { return .accentColor.opacity(0.22) }
        return .clear
    }

    private var fg: Color {
        if isSelected   { return .white }
        if cell.isToday { return .accentColor }
        return .primary
    }
}
