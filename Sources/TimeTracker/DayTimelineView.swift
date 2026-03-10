import SwiftUI

/// A compact 24-hour timeline showing existing sessions and a selected range.
struct DayTimelineView: View {
    let sessions: [TimeSession]
    let rangeStart: Date
    let rangeEnd: Date

    private let trackH: CGFloat = 10
    private let daySeconds: Double = 86_400

    private var isConflicting: Bool {
        guard rangeStart < rangeEnd else { return false }
        return sessions.contains { s in
            let end = s.startDate.addingTimeInterval(TimeInterval(s.duration))
            return rangeStart < end && s.startDate < rangeEnd
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Canvas { ctx, size in
                let w = size.width

                // Background track
                ctx.fill(
                    Path(roundedRect: .init(x: 0, y: 0, width: w, height: trackH),
                         cornerRadius: trackH / 2),
                    with: .color(.secondary.opacity(0.12))
                )

                // Hour grid lines at 6, 12, 18
                for hour in [6, 12, 18] {
                    let x = Double(hour) / 24.0 * Double(w)
                    ctx.fill(
                        Path(.init(x: x, y: 0, width: 1, height: trackH)),
                        with: .color(.secondary.opacity(0.15))
                    )
                }

                // Existing sessions
                for session in sessions {
                    let x = fraction(for: session.startDate) * Double(w)
                    let bw = max(Double(session.duration) / daySeconds * Double(w), 2)
                    ctx.fill(
                        Path(roundedRect: .init(x: x, y: 1, width: bw, height: trackH - 2),
                             cornerRadius: 2),
                        with: .color(.secondary.opacity(0.5))
                    )
                }

                // Selected range
                if rangeStart < rangeEnd {
                    let x = fraction(for: rangeStart) * Double(w)
                    let bw = max(rangeEnd.timeIntervalSince(rangeStart) / daySeconds * Double(w), 2)
                    ctx.fill(
                        Path(roundedRect: .init(x: x, y: 0, width: bw, height: trackH),
                             cornerRadius: 2),
                        with: isConflicting
                            ? .color(.red.opacity(0.65))
                            : .color(.accentColor.opacity(0.8))
                    )
                }

                // "Now" marker — thin vertical line
                let nowX = fraction(for: Date()) * Double(w)
                ctx.fill(
                    Path(.init(x: nowX - 0.75, y: -2, width: 1.5, height: trackH + 4)),
                    with: .color(.primary.opacity(0.35))
                )
            }
            .frame(height: trackH)

            // Hour labels aligned to their positions on the track
            HStack(spacing: 0) {
                Text("12a").frame(maxWidth: .infinity, alignment: .leading)
                Text("6a").frame(maxWidth: .infinity, alignment: .center)
                Text("12p").frame(maxWidth: .infinity, alignment: .center)
                Text("6p").frame(maxWidth: .infinity, alignment: .center)
                Text("12a").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 8))
            .foregroundStyle(.tertiary)
        }
    }

    private func fraction(for date: Date) -> Double {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        let hours = Double(c.hour ?? 0) * 3600
        let minutes = Double(c.minute ?? 0) * 60
        let seconds = Double(c.second ?? 0)
        return max(0, min(1, (hours + minutes + seconds) / daySeconds))
    }
}
